// media_upload_service.dart
//
// Signed direct-upload flow (zero backend bandwidth cost):
//   1. Get signed params from backend  →  POST /media/upload-signature
//   2. Upload file directly to Cloudinary CDN  →  multipart POST
//   3. Return the CDN URL to the caller
//
// To swap Cloudinary for a different CDN later:
//   - Change _getSignatureAndUpload() to point to the new provider
//   - The rest of the app (create_post, profile update, chat) stays unchanged.

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result type — same shape regardless of CDN provider
// ─────────────────────────────────────────────────────────────────────────────

class MediaUploadResult {
  final String url;
  final String publicId;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final double? duration; // seconds, videos only
  final String format;
  final int bytesSize;

  const MediaUploadResult({
    required this.url,
    required this.publicId,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.duration,
    this.format = '',
    this.bytesSize = 0,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) =>
      MediaUploadResult(
        url:          json['secure_url'] ?? json['url'] ?? '',
        publicId:     json['public_id']  ?? '',
        thumbnailUrl: _eagerThumb(json),
        width:        json['width'],
        height:       json['height'],
        duration:     (json['duration'] as num?)?.toDouble(),
        format:       json['format'] ?? '',
        bytesSize:    json['bytes'] ?? 0,
      );

  static String? _eagerThumb(Map<String, dynamic> json) {
    final eager = json['eager'];
    if (eager is List && eager.isNotEmpty) {
      return (eager[0] as Map)['secure_url'];
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload folders
// ─────────────────────────────────────────────────────────────────────────────

enum MediaFolder {
  profiles,
  posts,
  stories,
  chats,
}

extension MediaFolderName on MediaFolder {
  String get value {
    switch (this) {
      case MediaFolder.profiles: return 'profiles';
      case MediaFolder.posts:    return 'posts';
      case MediaFolder.stories:  return 'stories';
      case MediaFolder.chats:    return 'chats';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class MediaUploadService {
  MediaUploadService._();
  static final MediaUploadService instance = MediaUploadService._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Upload an image file. Returns CDN URL + metadata.
  Future<MediaUploadResult> uploadImage(
    File file, {
    required MediaFolder folder,
    void Function(double progress)? onProgress,
  }) =>
      _upload(file, folder: folder, resourceType: 'image', onProgress: onProgress);

  /// Upload a video file. Returns CDN URL + auto-generated thumbnail URL.
  Future<MediaUploadResult> uploadVideo(
    File file, {
    required MediaFolder folder,
    void Function(double progress)? onProgress,
  }) =>
      _upload(file, folder: folder, resourceType: 'video', onProgress: onProgress);

  /// Upload profile picture — convenience wrapper.
  Future<MediaUploadResult> uploadProfilePicture(
    File file, {
    void Function(double progress)? onProgress,
  }) =>
      uploadImage(file, folder: MediaFolder.profiles, onProgress: onProgress);

  /// Upload profile picture from raw bytes — works on web + mobile.
  Future<MediaUploadResult> uploadProfilePictureBytes(
    Uint8List bytes,
    String filename, {
    void Function(double progress)? onProgress,
  }) =>
      uploadImageBytes(
        bytes,
        filename: filename,
        folder: MediaFolder.profiles,
        onProgress: onProgress,
      );

  /// Upload image from raw bytes (web-safe, no dart:io required).
  Future<MediaUploadResult> uploadImageBytes(
    Uint8List bytes, {
    required String filename,
    required MediaFolder folder,
    void Function(double progress)? onProgress,
  }) =>
      _uploadBytes(
        bytes,
        filename: filename,
        folder: folder,
        resourceType: 'image',
        onProgress: onProgress,
      );

  /// Delete media from CDN. publicId comes from MediaUploadResult.publicId.
  Future<bool> deleteMedia(String publicId, {String resourceType = 'image'}) async {
    try {
      await ApiService.delete(
        '/media/',
        body: {'public_id': publicId, 'resource_type': resourceType},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Core upload (signed direct CDN upload) ─────────────────────────────────

  Future<MediaUploadResult> _upload(
    File file, {
    required MediaFolder folder,
    required String resourceType,
    void Function(double progress)? onProgress,
  }) async {
    // Step 0: compress images client-side before upload (videos skipped)
    File fileToUpload = file;
    if (resourceType == 'image') {
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          '${file.absolute.path}_compressed.jpg',
          minWidth:  1920,
          minHeight: 1920,
          quality:   85,
          keepExif:  false,
        );
        if (compressed != null) {
          fileToUpload = File(compressed.path);
        }
      } catch (_) {
        // Compression failed — silently fall back to original file
        fileToUpload = file;
      }
    }

    // Step 1: get signed upload params from backend (API secret stays on server)
    onProgress?.call(0.05);
    final sigParams = await _fetchSignature(folder.value, resourceType);

    // Step 2: upload directly to Cloudinary — Railway never touches the bytes
    onProgress?.call(0.10);
    final result = await _uploadToCloudinary(
      file:         fileToUpload,
      sigParams:    sigParams,
      resourceType: resourceType,
      onProgress:   onProgress,
    );

    // Clean up temp compressed file if one was created
    if (fileToUpload.path != file.path) {
      try { await fileToUpload.delete(); } catch (_) {}
    }

    onProgress?.call(1.0);
    return result;
  }

  Future<Map<String, dynamic>> _fetchSignature(
    String folder,
    String resourceType,
  ) async {
    return await ApiService.post(
      '/media/upload-signature',
      {'folder': folder, 'resource_type': resourceType},
      requiresAuth: true,
    );
  }

  // Bytes-based upload (web + mobile safe)
  Future<MediaUploadResult> _uploadBytes(
    Uint8List bytes, {
    required String filename,
    required MediaFolder folder,
    required String resourceType,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.05);
    final sigParams = await _fetchSignature(folder.value, resourceType);
    onProgress?.call(0.10);
    final result = await _uploadBytesToCloudinary(
      bytes:        bytes,
      filename:     filename,
      sigParams:    sigParams,
      resourceType: resourceType,
      onProgress:   onProgress,
    );
    onProgress?.call(1.0);
    return result;
  }

  Future<MediaUploadResult> _uploadToCloudinary({
    required File file,
    required Map<String, dynamic> sigParams,
    required String resourceType,
    void Function(double progress)? onProgress,
  }) async {
    final uploadUrl = sigParams['upload_url'] as String;
    final bytes     = await file.readAsBytes();
    final mimeType  = _mimeType(file.path, resourceType);

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

    // Signed fields
    request.fields['api_key']  = sigParams['api_key'].toString();
    request.fields['timestamp'] = sigParams['timestamp'].toString();
    request.fields['signature'] = sigParams['signature'].toString();
    request.fields['folder']   = sigParams['folder'].toString();
    _addSignedPolicyFields(request, sigParams);

    // Delivery optimizations — auto format (WebP/AVIF on Android) + auto quality
    if (resourceType == 'image') {
      request.fields['quality']      = 'auto';
      request.fields['fetch_format'] = 'auto';
    } else {
      request.fields['quality'] = 'auto';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: _filename(file.path),
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamed = await request.send().timeout(const Duration(minutes: 5));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${streamed.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return MediaUploadResult.fromJson(json);
  }

  Future<MediaUploadResult> _uploadBytesToCloudinary({
    required Uint8List bytes,
    required String filename,
    required Map<String, dynamic> sigParams,
    required String resourceType,
    void Function(double progress)? onProgress,
  }) async {
    final uploadUrl = sigParams['upload_url'] as String;
    final mimeType  = _mimeType(filename, resourceType);

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.fields['api_key']   = sigParams['api_key'].toString();
    request.fields['timestamp'] = sigParams['timestamp'].toString();
    request.fields['signature'] = sigParams['signature'].toString();
    request.fields['folder']    = sigParams['folder'].toString();
    _addSignedPolicyFields(request, sigParams);

    if (resourceType == 'image') {
      request.fields['quality']      = 'auto';
      request.fields['fetch_format'] = 'auto';
    } else {
      request.fields['quality'] = 'auto';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamed = await request.send().timeout(const Duration(minutes: 5));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${streamed.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return MediaUploadResult.fromJson(json);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _mimeType(String path, String resourceType) {
    final ext = path.toLowerCase().split('.').last;
    const mimes = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'webp': 'image/webp', 'gif': 'image/gif', 'heic': 'image/heic',
      'mp4': 'video/mp4', 'mov': 'video/quicktime', 'avi': 'video/x-msvideo',
      'webm': 'video/webm',
    };
    return mimes[ext] ??
        (resourceType == 'video' ? 'video/mp4' : 'image/jpeg');
  }

  void _addSignedPolicyFields(
    http.MultipartRequest request,
    Map<String, dynamic> sigParams,
  ) {
    const policyFields = {
      'allowed_formats',
      'max_file_size',
      'moderation',
    };
    for (final field in policyFields) {
      final value = sigParams[field];
      if (value != null && value.toString().isNotEmpty) {
        request.fields[field] = value.toString();
      }
    }
  }

  String _filename(String path) => path.split(RegExp(r'[/\\]')).last;
}
