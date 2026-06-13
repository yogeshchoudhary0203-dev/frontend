import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/glass_common.dart';

class DobPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const DobPickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<DobPickerDialog> createState() => _DobPickerDialogState();
}

class _DobPickerDialogState extends State<DobPickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final fg = GlassTokens.fg(isDark);
    final muted = GlassTokens.sub(isDark);
    final bg = isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E5E5);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0xFF14161E).withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Date of Birth'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select your birth date'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: muted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: isDark
                      ? const ColorScheme.dark(
                          primary: Color(0xFF6C63FF),
                          onPrimary: Colors.white,
                          surface: Color(0xFF18181B),
                          onSurface: Colors.white,
                        )
                      : const ColorScheme.light(
                          primary: Color(0xFF6C63FF),
                          onPrimary: Colors.white,
                          surface: Color(0xFFFFFFFF),
                          onSurface: Color(0xFF0E1124),
                        ),
                  dialogBackgroundColor: bg,
                ),
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDateChanged: (date) => _selectedDate = date,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    isDark: isDark,
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogButton(
                    isDark: isDark,
                    label: 'Confirm',
                    isPrimary: true,
                    onTap: () => Navigator.pop(context, _selectedDate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final bool isDark;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DialogButton({
    required this.isDark,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(isDark);
    final bg = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF4F4F4);
    final primaryBg = const Color(0xFF6C63FF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isPrimary ? primaryBg : bg,
          ),
          alignment: Alignment.center,
          child: Text(
            label.tr(context),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : fg,
            ),
          ),
        ),
      ),
    );
  }
}