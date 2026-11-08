import 'dart:math' as math;

import 'package:flutter/material.dart';

BoxConstraints responsiveDialogConstraints(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return BoxConstraints(
    maxWidth: size.width * 0.92,
    maxHeight: size.height * 0.92,
  );
}

EdgeInsets responsiveDialogInsetPadding(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return EdgeInsets.symmetric(
    horizontal: size.width * 0.04,
    vertical: size.height * 0.04,
  );
}

double responsiveDialogContentWidth(
  BuildContext context, {
  double maxWidth = double.infinity,
}) {
  final availableWidth = MediaQuery.sizeOf(context).width * 0.92 - 48;
  return math.max(0.0, math.min(availableWidth, maxWidth));
}

double responsiveDialogContentHeight(BuildContext context) {
  final height = MediaQuery.sizeOf(context).height;
  return math.max(0.0, math.min(height * 0.68, height - 200));
}
