import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Myš + touchpad + dotyk pre ťahanie scrollu tabuľky na desktope.
/// Úplné prepísanie [dragDevices] bez [PointerDeviceKind.trackpad] na Windows
/// vypne scrollovanie touchpadom (gesty idú ako trackpad, nie ako kolečko myši).
class WarehouseSuppliesDesktopDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
