import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_common.dart';

class ParentalControlScreen extends StatelessWidget {
  final bool dark;
  const ParentalControlScreen({Key? key, required this.dark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Parental Control', style: manrope(size: 18, weight: FontWeight.w800, color: fg)),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'Parental control settings will be implemented here.',
          style: manrope(size: 16, weight: FontWeight.w500, color: sub),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
