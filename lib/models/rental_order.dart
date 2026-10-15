/// Order lifecycle statuses shown in the Orders screen.
enum OrderStatus { preparing, confirmed, needsPayment, outForDelivery, returned }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.preparing => 'Preparing',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.needsPayment => 'Needs payment',
        OrderStatus.outForDelivery => 'Out for delivery',
        OrderStatus.returned => 'Returned',
      };

  bool get isOpen => this != OrderStatus.returned;
  bool get isUpcoming => this != OrderStatus.returned;
}

/// A rental order / booking.
class RentalOrder {
  final String id; // e.g. RW-2051
  final String eventName;
  final String customerName;
  final String contactName;
  final DateTime createdAt;
  final DateTime eventDate;
  final int itemCount;
  final double total;
  final OrderStatus status;

  const RentalOrder({
    required this.id,
    required this.eventName,
    required this.customerName,
    required this.contactName,
    required this.createdAt,
    required this.eventDate,
    required this.itemCount,
    required this.total,
    required this.status,
  });

  RentalOrder copyWith({OrderStatus? status, double? total, int? itemCount}) =>
      RentalOrder(
        id: id,
        eventName: eventName,
        customerName: customerName,
        contactName: contactName,
        createdAt: createdAt,
        eventDate: eventDate,
        itemCount: itemCount ?? this.itemCount,
        total: total ?? this.total,
        status: status ?? this.status,
      );
}
