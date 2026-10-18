// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rentwise/data/appwrite_mappers.dart';
import 'fixtures/sample_dataset.dart';
import 'package:rentwise/services/appwrite_backend.dart';
import 'package:rentwise/services/appwrite_config.dart';

/// One-shot provisioning harness for the Appwrite backend.
///
/// Run with:
///   AW_KEY=<api key> AW_SEED=1 flutter test test/seed_appwrite_test.dart
///
/// Upserts the full workspace dataset from [SampleDataset] into Appwrite Cloud using
/// stable document ids, so it is idempotent — re-running refreshes the
/// seeded values without duplicating documents. Without the env vars the
/// suite exits immediately (CI-safe).
void main() {
  final key = Platform.environment['AW_KEY'];
  final enabled = Platform.environment['AW_SEED'] == '1';

  test('seed workspace data to Appwrite', () async {
    if (!enabled) {
      print('AW_SEED not set — skipping Appwrite seeding.');
      return;
    }
    expect(key, isNotNull, reason: 'AW_KEY must hold a databases+users API key');

    final api = SeedApi(key!);
    final now = DateTime.now();

    // ------------------------------------------------------ profiles
    await api.put(AppwriteConfig.colProfiles, 'owner-tinsae', {
      'userId': 'owner-tinsae',
      'name': 'Tinsae Abeba',
      'email': 'selamvenda8@gmail.com',
      'role': 'owner',
      'title': 'Workspace owner',
      'activeWorkspace': SampleDataset.workspaceName,
    });
    await api.put(AppwriteConfig.colProfiles, 'employee-jordan', {
      'userId': 'employee-jordan',
      'name': 'Jordan Miller',
      'email': 'jordan@riverside.events',
      'role': 'employee',
      'title': 'Operations associate',
      'activeWorkspace': SampleDataset.workspaceName,
    });

    // ------------------------------------------------------ inventory
    final items = SampleDataset.inventory();
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await api.put(AppwriteConfig.colInventory, item.id, {
        'name': item.name,
        'note': item.note,
        'category': item.category,
        'totalStock': item.totalStock,
        'available': item.available,
        'maintenance': item.maintenance,
        'ratePerDay': item.ratePerDay,
        'iconKey': iconKeyFor(item.icon),
        'sortIndex': i,
      });
    }

    // ------------------------------------------------------ customers
    for (final c in SampleDataset.customers(now)) {
      await api.put(AppwriteConfig.colCustomers, c.id, {
        'name': c.name,
        'company': c.company,
        'email': c.email,
        'phone': c.phone,
        'rentals': c.rentals,
        'lifetimeSpend': c.lifetimeSpend,
        'lastBooking': awDate(c.lastBooking),
        'avatarColorIndex': avatarColorIndex(c.avatarColor),
      });
    }

    // --------------------------------------------------------- orders
    for (final o in SampleDataset.orders(now)) {
      await api.put(AppwriteConfig.colOrders, o.id, {
        'eventName': o.eventName,
        'customerName': o.customerName,
        'contactName': o.contactName,
        'createdAt': awDate(o.createdAt),
        'eventDate': awDate(o.eventDate),
        'itemCount': o.itemCount,
        'total': o.total,
        'status': statusToDoc(o.status),
        'notes': o.notes,
        'linesJson': orderLinesToDoc(o.lineItems),
      });
    }

    // ------------------------------------------------------ activities
    for (final a in SampleDataset.activity(now)) {
      await api.put(AppwriteConfig.colActivities, a.id, {
        'actor': a.actor,
        'actorInitials': a.actorInitials,
        'actorColorIndex': actorColorIndex(a.actorColor),
        'at': awDate(a.at),
        'type': activityTypeToDoc(a.type),
        'body': a.body,
      });
    }

    // -------------------------------------------------------- pickups
    for (final p in SampleDataset.pickups(now)) {
      await api.put(AppwriteConfig.colPickups, p.id, {
        'date': awDate(p.date),
        'title': p.title,
        'venue': p.venue,
        'itemCount': p.itemCount,
        'contactName': p.contactName,
      });
    }

    // ----------------------------------------------------- workspaces
    await api.put(AppwriteConfig.colWorkspaces, 'riverside-events', {
      'name': SampleDataset.workspaceName,
      'createdAt': awDate(now),
      'createdBy': 'Tinsae Abeba',
    });

    // -------------------------------------------------------- metrics
    await api.put(AppwriteConfig.colMetrics, 'main', {
      'grossMonth': SampleDataset.grossRevenueMonth,
      'utilization': SampleDataset.utilizationPct,
      'earningsJson': pointsToJson(SampleDataset.earningsDaily(now)),
      'trendJson': pointsToJson(SampleDataset.revenueTrend(now)),
      'categoryJson': categoriesToJson(SampleDataset.categoryRevenue),
    });

    print('SEEDED: inventory=${items.length} '
        'orders=${SampleDataset.orders(now).length} '
        'customers=${SampleDataset.customers(now).length} '
        'activities=${SampleDataset.activity(now).length} '
        'pickups=${SampleDataset.pickups(now).length}');
  });
}

/// Minimal Appwrite REST client for the seeding harness (API-key auth).
///
/// The Flutter SDK is client-only (no API-key support), so seeding talks
/// to the same REST endpoints directly over dart:io.
class SeedApi {
  SeedApi(this.key);

  final String key;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);

  /// Upserts one document (Appwrite 2.x `upsert` query param).
  Future<void> put(
      String collection, String documentId, Map<String, dynamic> body) async {
    await _send(
      'POST',
      '/databases/${AppwriteConfig.databaseId}'
      '/collections/$collection/documents',
      {
        'documentId': documentId,
        'data': body,
      },
      query: 'upsert=true',
    );
  }

  Future<Map<String, dynamic>> _send(
      String method, String path, Map<String, dynamic>? body,
      {String query = ''}) async {
    final uri = Uri.parse(
        '${AppwriteConfig.endpoint}$path${query.isEmpty ? '' : '?$query'}');
    final req = await _client.openUrl(method, uri);
    req.headers.set('X-Appwrite-Project', AppwriteConfig.projectId);
    req.headers.set('X-Appwrite-Key', key);
    req.headers.set('Content-Type', 'application/json');
    if (body != null) {
      req.add(utf8.encode(jsonEncode(body)));
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 300) {
      throw StateError('Appwrite $method $path -> ${res.statusCode}: '
          '${text.length > 300 ? text.substring(0, 300) : text}');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }
}
