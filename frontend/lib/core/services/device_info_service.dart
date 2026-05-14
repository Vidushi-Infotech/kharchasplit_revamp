import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Resolves a small payload describing this device, sent with login /
/// register requests so the backend can label sessions.
class DeviceInfoService {
  DeviceInfoService._();

  static Map<String, String>? _cached;

  /// Returns `{name, platform, osVersion, appVersion}` for this device.
  /// Caches the first successful read so subsequent calls are free.
  static Future<Map<String, String>> describe() async {
    if (_cached != null) return _cached!;
    final out = <String, String>{};
    try {
      final pkg = await PackageInfo.fromPlatform();
      out['appVersion'] = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {/* keep going */}

    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final w = await info.webBrowserInfo;
        out['name'] = w.browserName.name;
        out['platform'] = 'Web';
        out['osVersion'] = w.platform ?? '';
      } else if (Platform.isAndroid) {
        final a = await info.androidInfo;
        out['name'] = a.model.isEmpty ? a.manufacturer : '${a.manufacturer} ${a.model}';
        out['platform'] = 'Android';
        out['osVersion'] = 'Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        out['name'] = i.name; // user-set device name, e.g. "Shoaib's iPhone"
        out['platform'] = 'iOS';
        out['osVersion'] = '${i.systemName} ${i.systemVersion}';
      } else if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        out['name'] = m.computerName;
        out['platform'] = 'macOS';
        out['osVersion'] = 'macOS ${m.osRelease}';
      } else if (Platform.isWindows) {
        final w = await info.windowsInfo;
        out['name'] = w.computerName;
        out['platform'] = 'Windows';
        out['osVersion'] = 'Windows ${w.displayVersion}';
      } else if (Platform.isLinux) {
        final l = await info.linuxInfo;
        out['name'] = l.prettyName;
        out['platform'] = 'Linux';
        out['osVersion'] = l.version ?? '';
      }
    } catch (_) {/* keep going */}

    _cached = out;
    return out;
  }
}
