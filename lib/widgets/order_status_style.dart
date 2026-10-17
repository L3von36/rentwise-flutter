import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/rental_order.dart';

/// Status pill / chip colors for orders — shared by the orders screen,
/// dashboard, order detail and tasks screens.
extension OrderStatusStyle on OrderStatus {
  Color get fg => switch (this) {
        OrderStatus.preparing => AppPalette.blue,
        OrderStatus.confirmed => AppPalette.green,
        OrderStatus.needsPayment => AppPalette.amber,
        OrderStatus.outForDelivery => AppPalette.purple,
        OrderStatus.returned => AppPalette.green,
      };

  Color get bg => switch (this) {
        OrderStatus.preparing => AppPalette.blueBg,
        OrderStatus.confirmed => AppPalette.greenBg,
        OrderStatus.needsPayment => AppPalette.amberBg,
        OrderStatus.outForDelivery => AppPalette.purpleBg,
        OrderStatus.returned => AppPalette.greenBg,
      };
}
