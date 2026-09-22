import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sudoku_engine.dart';

/// 一条排行榜记录：用时（秒）+ 完成日期。
class LeaderboardEntry {
  const LeaderboardEntry({required this.seconds, required this.date});

  final int seconds;
  final DateTime date;

  Map<String, dynamic> toJson() => {
        's': seconds,
        'd': date.toIso8601String(),
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        seconds: json['s'] as int,
        date: DateTime.parse(json['d'] as String),
      );
}

/// 各难度分开记录前 10 名，按用时升序排列。
class Leaderboard {
  static const _maxEntries = 10;
  static const _prefix = 'leaderboard_';

  /// 添加一条记录，返回更新后的列表。
  static Future<List<LeaderboardEntry>> addEntry(
    Difficulty difficulty,
    int seconds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefix + difficulty.name;
    final entries = _load(prefs, key);
    entries.add(LeaderboardEntry(seconds: seconds, date: DateTime.now()));
    entries.sort((a, b) => a.seconds.compareTo(b.seconds));
    final trimmed = entries.take(_maxEntries).toList();
    await prefs.setString(key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    return trimmed;
  }

  /// 读取某难度的排行榜。
  static Future<List<LeaderboardEntry>> getEntries(Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs, _prefix + difficulty.name);
  }

  static List<LeaderboardEntry> _load(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.seconds.compareTo(b.seconds));
    } catch (_) {
      return [];
    }
  }

  /// 清空某难度的排行榜（用于测试或"清空"按钮）。
  static Future<void> clear(Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + difficulty.name);
  }
}
