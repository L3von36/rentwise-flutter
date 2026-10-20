// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:rentwise/models/payment_receipt.dart';
import 'package:rentwise/models/rental_order.dart';
import 'package:rentwise/services/appwrite_backend.dart';

/// Pre-flight probe for the browser E2E run: verifies (1) owner login,
/// (2) workspace loads, (3) the v1.30 `payments` collection is LIVE and
/// writable on the cloud (a throwaway receipt is put then deleted).
///
/// Run: AW_E2E=1 flutter test test/e2e_probe_test.dart
class _TempPathProvider extends PathProviderPlatform {
  static int _n = 0;
  _TempPathProvider(this.root);
  final String root;
  String get _next => '$root/instance-${_n++}';

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final d = Directory(_next);
    await d.create(recursive: true);
    return d.path;
  }

  @override
  Future<String?> getTemporaryPath() async => _next;

  @override
  Future<String?> getApplicationSupportPath() async => _next;
}

void main() {
  final enabled = Platform.environment['AW_E2E'] == '1';
  final tmp = Directory.systemTemp.createTempSync('rentwise_e2e_probe');
  PathProviderPlatform.instance = _TempPathProvider(tmp.path);

  test('probe: login + workspace + payments collection writability',
      timeout: const Timeout(Duration(minutes: 4)), () async {
    if (!enabled) {
      print('AW_E2E not set — skipping.');
      return;
    }
    final backend = AppwriteBackend();
    final account = await backend.authenticate(
      'selamvenda8@gmail.com',
      'selam@336',
    );
    print('[probe] auth OK: ${account.name} role=${account.role}');

    final snap = await backend.loadWorkspace();
    print('[probe] workspace "${snap.activeWorkspace}": '
        '${snap.inventory.length} items, ${snap.orders.length} orders, '
        '${snap.customers.length} customers, ${snap.payments.length} payments');
    for (final o in snap.orders) {
      print('[probe]   order #${o.id} "${o.eventName}" status=${o.status.name} '
          'total=${o.total.toStringAsFixed(0)} lines=${o.lineItems.length}');
    }
    expect(snap.orders, isNotEmpty);

    // Writability check on the payments collection — throwaway receipt
    // on a probe-only order id, deleted right after.
    final probe = PaymentReceipt(
      id: 'PAY-E2E-PROBE',
      orderId: 'E2E-PROBE-ORDER',
      amount: 1.0,
      method: PaymentMethod.cash,
      note: 'e2e writability probe — self-cleaning',
      recordedBy: 'probe',
      recordedAt: DateTime.now().toUtc(),
    );
    try {
      await backend.putPayment(probe);
      print('[probe] payments collection: WRITE OK');
      await backend.deletePayment(probe.id);
      print('[probe] payments collection: DELETE OK (cleaned up)');
    } catch (e) {
      print('[probe] payments collection: UNAVAILABLE → $e');
      fail('payments collection not writable — run scripts/appwrite_provision.sh');
    }
  });
}
