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

/// A single quoted line item on a rental order. `unitPrice` is the
/// per-unit event price quoted to the customer (it may differ from the
/// catalog day-rate — quotes bundle multi-day use, delivery and setup).
class OrderLine {
  final String itemName;
  final int qty;
  final double unitPrice;

  const OrderLine({
    required this.itemName,
    required this.qty,
    required this.unitPrice,
  });

  double get lineTotal => qty * unitPrice;

  Map<String, dynamic> toCsvRow() =>
      {'item': itemName, 'qty': qty, 'unit': unitPrice, 'total': lineTotal};
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

  /// Quoted line items — the physical manifest behind [itemCount]/[total].
  final List<OrderLine> lineItems;

  /// Delivery / prep notes captured at booking time.
  final String notes;

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
    this.lineItems = const [],
    this.notes = '',
  });

  RentalOrder copyWith({
    OrderStatus? status,
    double? total,
    int? itemCount,
    List<OrderLine>? lineItems,
    String? notes,
  }) =>
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
        lineItems: lineItems ?? this.lineItems,
        notes: notes ?? this.notes,
      );
}
