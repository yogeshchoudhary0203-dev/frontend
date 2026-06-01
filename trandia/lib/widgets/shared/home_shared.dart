import 'package:flutter/material.dart';

extension ColorOpacity on Color {
  Color op(double opacity) => withOpacity(opacity);
}

const double kNavBtnSize = 64.0;
const double kNavWidth   = kNavBtnSize;
const double kItemH      = 54.0;
const double kNavGap     = 6.0;
const double kIconSize   = 20.0;

final ValueNotifier<bool> homeFeedActive = ValueNotifier(true);
