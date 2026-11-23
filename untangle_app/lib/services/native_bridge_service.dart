import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridgeService {
  static const MethodChannel channel = MethodChannel('com.amanjoshi.untangle_app/native');

  static Future<bool> syncReflectionReminders({
    required bool enabled,
    required String amTime24,
    required String pmTime24,
  }) async {
    if (kIsWeb) return enabled;
    final amParts = _parseHm(amTime24, 8, 30);
    final pmParts = _parseHm(pmTime24, 20, 30);
    try {
      final ok = await channel.invokeMethod<bool>('configureReminders', {
        'enabled': enabled,
        'amHour': amParts.$1,
        'amMinute': amParts.$2,
        'pmHour': pmParts.$1,
        'pmMinute': pmParts.$2,
      });
      return ok ?? enabled;
    } on MissingPluginException {
      return enabled;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> saveExportDocument({
    required String filename,
    required String mimeType,
    required String content,
  }) async {
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: content));
      return true;
    }
    try {
      final ok = await channel.invokeMethod<bool>('saveExportDocument', {
        'filename': filename,
        'mimeType': mimeType,
        'content': content,
      });
      return ok ?? true;
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: content));
      return true;
    } on PlatformException {
      return false;
    }
  }

  static (int, int) _parseHm(String s, int defH, int defM) {
    final parts = s.split(':');
    if (parts.length != 2) return (defH, defM);
    final h = int.tryParse(parts[0]) ?? defH;
    final m = int.tryParse(parts[1]) ?? defM;
    return (h.clamp(0, 23), m.clamp(0, 59));
  }
}
