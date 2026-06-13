import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

/// Top-level function required by Flutter's [compute] for isolate execution.
/// Generates a 2048-bit RSA key pair off the main thread and returns
/// a map of {"public": base64Json, "private": base64Json}.
Map<String, String> generateRSAKeyPairIsolate(void _) {
  final secureRandom = pc.SecureRandom('Fortuna')
    ..seed(pc.KeyParameter(Uint8List.fromList(
        List.generate(32, (_) => Random.secure().nextInt(255)))));

  final keyGen = RSAKeyGenerator()
    ..init(pc.ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom));

  final pair = keyGen.generateKeyPair();
  final myPublic = pair.publicKey as RSAPublicKey;
  final myPrivate = pair.privateKey as RSAPrivateKey;

  String encodeBigInt(BigInt? number) {
    if (number == null) return '';
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    final l = hex.length ~/ 2;
    final bytes = Uint8List(l);
    for (var i = 0; i < l; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return base64Encode(bytes);
  }

  final pubJson = jsonEncode({
    'modulus': encodeBigInt(myPublic.modulus),
    'exponent': encodeBigInt(myPublic.publicExponent),
  });

  final privJson = jsonEncode({
    'modulus': encodeBigInt(myPrivate.modulus),
    'privateExponent': encodeBigInt(myPrivate.privateExponent),
    'p': encodeBigInt(myPrivate.p),
    'q': encodeBigInt(myPrivate.q),
  });

  return {
    'public': base64Encode(utf8.encode(pubJson)),
    'private': base64Encode(utf8.encode(privJson)),
  };
}

class CryptographyService {
  static final CryptographyService _instance = CryptographyService._internal();
  factory CryptographyService() => _instance;
  CryptographyService._internal();

  static const String _kPublicKeyPref = 'e2ee_public_key';
  static const String _kPrivateKeyPref = 'e2ee_private_key';

  // flutter_secure_storage instance — uses Android Keystore / iOS Keychain
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Guards against concurrent initKeys() calls generating/restoring twice.
  Future<String>? _initInFlight;

  // ── Key Generation & Serialization ───────────────────────────

  /// Generate a brand new RSA 2048-bit keypair on the device.
  /// Runs in a separate isolate via [compute] to avoid blocking the UI thread.
  /// Returns a map of {"public": base64Json, "private": base64Json}.
  Future<Map<String, String>> generateRSAKeyPair() async {
    return compute(generateRSAKeyPairIsolate, null);
  }

  /// Ensure this device has the account's E2EE keypair, and return the public key.
  ///
  /// Resolution order (this is what makes chats survive a device switch):
  ///   1. Local secure storage  → use it (fast path, no network).
  ///   2. Server keypair backup → restore it, so we can decrypt existing history.
  ///   3. Neither exists        → generate a fresh pair and back it up.
  ///
  /// Concurrent callers share a single in-flight future so we never generate
  /// two different keypairs on the same fresh device.
  Future<String> initKeys() {
    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;
    final future = _initKeysInternal();
    _initInFlight = future;
    return future.whenComplete(() => _initInFlight = null);
  }

  Future<String> _initKeysInternal() async {
    final pub = await _secureStorage.read(key: _kPublicKeyPref);
    final priv = await _secureStorage.read(key: _kPrivateKeyPref);

    // 1. Local keys present → done.
    if (pub != null && pub.isNotEmpty && priv != null && priv.isNotEmpty) {
      return pub;
    }

    // 2. No local keys (new device / reinstall) → try server backup.
    try {
      final backup = await _fetchKeypairBackup();
      final remotePub = backup?['public_key'] as String?;
      final remotePriv = backup?['private_key'] as String?;
      if (remotePub != null && remotePub.isNotEmpty &&
          remotePriv != null && remotePriv.isNotEmpty) {
        await _secureStorage.write(key: _kPublicKeyPref, value: remotePub);
        await _secureStorage.write(key: _kPrivateKeyPref, value: remotePriv);
        developer.log('[CryptographyService] Restored keypair from server backup ✓');
        return remotePub;
      }
    } catch (e) {
      developer.log('[CryptographyService] Keypair restore failed (will generate): $e');
    }

    // 3. No backup anywhere → generate fresh and back it up for future devices.
    final pair = await generateRSAKeyPair();
    final newPub = pair['public']!;
    final newPriv = pair['private']!;
    await _secureStorage.write(key: _kPublicKeyPref, value: newPub);
    await _secureStorage.write(key: _kPrivateKeyPref, value: newPriv);
    unawaited(_uploadKeypairBackup(newPub, newPriv));
    developer.log('[CryptographyService] Generated new keypair + backup ✓');
    return newPub;
  }

  /// Fetch the account's keypair backup from the server (null when none / not logged in).
  Future<Map<String, dynamic>?> _fetchKeypairBackup() async {
    final token = await ApiService.getToken();
    if (token == null) return null;
    return ApiService.get('/users/me/keypair', requiresAuth: true, bypassCache: true);
  }

