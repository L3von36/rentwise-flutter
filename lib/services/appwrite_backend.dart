import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appwrite/appwrite.dart' as aw;
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'appwrite_config.dart';
import '../data/appwrite_mappers.dart';
import '../models/account.dart';
import '../models/activity_entry.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../models/pickup.dart';
import '../models/rental_order.dart';

/// Everything the workspace needs after a successful sign-in.
class WorkspaceSnapshot {
  final String accountUserId;
  final List<InventoryItem> inventory;
  final List<RentalOrder> orders;
  final List<Customer> customers;
  final List<ActivityEntry> activity;
  final List<Pickup> pickups;
  final List<String> workspaces;
  final String activeWorkspace;
  final double grossMonthK;
  final double utilizationPct;
  final List<RevenuePoint> earnings;
  final List<CategoryRevenue> categoryRevenue;
  final List<RevenuePoint> trend;

  const WorkspaceSnapshot({
    required this.accountUserId,
    required this.inventory,
    required this.orders,
    required this.customers,
    required this.activity,
    required this.pickups,
    required this.workspaces,
    required this.activeWorkspace,
    required this.grossMonthK,
    required this.utilizationPct,
    required this.earnings,
    required this.categoryRevenue,
    required this.trend,
  });
}

/// Real backend: Appwrite Cloud (auth + database).
///
/// The Flutter SDK is client-only — every call below runs with the
/// signed-in user's session, and collection permissions are granted to
/// `users`. Collection ids/attributes are provisioned by
/// `scripts/appwrite_provision.sh`; the one-shot harness in
/// `test/seed_appwrite_test.dart` fills the live workspace dataset.
class AppwriteBackend {
  AppwriteBackend() {
    _client = aw.Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId);
  }

  /// Per-request budget. If the network black-holes the connection (VPN,
  /// firewall, dropped Wi-Fi) we fail fast with a clear TimeoutException
  /// instead of leaving the sign-in button spinning forever.
  static const Duration _callTimeout = Duration(seconds: 20);
  static const Duration _bulkTimeout = Duration(seconds: 30);

  late final aw.Client _client;
  late final aw.Account _account = aw.Account(_client);
  late final aw.Databases _db = aw.Databases(_client);

  String? _userId;

  // ------------------------------------------------------------------- auth

  /// Signs the user in and resolves their workspace profile (role, title).
  /// Returns the account; throws [AppwriteException] on failure.
  Future<Account> authenticate(String email, String password) async {
    try {
      await _account
          .createEmailPasswordSession(email: email, password: password)
          .timeout(_callTimeout);
    } on aw.AppwriteException catch (e) {
      if (e.code != 401 || e.type != 'user_session_already_exists') rethrow;
      // An active session is fine — continue with it.
    }
    final user = await _account.get().timeout(_callTimeout);
    _userId = user.$id;

    final profile = await _findProfile(user.$id).timeout(_callTimeout);
    if (profile != null) {
      final d = profile.data;
      return Account(
        name: (d['name'] ?? user.name) as String? ?? user.name,
        email: (d['email'] ?? user.email) as String? ?? user.email,
        role: (d['role'] ?? 'employee') == 'owner'
            ? UserRole.owner
            : UserRole.employee,
        initials: initialsFor(
            (d['name'] ?? user.name) as String? ?? user.name),
        title: (d['title'] ?? '') as String? ?? '',
      );
    }

    // First-ever sign-in of an unprovisioned user. Bootstrap rule: if
    // NO owner profile exists yet, this account becomes the owner —
    // otherwise it joins as a safe employee and is promoted by the
    // owner in Access & roles. Owner access is never granted when an
    // owner already exists.
    final bootstrapOwner = !(await _hasOwner());
    final provisioned = Account(
      name: user.name.isEmpty ? email : user.name,
      email: user.email,
      role: bootstrapOwner ? UserRole.owner : UserRole.employee,
      initials: initialsFor(user.name.isEmpty ? email : user.name),
      title: bootstrapOwner ? 'Workspace owner' : 'Team member',
    );
    await _db.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.colProfiles,
      documentId: user.$id,
      data: {
        'userId': user.$id,
        'name': provisioned.name,
        'email': provisioned.email,
        'role': bootstrapOwner ? 'owner' : 'employee',
        'title': provisioned.title,
      },
    );
    return provisioned;
  }

  /// Creates a new Appwrite account (sign-up), then signs it in and
  /// provisions the profile through [authenticate]. Throws
  /// [AppwriteException] on failure (existing email, weak password…).
  Future<Account> registerAccount(
      String name, String email, String password) async {
    await _account
        .create(
          userId: aw.ID.unique(),
          email: email,
          password: password,
          name: name,
        )
        .timeout(_callTimeout);
    return authenticate(email, password);
  }

  /// True when at least one profile with role `owner` exists.
  Future<bool> _hasOwner() async {
    final res = await _db.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.colProfiles,
      queries: [aw.Query.equal('role', 'owner'), aw.Query.limit(1)],
    );
    return res.documents.isNotEmpty;
  }

  /// Owner-only danger action: permanently deletes every document in
  /// the business collections (inventory, orders, customers, activity,
  /// pickups) and zeroes the metrics document. Profiles, workspaces
  /// and the auth account itself are kept. Throws on failure so the
  /// caller can surface an honest error.
  Future<void> resetWorkspaceData() async {
    const collections = [
      AppwriteConfig.colInventory,
      AppwriteConfig.colOrders,
      AppwriteConfig.colCustomers,
      AppwriteConfig.colActivities,
      AppwriteConfig.colPickups,
    ];
    for (final c in collections) {
      // Re-list after every delete batch — deletions shift the result
      // set. Hard-capped so a partial permission failure can't loop.
      for (var sweep = 0; sweep < 500; sweep++) {
        final res = await _db.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: c,
          queries: [aw.Query.limit(100)],
        ).timeout(_bulkTimeout);
        if (res.documents.isEmpty) break;
        for (final d in res.documents) {
          await _db.deleteDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: c,
            documentId: d.$id,
          );
        }
      }
    }
    final resetMetrics = {
      'grossMonth': 0,
      'utilization': 0,
      'earningsJson': '[]',
      'categoryJson': '[]',
    };
    try {
      await _db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.colMetrics,
        documentId: 'main',
        data: resetMetrics,
      ).timeout(_callTimeout);
    } catch (_) {
      // No metrics document yet — create it zeroed.
      try {
        await _db.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.colMetrics,
          documentId: 'main',
          data: resetMetrics,
        ).timeout(_callTimeout);
      } catch (e) {
        debugPrint('Appwrite[metrics.reset] $e');
      }
    }
  }

  Future<models.Document?> _findProfile(String userId) async {
    final res = await _db.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.colProfiles,
      queries: [aw.Query.equal('userId', userId), aw.Query.limit(1)],
    );
    return res.documents.isEmpty ? null : res.documents.first;
  }

  Future<void> signOutAccount() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (e) {
      debugPrint('Appwrite[signOut] $e');
    }
    _userId = null;
  }

  // ------------------------------------------------------------ data load

  /// Lists EVERY document in a collection, following cursors page by
  /// page. The old one-shot `limit(200)` load silently truncated larger
  /// workspaces — with 200+ rows the dashboard numbers simply stopped
  /// being true. Page size stays at 100 (safe on every Appwrite plan).
  Future<List<models.Document>> _listAll(
    String collectionId, {
    List<String> extraQueries = const [],
    int pageSize = 100,
    int maxPages = 100,
  }) async {
    final docs = <models.Document>[];
    var cursor = '';
    for (var page = 0; page < maxPages; page++) {
      final res = await _db
          .listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: collectionId,
            queries: [
              ...extraQueries,
              aw.Query.limit(pageSize),
              if (cursor.isNotEmpty) aw.Query.cursorAfter(cursor),
            ],
          )
          .timeout(_bulkTimeout);
      docs.addAll(res.documents);
      if (res.documents.length < pageSize) break;
      cursor = res.documents.last.$id;
    }
    return docs;
  }

  /// Pulls every workspace collection. A hard failure (network, auth)
  /// propagates to the caller — sign-in fails with an honest error and
  /// nothing is faked locally.
  Future<WorkspaceSnapshot> loadWorkspace() async {
    final inv = _listAll(AppwriteConfig.colInventory);
    final ord = _listAll(AppwriteConfig.colOrders);
    final cus = _listAll(AppwriteConfig.colCustomers);
    final act =
        _listAll(AppwriteConfig.colActivities, extraQueries: [
          aw.Query.orderDesc('at'),
        ]);
    final pks = _listAll(AppwriteConfig.colPickups);
    final wrk = _listAll(AppwriteConfig.colWorkspaces);
    final met = _getMetricsDoc();

    final r = await Future.wait([
      inv,
      ord,
      cus,
      act,
      pks,
      wrk,
    ]).timeout(_bulkTimeout);

    final metRes = await met;
    final m = metRes?.data ?? const {};

    final activeWs =
        _userId == null ? '' : await _activeWorkspaceFor(_userId!);

    return WorkspaceSnapshot(
      accountUserId: _userId ?? '',
      inventory: r[0].map(inventoryFromDoc).toList(),
      orders: r[1].map(orderFromDoc).toList(),
      customers: r[2].map(customerFromDoc).toList(),
      activity: r[3].map(activityFromDoc).toList(),
      pickups: r[4].map(pickupFromDoc).toList(),
      workspaces: r[5]
          .map((d) => (d.data['name'] ?? '') as String)
          .where((n) => n.isNotEmpty)
          .toList(),
      activeWorkspace: activeWs,
      grossMonthK:
          ((m['grossMonth'] ?? 0) as num).toDouble(),
      utilizationPct:
          ((m['utilization'] ?? 0) as num).toDouble(),
      earnings: pointsFromJson(m['earningsJson']),
      categoryRevenue: categoriesFromJson(m['categoryJson']),
      trend: pointsFromJson(m['trendJson']),
    );
  }

  Future<models.Document?> _getMetricsDoc() async {
    try {
      return await _db.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.colMetrics,
        documentId: 'main',
      );
    } catch (e) {
      debugPrint('Appwrite[metrics] $e');
      return null;
    }
  }

  /// Returns '' when the user has no saved workspace preference — the
  /// caller then falls back to the first workspace the account can see.
  ///
  /// Reads the per-user `user_prefs` document (the only profile-
  /// adjacent document a client may write); falls back to the legacy
  /// `profiles.activeWorkspace` attribute for older accounts.
  Future<String> _activeWorkspaceFor(String userId) async {
    try {
      final prefs = await _db.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.colUserPrefs,
        documentId: userId,
      );
      final saved = (prefs.data['activeWorkspace'] ?? '') as String? ?? '';
      if (saved.isNotEmpty) return saved;
    } catch (_) {
      // No prefs doc (or prefs collection not provisioned yet) — fall
      // through to the legacy profile attribute.
    }
    try {
      final p = await _findProfile(userId);
      return (p?.data['activeWorkspace'] ?? '') as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  // --------------------------------------------------------- write-through

  Future<void> putInventoryItem(InventoryItem item, {bool isNew = false}) =>
      _upsert(
        AppwriteConfig.colInventory,
        item.id,
        {
          'name': item.name,
          'note': item.note,
          'category': item.category,
          'totalStock': item.totalStock,
          'available': item.available,
          'maintenance': item.maintenance,
          'ratePerDay': item.ratePerDay,
          'iconKey': iconKeyFor(item.icon),
        },
        isNew: isNew,
        // Clouds provisioned before the `maintenance` attribute reject
        // the new key with 400 — retry without it so the stock numbers
        // still persist (see scripts/appwrite_provision.sh to upgrade).
        fallbackData: {
          'name': item.name,
          'note': item.note,
          'category': item.category,
          'totalStock': item.totalStock,
          'available': item.available,
          'ratePerDay': item.ratePerDay,
          'iconKey': iconKeyFor(item.icon),
        },
      );

  Future<void> putOrder(RentalOrder order, {bool isNew = false}) => _upsert(
        AppwriteConfig.colOrders,
        order.id,
        {
          'eventName': order.eventName,
          'customerName': order.customerName,
          'contactName': order.contactName,
          'createdAt': awDate(order.createdAt),
          'eventDate': awDate(order.eventDate),
          'itemCount': order.itemCount,
          'total': order.total,
          'status': statusToDoc(order.status),
          'notes': order.notes,
          'linesJson': orderLinesToDoc(order.lineItems),
        },
        isNew: isNew,
      );

  Future<void> putCustomer(Customer customer, {bool isNew = false}) =>
      _upsert(
        AppwriteConfig.colCustomers,
        customer.id,
        {
          'name': customer.name,
          'company': customer.company,
          'email': customer.email,
          'phone': customer.phone,
          'rentals': customer.rentals,
          'lifetimeSpend': customer.lifetimeSpend,
          'lastBooking': awDate(customer.lastBooking),
          'avatarColorIndex': avatarColorIndex(customer.avatarColor),
        },
        isNew: isNew,
      );

  Future<void> putActivity(ActivityEntry entry) => _upsert(
        AppwriteConfig.colActivities,
        entry.id,
        {
          'actor': entry.actor,
          'actorInitials': entry.actorInitials,
          'actorColorIndex': actorColorIndex(entry.actorColor),
          'at': awDate(entry.at),
          'type': activityTypeToDoc(entry.type),
          'body': entry.body,
        },
        isNew: true,
      );

  Future<void> putWorkspace(String name, {required String createdBy}) {
    final id = slugFor(name);
    return _upsert(
      AppwriteConfig.colWorkspaces,
      id,
      {
        'name': name,
        'createdAt': awDate(DateTime.now()),
        'createdBy': createdBy,
      },
      isNew: true,
    );
  }

  /// Saves the user's active workspace into their own `user_prefs`
  /// document (document-level security: only this user may read/write
  /// it). Profiles are read- + create-only for clients — a profile's
  /// role is fixed at creation and can never be changed from the app.
  Future<void> setActiveWorkspace(String name) async {
    final uid = _userId;
    if (uid == null) return;
    final data = {'activeWorkspace': name};
    try {
      await _db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.colUserPrefs,
        documentId: uid,
        data: data,
      );
    } on aw.AppwriteException catch (e) {
      if (e.code != 404) {
        debugPrint('Appwrite[userPrefs.$uid] $e');
        return;
      }
      // First save — create the user's prefs doc scoped to them.
      try {
        await _db.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.colUserPrefs,
          documentId: uid,
          data: data,
          permissions: [
            aw.Permission.read(aw.Role.user(uid)),
            aw.Permission.update(aw.Role.user(uid)),
            aw.Permission.delete(aw.Role.user(uid)),
          ],
        );
      } catch (e2) {
        debugPrint('Appwrite[userPrefs.$uid.create] $e2');
      }
    } catch (e) {
      debugPrint('Appwrite[userPrefs.$uid] $e');
    }
  }

  Future<void> _upsert(String collection, String id, Map<String, dynamic> data,
      {bool isNew = false, Map<String, dynamic>? fallbackData}) async {
    Future<void> write(Map<String, dynamic> d) async {
      if (isNew) {
        try {
          await _db.createDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: collection,
            documentId: id,
            data: d,
          );
          return;
        } on aw.AppwriteException catch (e) {
          if (e.code != 409) rethrow;
          // Document exists — fall through to an update (idempotent replay).
        }
      }
      await _db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: collection,
        documentId: id,
        data: d,
      );
    }

    try {
      await write(data);
    } on aw.AppwriteException catch (e) {
      if (fallbackData != null && e.code == 400) {
        // Schema predates a newly added attribute — write the reduced
        // payload so the rest of the data still persists.
        try {
          await write(fallbackData);
          return;
        } catch (e2) {
          debugPrint('Appwrite[$collection.$id] fallback write: $e2');
          rethrow; // surface — the state layer shows a sync notice
        }
      }
      debugPrint('Appwrite[$collection.$id] $e');
      rethrow; // surface — the state layer shows a sync notice
    } catch (e) {
      debugPrint('Appwrite[$collection.$id] $e');
      rethrow;
    }
  }

  // ------------------------------------------------------------- decoding

  static InventoryItem inventoryFromDoc(models.Document d) {
    final data = d.data;
    return InventoryItem(
      id: d.$id,
      name: (data['name'] ?? '') as String,
      note: (data['note'] ?? '') as String,
      category: (data['category'] ?? '') as String,
      totalStock: (data['totalStock'] ?? 0) as int,
      available: (data['available'] ?? 0) as int,
      maintenance: (data['maintenance'] ?? false) == true,
      ratePerDay: ((data['ratePerDay'] ?? 0) as num).toDouble(),
      icon: kInventoryIcons[(data['iconKey'] ?? '') as String? ?? ''] ??
          Icons.inventory_2_outlined,
    );
  }

  static RentalOrder orderFromDoc(models.Document d) {
    final data = d.data;
    return RentalOrder(
      id: d.$id,
      eventName: (data['eventName'] ?? '') as String,
      customerName: (data['customerName'] ?? '') as String,
      contactName: (data['contactName'] ?? '') as String? ?? '',
      createdAt: dateFromDoc((data['createdAt'] ?? awDate(DateTime.now())) as String),
      eventDate: dateFromDoc((data['eventDate'] ?? awDate(DateTime.now())) as String),
      itemCount: (data['itemCount'] ?? 0) as int,
      total: ((data['total'] ?? 0) as num).toDouble(),
      status: statusFromDoc((data['status'] ?? 'preparing') as String),
      notes: (data['notes'] ?? '') as String? ?? '',
      lineItems: orderLinesFromDoc((data['linesJson'] ?? '[]') as String? ?? '[]'),
    );
  }

  static Customer customerFromDoc(models.Document d) {
    final data = d.data;
    return Customer(
      id: d.$id,
      name: (data['name'] ?? '') as String,
      company: (data['company'] ?? '') as String? ?? '',
      email: (data['email'] ?? '') as String? ?? '',
      phone: (data['phone'] ?? '') as String? ?? '',
      rentals: (data['rentals'] ?? 0) as int,
      lifetimeSpend: ((data['lifetimeSpend'] ?? 0) as num).toDouble(),
      lastBooking:
          dateFromDoc((data['lastBooking'] ?? awDate(DateTime.now())) as String),
      avatarColor: avatarColorFromIndex((data['avatarColorIndex'] ?? 0) as int? ?? 0),
    );
  }

  static ActivityEntry activityFromDoc(models.Document d) {
    final data = d.data;
    return ActivityEntry(
      id: d.$id,
      actor: (data['actor'] ?? '') as String,
      actorInitials: (data['actorInitials'] ?? '') as String? ?? '',
      actorColor: actorColorFromIndex((data['actorColorIndex'] ?? 0) as int? ?? 0),
      at: dateFromDoc((data['at'] ?? awDate(DateTime.now())) as String),
      type: activityTypeFromDoc((data['type'] ?? 'note') as String),
      body: (data['body'] ?? '') as String,
    );
  }

  static Pickup pickupFromDoc(models.Document d) {
    final data = d.data;
    return Pickup(
      id: d.$id,
      date: dateFromDoc((data['date'] ?? awDate(DateTime.now())) as String),
      title: (data['title'] ?? '') as String,
      venue: (data['venue'] ?? '') as String? ?? '',
      itemCount: (data['itemCount'] ?? 0) as int,
      contactName: (data['contactName'] ?? '') as String? ?? '',
    );
  }

  static List<RevenuePoint> pointsFromJson(Object? raw) {
    if (raw is! String || raw.isEmpty || raw == '[]') return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RevenuePoint(
                day: dateFromDoc((e['day'] ?? '') as String),
                value: ((e['value'] ?? 0) as num).toDouble(),
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static List<CategoryRevenue> categoriesFromJson(Object? raw) {
    if (raw is! String || raw.isEmpty || raw == '[]') return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CategoryRevenue(
                category: (e['category'] ?? '') as String,
                amount: ((e['amount'] ?? 0) as num).toDouble(),
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Human-friendly message for sign-in failures. The first line is for
  /// the user; a short diagnostic tail tells us (and support) what really
  /// happened instead of hiding every failure behind one generic string.
  static String authErrorText(Object error) {
    if (error is NoProfileException) return error.message;
    if (error is aw.AppwriteException) {
      switch (error.type) {
        case 'user_invalid_credentials':
        case 'user_email_not_found':
          return 'Email or password is incorrect.';
        case 'user_blocked':
          return 'This account has been suspended.';
        case 'general_rate_limit_exceeded':
          return 'Too many attempts — wait a moment and try again.';
        case 'general_unknown_origin':
          // Appwrite's message names the exact client to register, e.g.
          // "Register your new client (com.rentwise.rentwise) as a new
          // Windows platform ..." — surface that identifier.
          final id = RegExp(r'\(([^)]+)\)')
              .firstMatch(error.message ?? '')
              ?.group(1);
          return 'Appwrite does not recognize this app origin'
              '${id == null ? '' : ' ($id)'} — register it under Platforms '
              'in the Appwrite console (project rentwise), then try again.';
      }
      if (error.code == 429) {
        return 'Too many attempts — wait a moment and try again.';
      }
      // Real API response (e.g. 401 general_unauthorized_scope, 403
      // project rate/platform issues): surface it instead of masking.
      final msg = (error.message ?? '').toString();
      final short = msg.length > 90 ? '${msg.substring(0, 90)}…' : msg;
      final type = error.type ?? '';
      return 'Appwrite error ${error.code ?? '??'}${type.isEmpty ? '' : ' ($type)'} — $short';
    }
    if (error is SocketException) {
      final addr = error.address?.address ?? 'cloud.appwrite.io';
      final osErr = error.osError?.errorCode;
      final why = switch (osErr) {
        7 /* EAI_AGAIN DNS */ || -2 => 'DNS lookup failed for $addr',
        111 || 10061 => 'connection refused by $addr (VPN/proxy/firewall?)',
        101 || 10060 => 'network unreachable (offline or VPN required)',
        104 || 10054 => 'connection reset by $addr (firewall or antivirus?)',
        null => 'cannot connect to $addr',
        _ => 'cannot connect to $addr (errno $osErr)',
      };
      return 'Cannot reach Appwrite Cloud — $why.';
    }
    if (error is HandshakeException) {
      return 'Secure connection to Appwrite Cloud failed — a proxy, VPN or '
          'antivirus may be intercepting TLS certificates.';
    }
    if (error is http.ClientException) {
      final why = error.uri == null
          ? error.message
          : '${error.message} (${error.uri!.host})';
      return 'Cannot reach Appwrite Cloud — $why. If this happens in a '
          'browser, the site domain may not be registered in the '
          'Appwrite console.';
    }
    if (error is TimeoutException) {
      return 'Appwrite Cloud did not respond in time — check your '
          'connection or try a different network.';
    }
    final s = error.toString();
    final short = s.length > 110 ? '${s.substring(0, 110)}…' : s;
    return 'Sign-in failed — $short';
  }
}

/// Thrown when a signed-in Appwrite user cannot get a workspace profile
/// (the profiles lookup fails or bootstrap is impossible). The client
/// never grants roles silently — the user gets an actionable message.
class NoProfileException implements Exception {
  final String message;
  NoProfileException()
      : message = 'This account is not assigned to a RentWise workspace yet.\n'
            'Ask the workspace owner to provision your employee profile.';

  @override
  String toString() => message;
}

/// Shared helpers (also used by the seeding harness).
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '??';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String slugFor(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Metrics JSON encoders (seeding harness side).
String pointsToJson(List<RevenuePoint> points) => jsonEncode(points
    .map((p) => {'day': awDate(p.day), 'value': p.value})
    .toList());

String categoriesToJson(List<CategoryRevenue> cats) => jsonEncode(cats
    .map((c) => {'category': c.category, 'amount': c.amount})
    .toList());
