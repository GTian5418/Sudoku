import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 当前游戏存档：自动保存与恢复。
class GameSave {
  static const _key = 'current_game';

  /// 读取存档，无存档或解析失败返回 null。
  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 保存当前游戏状态。
  static Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// 清除存档（通关后调用）。
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
