import 'package:flutter/material.dart';

import '../services/report_service.dart';

/// Shows a reason-picker bottom sheet and files a report. Styled to match the
/// app's existing modal sheets (rounded top, grab handle, ListTile rows).
///
/// Usage from any overflow menu:
///   showReportSheet(context, targetType: ReportService.targetPost, targetId: id);
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  String? titleOverride,
}) async {
  final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  final fg = isDark ? Colors.white : Colors.black;
  final sub = fg.withValues(alpha: 0.55);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              titleOverride ?? 'Report',
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Why are you reporting this?',
              style: TextStyle(color: sub, fontSize: 13),
            ),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in ReportService.reasons)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.outlined_flag_rounded, color: sub, size: 22),
                  title: Text(r.key, style: TextStyle(color: fg, fontSize: 15)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await ReportService.report(
                      targetType: targetType,
                      targetId: targetId,
                      reason: r.value,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(ok
                              ? 'Thanks — our team will review this.'
                              : 'Could not send report. Please try again.'),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
