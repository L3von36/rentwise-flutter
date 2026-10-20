import '../core/app_locale.dart';
import '../core/formatters.dart';
import 'rental_order.dart';

/// The three stages of the v1.26 payment plan, in collection order.
/// Money always fills them in policy sequence — down payment first,
/// then the remaining balance, then the collateral deposit.
enum PaymentBucket { downPayment, remaining, collateral }

extension PaymentBucketX on PaymentBucket {
  String get label => switch (this) {
        PaymentBucket.downPayment => AppLocale.t('Down payment'),
        PaymentBucket.remaining => AppLocale.t('Remaining balance'),
        PaymentBucket.collateral => AppLocale.t('Collateral (refundable)'),
      };
}

/// One real money movement on an order's ledger — a receipt the desk
/// actually pocketed (amount > 0) or a refund handed back to the
/// customer (amount < 0, collateral deposits only).
///
/// Receipts are append-only facts: corrections DELETE a receipt and are
/// owner-only. What stage the money belongs to is never stored — it is
/// DERIVED by [PaymentLedger] from the policy order, so a single cash
/// handover can honestly cover the down payment and the remaining
/// balance in one receipt.
class PaymentReceipt {
  final String id; // PAY-### (workspace-wide counter)
  final String orderId;
  final double amount;

  /// The Ethiopian rail the money moved on (cash / Telebirr / …).
  final PaymentMethod method;

  /// Optional free-text memo (receipt number, collector initials, …).
  final String note;
  final String recordedBy;
  final DateTime recordedAt;

  const PaymentReceipt({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.method,
    this.note = '',
    required this.recordedBy,
    required this.recordedAt,
  });

  bool get isRefund => amount < 0;

  /// Absolute value — what the desk actually saw move.
  double get magnitude => amount.abs();

  PaymentReceipt copyWith({String? note}) => PaymentReceipt(
        id: id,
        orderId: orderId,
        amount: amount,
        method: method,
        note: note ?? this.note,
        recordedBy: recordedBy,
        recordedAt: recordedAt,
      );
}

/// Half-a-cent tolerance for float money comparisons — cents exist in
/// this app, so equality is never tested with `==` on doubles.
const double kMoneyEps = 0.005;

/// Derived truth of an order's payment plan, computed from its receipts.
///
/// This is the single source of truth for "how much of each stage is
/// settled": it walks the receipts chronologically, fills the buckets in
/// policy order (down → remaining → collateral) and, for refunds, draws
/// money back in reverse order (collateral → remaining → down). A stage
/// counts as PAID the moment its running net reaches its target — the
/// crossing receipt's time and rail become the stage's paid-at/method,
/// exactly as the v1.26–v1.28 single-shot toggles used to record them.
class PaymentLedger {
  final double downTarget;
  final double remainingTarget;
  final double collateralTarget;

  /// Chronologically ordered receipts belonging to the order.
  final List<PaymentReceipt> receipts;

  const PaymentLedger._({
    required this.downTarget,
    required this.remainingTarget,
    required this.collateralTarget,
    required this.receipts,
    required this.downPaid,
    required this.remainingPaid,
    required this.collateralPaid,
    this.downPaidAt,
    this.remainingPaidAt,
    this.collateralPaidAt,
    this.downMethod,
    this.remainingMethod,
    this.collateralMethod,
  });

  final double downPaid;
  final double remainingPaid;
  final double collateralPaid;

  final DateTime? downPaidAt;
  final DateTime? remainingPaidAt;
  final DateTime? collateralPaidAt;

  final PaymentMethod? downMethod;
  final PaymentMethod? remainingMethod;
  final PaymentMethod? collateralMethod;

