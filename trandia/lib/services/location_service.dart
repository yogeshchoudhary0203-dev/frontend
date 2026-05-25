import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'user_service.dart';

class LocationService {
  /// Pre-permission rationale dialog → OS permission → GPS → reverse geocode → save to backend
  static Future<bool> requestAndSaveLocation(BuildContext context) async {
    final proceed = await _showRationaleDialog(context);
    if (!proceed) return false;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) _snack(context, 'Location services are off. Enable them in Settings.');
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      if (context.mounted) _snack(context, 'Location permission denied.');
      return false;
    }
    if (perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        _snack(context, 'Permission permanently denied. Enable in App Settings.');
        await Geolocator.openAppSettings();
      }
      return false;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));

      final city = await _reverseGeocode(pos.latitude, pos.longitude);
      await UserService.updateLocation(pos.latitude, pos.longitude, city ?? '');
      return true;
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not get location. Try again.');
      return false;
    }
  }

  static Future<bool> _showRationaleDialog(BuildContext context) async {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg = dark ? const Color(0xFF1C1C1F) : Colors.white;
    final fg = dark ? Colors.white : const Color(0xFF0A0A0A);
    final sub = dark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFF2F2F7),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 28,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share Your City',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Trandia will show your city on your profile so others can see where you\'re from.\n\nYou can hide or remove your location anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: sub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: dark
                                  ? Colors.white.withOpacity(0.07)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Not Now',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: sub,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Allow',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  /// OpenStreetMap Nominatim (free, no API key needed)
  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'Trandia/1.0 (contact@trandia.app)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          return addr['city'] as String? ??
              addr['town'] as String? ??
              addr['village'] as String? ??
              addr['county'] as String? ??
              addr['state'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
