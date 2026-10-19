import '../../core/app_locale.dart';
import '../../core/formatters.dart';

/// Order lifecycle statuses shown in the Orders screen.
enum OrderStatus { preparing, confirmed, needsPayment, outForDelivery, returned }

/// How money actually arrived — the Ethiopian payment rails a rental
/// desk sees daily. Brand names stay Latin in every language; only Cash
/// and Card localize.
enum PaymentMethod { cash, telebirr, cbeBirr, mpesa, chapa, card }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => AppLocale.t('Cash'),
        PaymentMethod.telebirr => 'Telebirr',
        PaymentMethod.cbeBirr => 'CBE Birr',
        PaymentMethod.mpesa => 'M-Pesa',
        PaymentMethod.chapa => 'Chapa',
        PaymentMethod.card => AppLocale.t('Card'),
      };

  /// Short chip label — ጥሩ ገንዘብ is too long for a tight row chip.
  String get chip => switch (this) {
        PaymentMethod.cash => AppLocale.isAmharic ? 'ጥሩ' : 'Cash',
        _ => label,
      };

  String get docName => name;

  static PaymentMethod? fromDoc(String? raw) {
    for (final m in PaymentMethod.values) {
      if (m.name == raw) return m;
    }
    return null;
  }
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.preparing => AppLocale.t('Preparing'),
        OrderStatus.confirmed => AppLocale.t('Confirmed'),
        OrderStatus.needsPayment => AppLocale.t('Needs payment'),
        // Customer-pickup business: items handed over to the customer,
        // never delivered by the shop (transport is on the customer).
        OrderStatus.outForDelivery => AppLocale.t('With customer'),
        OrderStatus.returned => AppLocale.t('Returned'),
      };

  /// Human action label for ADVANCING an order into this status —
  /// the button text the operator actually wants to press.
  String get actionLabel => switch (this) {
        OrderStatus.preparing => AppLocale.t('Stage & pack'),
        OrderStatus.confirmed => AppLocale.t('Accept payment'),
        OrderStatus.needsPayment => AppLocale.t('Request payment'),
        OrderStatus.outForDelivery => AppLocale.t('Hand over to customer'),
        OrderStatus.returned => AppLocale.t('Mark returned'),
      };

  bool get isOpen => this != OrderStatus.returned;
  bool get isUpcoming => this != OrderStatus.returned;
}

/// Valid forward transitions of the rental lifecycle.
///
/// Single source of truth: the order detail screen only OFFERS these,
/// and [WorkspaceState.updateOrderStatus] enforces them — a crafted
/// direct state call cannot push an order into an illegal status.
const Map<OrderStatus, List<OrderStatus>> kOrderTransitions = {
  OrderStatus.confirmed: [
    OrderStatus.preparing,
    OrderStatus.outForDelivery,
    OrderStatus.needsPayment,
  ],
  OrderStatus.preparing: [
    OrderStatus.outForDelivery,
    OrderStatus.needsPayment,
    OrderStatus.returned, // cancelled-before-dispatch
  ],
  OrderStatus.outForDelivery: [
    OrderStatus.needsPayment,
    OrderStatus.returned,
  ],
  OrderStatus.needsPayment: [
    OrderStatus.confirmed, // payment accepted
    OrderStatus.returned,
  ],
  OrderStatus.returned: [], // terminal
};