  /// Computes the ledger for [order] from every receipt in [all]
  /// (receipts for other orders are ignored).
  factory PaymentLedger.of(
    RentalOrder order,
    Iterable<PaymentReceipt> all,
  ) {
    final rs = all.where((r) => r.orderId == order.id).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    const eps = kMoneyEps;
    var d = 0.0, r = 0.0, c = 0.0;
    DateTime? dAt, rAt, cAt;
    PaymentMethod? dM, rM, cM;

    for (final rc in rs) {
      var amount = rc.amount;
      if (amount >= 0) {
        // Money in — fill the buckets in policy order: down → remaining
        // → collateral. A receipt may span buckets (one cash handover
        // settling the tail of the balance AND the deposit).
        void fill(
          double target,
          void Function(double) add,
          double Function() get,
          DateTime? Function() at,
          PaymentMethod? Function() method,
          void Function(DateTime, PaymentMethod) cross,
        ) {
          if (amount <= eps) return;
          if (target <= eps) return; // nothing due on this stage
          final room = target - get();
          if (room <= eps) return;
          final take = amount < room ? amount : room;
          add(take);
          amount -= take;
          if (get() >= target - eps) {
            cross(at() ?? rc.recordedAt, method() ?? rc.method);
          }
        }

        fill(order.downPayment, (v) => d += v, () => d, () => dAt, () => dM,
            (at, m) {
          dAt = at;
          dM = m;
        });
        fill(order.remainingDue, (v) => r += v, () => r, () => rAt, () => rM,
            (at, m) {
          rAt = at;
          rM = m;
        });
        fill(order.collateralAmount, (v) => c += v, () => c, () => cAt,
            () => cM, (at, m) {
          cAt = at;
          cM = m;
        });
        // Any dust beyond the full plan (cannot happen — state refuses
        // overpayment) is ignored, never silently credited.
      } else {
        // Money out — refunds draw back in REVERSE policy order:
        // collateral first, then remaining, then down. A stage that
        // drops below its target un-settles (and may re-settle later).
        var out = -amount;
        void drain(
          double target,
          void Function(double) sub,
          double Function() get,
          void Function() unset,
        ) {
          if (out <= eps || target <= eps) return;
          final held = get();
          if (held <= eps) return;
          final take = out < held ? out : held;
          sub(take);
          out -= take;
          if (get() < target - eps) unset();
        }

        drain(order.collateralAmount, (v) => c -= v, () => c, () {
          cAt = null;
          cM = null;
        });
        drain(order.remainingDue, (v) => r -= v, () => r, () {
          rAt = null;
          rM = null;
        });
        drain(order.downPayment, (v) => d -= v, () => d, () {
          dAt = null;
          dM = null;
        });
      }
    }

    return PaymentLedger._(
      downTarget: order.downPayment,
      remainingTarget: order.remainingDue,
      collateralTarget: order.collateralAmount,
      receipts: rs,
      downPaid: d,
      remainingPaid: r,
      collateralPaid: c,
      downPaidAt: dAt,
      remainingPaidAt: rAt,
      collateralPaidAt: cAt,
      downMethod: dM,
      remainingMethod: rM,
      collateralMethod: cM,
    );
  }

  // -- derived reads ---------------------------------------------------

  double paidFor(PaymentBucket b) => switch (b) {
        PaymentBucket.downPayment => downPaid,
        PaymentBucket.remaining => remainingPaid,
        PaymentBucket.collateral => collateralPaid,
      };

  double targetFor(PaymentBucket b) => switch (b) {
        PaymentBucket.downPayment => downTarget,
        PaymentBucket.remaining => remainingTarget,
        PaymentBucket.collateral => collateralTarget,
      };

  /// Net money still owed on one bucket (never negative).
  double outstandingFor(PaymentBucket b) =>
      (targetFor(b) - paidFor(b)).clamp(0, double.infinity);

  bool bucketSettled(PaymentBucket b) =>
      targetFor(b) <= kMoneyEps || paidFor(b) >= targetFor(b) - kMoneyEps;

  /// Money still owed across all three buckets.
  double get outstandingTotal => PaymentBucket.values
      .fold(0.0, (s, b) => s + outstandingFor(b));

  bool get fullySettled => outstandingTotal <= kMoneyEps;

  /// Collateral currently HELD (deposited minus refunded) — the amount
  /// the desk must hand back when the items return.
  double get collateralHeld => collateralPaid.clamp(0, double.infinity);

  /// First unsettled bucket with a target — what the next receipt will
  /// start filling (the record-payment dialog pre-fills this amount).
  ({PaymentBucket bucket, double amount})? get nextDue {
    for (final b in PaymentBucket.values) {
      final out = outstandingFor(b);
      if (targetFor(b) > kMoneyEps && out > kMoneyEps) {
        return (bucket: b, amount: out);
      }
    }
    return null;
  }

  /// Handover blockers, ledger-flavoured: stages show their live
  /// progress when partially paid. Empty = the items may leave.
  List<String> get handoverBlockers {
    const t = AppLocale.t;
    final blockers = <String>[];
    for (final b in PaymentBucket.values) {
      if (bucketSettled(b)) continue;
      final target = targetFor(b);
      final paid = paidFor(b);
      blockers.add(paid > kMoneyEps
          ? '${b.label} ${Fmt.moneySmart(paid)} / ${Fmt.moneySmart(target)} '
              '${t('partially received')}'
          : '${b.label} ${Fmt.moneySmart(target)} ${t('not received')}');
    }
    return blockers;
  }

  bool get canHandOver => handoverBlockers.isEmpty;

  /// How a NEW receipt of [amount] would fill the buckets — the honest
  /// preview the record-payment dialog shows BEFORE money is recorded.
  /// Pure math: the real ledger only changes when a receipt is stored.
  Map<PaymentBucket, double> allocationFor(double amount) {
    final applied = <PaymentBucket, double>{};
    var left = amount;
    for (final b in PaymentBucket.values) {
      if (left <= kMoneyEps) break;
      final room = outstandingFor(b);
      if (room <= kMoneyEps) continue;
      final take = left < room ? left : room;
      applied[b] = take;
      left -= take;
    }
    return applied;
  }

  /// Sums every receipt (in and out) of the given REAL rows — sanity
  /// anchor for the ledger header. Virtual/migration rows excluded by
  /// the caller.
  static double collectedTotal(Iterable<PaymentReceipt> rows) =>
      rows.where((r) => r.amount > 0).fold(0.0, (s, r) => s + r.amount);

  static double refundedTotal(Iterable<PaymentReceipt> rows) =>
      rows.where((r) => r.amount < 0).fold(0.0, (s, r) => s + -r.amount);
}
