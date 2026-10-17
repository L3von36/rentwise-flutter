import 'dart:async';
import 'dart:io';

/// Teaches Dart's HTTP stack about the OS-level system proxy.
///
/// Dart's `HttpClient` honours `http_proxy`/`https_proxy` environment
/// variables but never reads the proxy that desktop OSes configure in
/// their network settings — exactly what VPN/proxy clients toggle with
/// their "system proxy" switch. On such machines every Appwrite request
/// failed with "cannot reach Appwrite Cloud" while browsers worked fine.
///
/// Windows: per-user WinINET settings (Registry). macOS: `scutil --proxy`.
/// Linux: environment variables are already honoured — no-op needed.
/// Discovery failures are swallowed: worst case we behave like before.
Future<void> applySystemProxy() async {
  try {
    if (Platform.isWindows) {
      await _applyWindowsProxy();
    } else if (Platform.isMacOS) {
      await _applyMacProxy();
    }
  } catch (_) {
    // Proxy discovery must never break app startup.
  }
}

Future<void> _applyWindowsProxy() async {
  final res = await Process.run('reg', [
    'query',
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
  ]);
  if (res.exitCode != 0) return;
  final out = res.stdout as String;
  if (!RegExp(r'ProxyEnable\s+REG_DWORD\s+0x1').hasMatch(out)) return;
  final m = RegExp(r'ProxyServer\s+REG_SZ\s+(\S+)').firstMatch(out);
  if (m == null) return;
  final raw = m.group(1)!;

  // Two shapes: "host:port" or "http=host:port;https=host:port;...;<local>"
  String? proxyFor(String scheme) {
    if (raw.contains('=')) {
      for (final part in raw.split(';')) {
        final kv = part.split('=');
        if (kv.length == 2 && kv[0].trim() == scheme && kv[1].trim().isNotEmpty) {
          return 'PROXY ${kv[1].trim()}';
        }
      }
      return null;
    }
    return 'PROXY $raw';
  }

  applyOverrides(httpFor: proxyFor('http'), httpsFor: proxyFor('https'));
}

Future<void> _applyMacProxy() async {
  final res = await Process.run('scutil', ['--proxy']);
  if (res.exitCode != 0) return;
  final out = res.stdout as String;
  String? proxyFor(String scheme) {
    final enabled =
        RegExp('$scheme Enable : 1').hasMatch(out); // HTTPEnable / HTTPSEnable
    if (!enabled) return null;
    final host = RegExp('$scheme Proxy : (\\S+)').firstMatch(out)?.group(1);
    final port = RegExp('$scheme Port : (\\d+)').firstMatch(out)?.group(1);
    if (host == null || port == null) return null;
    return 'PROXY $host:$port';
  }

  applyOverrides(httpFor: proxyFor('HTTP'), httpsFor: proxyFor('HTTPS'));
}

/// Installs an [HttpOverrides] that routes requests through the discovered
/// system proxy. HTTPS goes through the https proxy when one is configured,
/// falling back to the http proxy (standard browser behaviour).
void applyOverrides({String? httpFor, String? httpsFor}) {
  if (httpFor == null && httpsFor == null) return;
  HttpOverrides.global = _SystemProxyOverrides(httpFor, httpsFor);
}

class _SystemProxyOverrides extends HttpOverrides {
  _SystemProxyOverrides(this.httpProxy, this.httpsProxy);

  final String? httpProxy;
  final String? httpsProxy;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 15);
    client.findProxy = (uri) {
      final proxy =
          uri.scheme == 'https' ? (httpsProxy ?? httpProxy) : (httpProxy ?? httpsProxy);
      return proxy ?? 'DIRECT';
    };
    return client;
  }
}