/// A single quoted line item on a rental order. `unitPrice` is the
/// per-unit event price quoted to the customer (it may differ from the
/// catalog day-rate — quotes bundle multi-day use, prep and pickup).
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
///
/// Payment policy (v1.26): NOTHING leaves the shop until every line of
/// the plan is settled and the customer is verified —
///
///   1. DOWN PAYMENT, agreed at booking, collected first.
///   2. REMAINING balance (total − down payment) before handover.
///   3. COLLATERAL deposit before handover (refunded at return).
///   4. Customer ID sighted and recorded ([idVerifiedAt]).
///   5. Rental agreement signed ([signedAt] + [signatureData]).
///
/// The customer picks the items up themselves — the shop does not
/// deliver; transport is on the customer.
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

  /// Prep / pickup notes captured at booking time.
  final String notes;

  // -- payment plan (all settled BEFORE the items leave the shop) --

  /// Deposit collected first, agreed at booking time.
  final double downPayment;

  /// When the down payment was actually received (null = not yet).
  final DateTime? downPaymentPaidAt;

  /// How the down payment arrived (Telebirr / CBE Birr / cash / …).
  final PaymentMethod? downPaymentMethod;

  /// Refundable collateral deposit, held until the items come back.
  final double collateralAmount;

  /// When the collateral was received (null = not yet).
  final DateTime? collateralPaidAt;

  /// How the collateral was received.
  final PaymentMethod? collateralMethod;

  /// When the remaining balance (total − downPayment) was received.
  final DateTime? remainingPaidAt;

  /// How the remaining balance arrived.
  final PaymentMethod? remainingMethod;

  // -- customer verification at handover --

  /// When the customer's ID was sighted and recorded.
  final DateTime? idVerifiedAt;

  /// Signature strokes (compact codec — see [signatureToDoc]) and the
  /// printed name typed by the signer.
  final String signatureData;
  final String signedName;
  final DateTime? signedAt;

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
    this.downPayment = 0,
    this.downPaymentPaidAt,
    this.downPaymentMethod,
    this.collateralAmount = 0,
    this.collateralPaidAt,
    this.collateralMethod,
    this.remainingPaidAt,
    this.remainingMethod,
    this.idVerifiedAt,
    this.signatureData = '',
    this.signedName = '',
    this.signedAt,
  });

  // -- derived payment state (single source of truth for the gate) --

  /// Balance left after the down payment — collected before handover.
  double get remainingDue => (total - downPayment).clamp(0, double.infinity);

  bool get downPaymentPaid =>
      downPayment <= 0 || downPaymentPaidAt != null;
  bool get remainingPaid =>
      remainingDue <= 0 || remainingPaidAt != null;
  bool get collateralPaid =>
      collateralAmount <= 0 || collateralPaidAt != null;
  bool get idVerified => idVerifiedAt != null;
  bool get signatureCaptured =>
      signedAt != null && signatureData.isNotEmpty;

  /// Money still owed on this order (down + remaining + collateral).
  double get outstandingTotal =>
      (downPaymentPaid ? 0 : downPayment) +
      (remainingPaid ? 0 : remainingDue) +
      (collateralPaid ? 0 : collateralAmount);

  /// Human-readable list of everything blocking handover. Empty = the
  /// items may leave the shop.
  List<String> get handoverBlockers {
    const t = AppLocale.t;
    final blockers = <String>[
      if (!downPaymentPaid)
        '${t('Down payment')} ${Fmt.moneySmart(downPayment)} '
            '${t('not received')}',
      if (!remainingPaid)
        '${t('Remaining')} ${Fmt.moneySmart(remainingDue)} '
            '${t('not received')}',
      if (!collateralPaid)
        '${t('Collateral')} ${Fmt.moneySmart(collateralAmount)} '
            '${t('not received')}',
      if (!idVerified) t('Customer ID not verified'),
      if (!signatureCaptured) t('Rental agreement not signed'),
    ];
    return blockers;
  }

  bool get canHandOver => handoverBlockers.isEmpty;

  RentalOrder copyWith({
    OrderStatus? status,
    double? total,
    int? itemCount,
    List<OrderLine>? lineItems,
    String? notes,
    double? downPayment,
    DateTime? downPaymentPaidAt,
    PaymentMethod? downPaymentMethod,
    double? collateralAmount,
    DateTime? collateralPaidAt,
    PaymentMethod? collateralMethod,
    DateTime? remainingPaidAt,
    PaymentMethod? remainingMethod,
    DateTime? idVerifiedAt,
    String? signatureData,
    String? signedName,
    DateTime? signedAt,
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
        downPayment: downPayment ?? this.downPayment,
        downPaymentPaidAt: downPaymentPaidAt ?? this.downPaymentPaidAt,
        downPaymentMethod: downPaymentMethod ?? this.downPaymentMethod,
        collateralAmount: collateralAmount ?? this.collateralAmount,
        collateralPaidAt: collateralPaidAt ?? this.collateralPaidAt,
        collateralMethod: collateralMethod ?? this.collateralMethod,
        remainingPaidAt: remainingPaidAt ?? this.remainingPaidAt,
        remainingMethod: remainingMethod ?? this.remainingMethod,
        idVerifiedAt: idVerifiedAt ?? this.idVerifiedAt,
        signatureData: signatureData ?? this.signatureData,
        signedName: signedName ?? this.signedName,
        signedAt: signedAt ?? this.signedAt,
      );
}
