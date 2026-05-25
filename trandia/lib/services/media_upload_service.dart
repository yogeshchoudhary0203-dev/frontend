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
  Future<MediaUploadResult> uploadProfilePicture(File file) =>
      uploadImage(file, folder: MediaFolder.profiles);

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
    // Step 1: get signed upload params from backend (API secret stays on server)
    onProgress?.call(0.05);
    final sigParams = await _fetchSignature(folder.value, resourceType);

    // Step 2: upload directly to Cloudinary — Railway never touches the bytes
    onProgress?.call(0.10);
    final result = await _uploadToCloudinary(
      file:         file,
      sigParams:    sigParams,
      resourceType: resourceType,
      onProgress:   onProgress,
    );

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

  String _filename(String path) => path.split(RegExp(r'[/\\]')).last;
}
