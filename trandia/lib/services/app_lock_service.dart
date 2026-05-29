import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/digests/sha256.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const _hashKey = 'app_lock_pin_hash';
  static const _enabledKey = 'app_lock_enabled';
  static const _pinLengthKey = 'app_lock_pin_length';

  // In-memory flag to avoid double-showing the lock screen
  static bool lockShown = false;

  static String _hash(String input) {
    final digest = SHA256Digest();
    final bytes = utf8.encode(input);
    final hash = digest.process(Uint8List.fromList(bytes));
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<int> getPinLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pinLengthKey) ?? 4;
  }

  static Future<void> enable({required String pin}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hashKey, _hash(pin));
    await prefs.setInt(_pinLengthKey, pin.length);
    await prefs.setBool(_enabledKey, true);
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_pinLengthKey);
    await prefs.setBool(_enabledKey, false);
    lockShown = false;
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_hashKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }
}
