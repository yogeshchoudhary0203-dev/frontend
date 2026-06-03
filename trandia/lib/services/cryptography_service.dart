import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

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

  // ── Key Generation & Serialization ───────────────────────────

  /// Generate a brand new RSA 2048-bit keypair on the device.
  /// Returns a map of {"public": base64Json, "private": base64Json}.
  Future<Map<String, String>> generateRSAKeyPair() async {
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

    final pubJson = jsonEncode({
      'modulus': _encodeBigInt(myPublic.modulus),
      'exponent': _encodeBigInt(myPublic.publicExponent),
    });

    final privJson = jsonEncode({
      'modulus': _encodeBigInt(myPrivate.modulus),
      'privateExponent': _encodeBigInt(myPrivate.privateExponent),
      'p': _encodeBigInt(myPrivate.p),
      'q': _encodeBigInt(myPrivate.q),
    });

    final pubB64 = base64Encode(utf8.encode(pubJson));
    final privB64 = base64Encode(utf8.encode(privJson));

    return {'public': pubB64, 'private': privB64};
  }

  /// Initialize E2EE keys locally. Generates if not present, then returns public key.
  Future<String> initKeys() async {
    var pub = await _secureStorage.read(key: _kPublicKeyPref);
    var priv = await _secureStorage.read(key: _kPrivateKeyPref);

    if (pub == null || priv == null) {
      final pair = await generateRSAKeyPair();
      pub = pair['public']!;
      priv = pair['private']!;
      await _secureStorage.write(key: _kPublicKeyPref, value: pub);
      await _secureStorage.write(key: _kPrivateKeyPref, value: priv);
    }
    return pub;
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
    final key = Key(base64Decode(aesKeyBase64));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return jsonEncode({
      'ct': encrypted.base64,
      'iv': iv.base64,
    });
  }

  /// Decrypts text using AES-256-CBC.
  String decryptAES(String encryptedJson, String aesKeyBase64) {
    final key = Key(base64Decode(aesKeyBase64));
    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final ct = data['ct'] as String;
    final iv = IV.fromBase64(data['iv'] as String);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt(Encrypted.fromBase64(ct), iv: iv);
  }

  // ── Asymmetric Cryptography (RSA-2048) ───────────────────────

  /// Encrypts a symmetric AES key using a recipient's RSA Public Key.
  String encryptAESKeyWithRSA(String aesKeyBase64, String rsaPublicKeyBase64) {
    final pubKey = _parseRSAPublicKey(rsaPublicKeyBase64);
    final encrypter = Encrypter(RSA(publicKey: pubKey));
    final encrypted = encrypter.encrypt(aesKeyBase64);
    return encrypted.base64;
  }

  /// Decrypts a symmetric AES key using the local RSA Private Key.
  String decryptAESKeyWithRSA(String encryptedAESKeyBase64, String rsaPrivateKeyBase64) {
    final privKey = _parseRSAPrivateKey(rsaPrivateKeyBase64);
    final encrypter = Encrypter(RSA(privateKey: privKey));
    final decryptedBytes = encrypter.decryptBytes(Encrypted.fromBase64(encryptedAESKeyBase64));
    return utf8.decode(decryptedBytes);
  }

  /// Checks if the local public key is registered in MongoDB, and uploads it if missing or different.
  Future<void> ensurePublicKeyRegistered() async {
    try {
      // 1. Initialize local keys and get public key base64 string
      final localPub = await initKeys();

      // 2. Fetch our profile from backend to check registered public key
      final token = await ApiService.getToken();
      if (token == null) return; // not logged in yet

      // Get me profile
      final response = await ApiService.get('/users/me', requiresAuth: true);
      final registeredPub = response['public_key'] as String?;

      // 3. If not registered or different, publish it to backend
      if (registeredPub != localPub) {
        developer.log('[CryptographyService] Registering new public key to backend...');
        await ApiService.put(
          '/users/me/public-key',
          {'public_key': localPub},
          requiresAuth: true,
        );
        developer.log('[CryptographyService] Public key registered successfully ✓');
      } else {
        developer.log('[CryptographyService] Public key already registered matches local key ✓');
      }
    } catch (e) {
      developer.log('[CryptographyService] Failed to ensure public key registration: $e');
    }
  }
}