  /// Upload the keypair backup (private key is encrypted at rest server-side).
  Future<void> _uploadKeypairBackup(String publicKey, String privateKey) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;
      await ApiService.put(
        '/users/me/keypair',
        {'public_key': publicKey, 'private_key': privateKey},
        requiresAuth: true,
      );
    } catch (e) {
      developer.log('[CryptographyService] keypair backup upload failed: $e');
    }
  }

  Future<String?> getLocalPublicKey() async {
    return _secureStorage.read(key: _kPublicKeyPref);
  }

  Future<String?> getLocalPrivateKey() async {
    return _secureStorage.read(key: _kPrivateKeyPref);
  }

  Future<void> clearLocalKeys() async {
    await _secureStorage.delete(key: _kPublicKeyPref);
    await _secureStorage.delete(key: _kPrivateKeyPref);
  }

  // ── Helper BigInt Encoders ───────────────────────────────────

  static String _encodeBigInt(BigInt? number) {
    if (number == null) return '';
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    final l = hex.length ~/ 2;
    final bytes = Uint8List(l);
    for (var i = 0; i < l; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return base64Encode(bytes);
  }

  static BigInt _decodeBigInt(String base64Str) {
    final bytes = base64Decode(base64Str);
    var hex = '';
    for (var i = 0; i < bytes.length; i++) {
      var s = bytes[i].toRadixString(16);
      if (s.length == 1) s = '0$s';
      hex += s;
    }
    if (hex.isEmpty) return BigInt.zero;
    return BigInt.parse(hex, radix: 16);
  }

  RSAPublicKey _parseRSAPublicKey(String base64Key) {
    final rawJson = utf8.decode(base64Decode(base64Key));
    final data = jsonDecode(rawJson) as Map<String, dynamic>;
    final modulus = _decodeBigInt(data['modulus'] as String);
    final exponent = _decodeBigInt(data['exponent'] as String);
    return RSAPublicKey(modulus, exponent);
  }

  RSAPrivateKey _parseRSAPrivateKey(String base64Key) {
    final rawJson = utf8.decode(base64Decode(base64Key));
    final data = jsonDecode(rawJson) as Map<String, dynamic>;
    final modulus = _decodeBigInt(data['modulus'] as String);
    final privateExponent = _decodeBigInt(data['privateExponent'] as String);
    final p = _decodeBigInt(data['p'] as String);
    final q = _decodeBigInt(data['q'] as String);
    return RSAPrivateKey(modulus, privateExponent, p, q);
  }

  // ── Symmetric Cryptography (AES-256-CBC) ─────────────────────

  /// Generates a cryptographically secure 256-bit random AES key.
  String generateRandomAESKey() {
    final random = Random.secure();
    final keyBytes = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    return base64Encode(keyBytes);
  }

  /// Encrypts text using AES-256-CBC with a random IV.
  /// Returns a JSON string containing the ciphertext and IV: {"ct": "...", "iv": "..."}.
  String encryptAES(String plainText, String aesKeyBase64) {
    final key = enc.Key(base64Decode(aesKeyBase64));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return jsonEncode({
      'ct': encrypted.base64,
      'iv': iv.base64,
    });
  }

  /// Decrypts text using AES-256-CBC.
  String decryptAES(String encryptedJson, String aesKeyBase64) {
    final key = enc.Key(base64Decode(aesKeyBase64));
    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final ct = data['ct'] as String;
    final iv = enc.IV.fromBase64(data['iv'] as String);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(enc.Encrypted.fromBase64(ct), iv: iv);
  }

  // ── Asymmetric Cryptography (RSA-2048) ───────────────────────

  /// Encrypts a symmetric AES key using a recipient's RSA Public Key.
  String encryptAESKeyWithRSA(String aesKeyBase64, String rsaPublicKeyBase64) {
    final pubKey = _parseRSAPublicKey(rsaPublicKeyBase64);
    final encrypter = enc.Encrypter(enc.RSA(publicKey: pubKey));
    final encrypted = encrypter.encrypt(aesKeyBase64);
    return encrypted.base64;
  }

  /// Decrypts a symmetric AES key using the local RSA Private Key.
  String decryptAESKeyWithRSA(String encryptedAESKeyBase64, String rsaPrivateKeyBase64) {
    final privKey = _parseRSAPrivateKey(rsaPrivateKeyBase64);
    final encrypter = enc.Encrypter(enc.RSA(privateKey: privKey));
    final decryptedBytes = encrypter.decryptBytes(enc.Encrypted.fromBase64(encryptedAESKeyBase64));
    return utf8.decode(decryptedBytes);
  }

  /// Ensure the account's keypair is both present locally AND backed up on the
  /// server, so any future device can restore it. Safe to call on every app open.
  ///
  /// Handles three cases:
  ///   • Fresh device  → initKeys() restores/generates; this just confirms sync.
  ///   • Legacy user   → has local keys but no server backup → uploads the backup
  ///                     so their NEXT device can read history.
  ///   • Up to date    → no-op.
  Future<void> ensurePublicKeyRegistered() async {
    try {
      // 1. Make sure this device has the keypair (restores from backup if needed).
      final localPub = await initKeys();
      final localPriv = await getLocalPrivateKey();

      final token = await ApiService.getToken();
      if (token == null) return; // not logged in yet

      // 2. Check what the server currently holds.
      Map<String, dynamic>? backup;
      try {
        backup = await ApiService.get('/users/me/keypair',
            requiresAuth: true, bypassCache: true);
      } catch (_) {
        backup = null;
      }
      final serverPub = backup?['public_key'] as String?;
      final serverPriv = backup?['private_key'] as String?;

      // 3. (Re)upload the backup when it is missing or out of sync with this
      //    device's keys. The backup PUT also stores the public key.
      final needsBackup = serverPriv == null ||
          serverPriv.isEmpty ||
          serverPub != localPub;
      if (needsBackup && localPriv != null && localPriv.isNotEmpty) {
        await _uploadKeypairBackup(localPub, localPriv);
        developer.log('[CryptographyService] Keypair backup synced ✓');
      } else {
        developer.log('[CryptographyService] Keypair backup already in sync ✓');
      }
    } catch (e) {
      developer.log('[CryptographyService] Failed to ensure keypair registration: $e');
    }
  }
}
