import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic/game_controller.dart';
import 'logic/game_save.dart';
import 'logic/leaderboard.dart';
import 'logic/sudoku_engine.dart';
import 'ui/board_widget.dart';
import 'ui/number_pad.dart';

void main() => runApp(const SudokuApp());

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数独',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6FF0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SudokuHomePage(),
    );
  }
}

/// 排行榜对话框：各难度分页，每页前 10 名。
class _LeaderboardDialog extends StatefulWidget {
  const _LeaderboardDialog();

  @override
  State<_LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<_LeaderboardDialog> {
  Difficulty _tab = Difficulty.easy;
  final Map<Difficulty, List<LeaderboardEntry>> _cache = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load(_tab);
  }

  Future<void> _load(Difficulty d) async {
    setState(() => _loading = true);
    final entries = await Leaderboard.getEntries(d);
    _cache[d] = entries;
    if (mounted) setState(() => _loading = false);
  }

  String _fmt(int seconds) {
    final d = Duration(seconds: seconds);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final entries = _cache[_tab];
    return AlertDialog(
      title: const Text('排行榜'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<Difficulty>(
              segments: [
                for (final d in Difficulty.values)
                  ButtonSegment(value: d, label: Text(d.label)),
              ],
              selected: {_tab},
              onSelectionChanged: (sel) {
                final next = sel.first;
                if (next == _tab) return;
                setState(() => _tab = next);
                if (!_cache.containsKey(next)) _load(next);
              },
            ),
            const SizedBox(height: 12),
            if (_loading || entries == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('暂无记录', style: TextStyle(color: Colors.grey)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final medal = switch (i) {
                      0 => '🥇',
                      1 => '🥈',
                      2 => '🥉',
                      _ => '${i + 1}',
                    };
                    return ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 32,
                        child: Text(
                          medal,
                          style: i < 3
                              ? const TextStyle(fontSize: 18)
                              : const TextStyle(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      title: Text(_fmt(e.seconds)),
                      trailing: Text(
                        '${e.date.month}/${e.date.day}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class SudokuHomePage extends StatefulWidget {
  const SudokuHomePage({super.key, this.controller});

  /// 测试时可注入预生成的控制器。
  final GameController? controller;

  @override
  State<SudokuHomePage> createState() => _SudokuHomePageState();
}

class _SudokuHomePageState extends State<SudokuHomePage> {
  GameController? _controller;
  late final bool _ownsController;
  final FocusNode _keyboardFocus = FocusNode();
  bool _winShown = false;
  bool _loading = true;
  Timer? _autoSaveTimer;

  /// 主键盘与小键盘数字键映射。
  static final Map<LogicalKeyboardKey, int> _digitKeys = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  /// A-E 键映射到颜色序号 1-5（正色）。
  static final Map<LogicalKeyboardKey, int> _colorKeys = {
    LogicalKeyboardKey.keyA: 1,
    LogicalKeyboardKey.keyB: 2,
    LogicalKeyboardKey.keyC: 3,
    LogicalKeyboardKey.keyD: 4,
    LogicalKeyboardKey.keyE: 5,
  };

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    if (_ownsController) {
      _initFromSave();
    } else {
      _controller = widget.controller;
      _controller!.addListener(_onGameChanged);
      _loading = false;
      _startAutoSave();
    }
  }

  Future<void> _initFromSave() async {
    final saved = await GameSave.load();
    if (!mounted) return;
    final ctrl = GameController.blank();
    if (saved != null) {
      ctrl.loadFromMap(saved);
    } else {
      ctrl.newGame(Difficulty.easy);
    }
    _controller = ctrl;
    ctrl.addListener(_onGameChanged);
    setState(() => _loading = false);
    _startAutoSave();
  }

  /// 固定周期自动存档（每 3 秒），不依赖 change 事件。
  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 3), (_) => _saveGame());
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final ctrl = _controller;
    if (ctrl == null || ctrl.solved) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    final digit = _digitKeys[key];
    if (digit != null) {
      ctrl.padDigit(digit);
      return KeyEventResult.handled;
    }

    // A-E：着色正色 1-5；Shift+A-E：着色反色 6-10。
    final colorIndex = _colorKeys[key];
    if (colorIndex != null) {
      ctrl.enterColorMode(shift ? colorIndex + 5 : colorIndex);
      return KeyEventResult.handled;
    }

    switch (key) {
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
        ctrl.erase();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyN:
        ctrl.toggleNotesMode();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyH:
        ctrl.hint();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyR:
        ctrl.clearAllColors();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (ctrl.activeColor != null) {
          ctrl.exitColorMode();
        } else {
          ctrl.clearSelection();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveSelection(-1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveSelection(1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _moveSelection(0, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _moveSelection(0, 1);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveSelection(int rowDelta, int colDelta) {
    final ctrl = _controller;
    if (ctrl == null) return;
    final sel = ctrl.selected ?? 40;
    var row = sel ~/ 9 + rowDelta;
    var col = sel % 9 + colDelta;
    if (row < 0) row = 0;
    if (row > 8) row = 8;
    if (col < 0) col = 0;
    if (col > 8) col = 8;
    ctrl.select(row * 9 + col);
  }

  void _onGameChanged() {
    final ctrl = _controller;
    if (ctrl == null) return;

    // 通关：清除存档，弹出完成对话框。
    if (ctrl.solved && !_winShown) {
      _winShown = true;
      _autoSaveTimer?.cancel();
      GameSave.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
  }

  void _saveGame() {
    final ctrl = _controller;
    if (ctrl != null && ctrl.puzzle != null && !ctrl.solved) {
      GameSave.save(ctrl.toMap());
    }
  }

  void _showWinDialog() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final difficulty = ctrl.puzzle!.difficulty;
    final seconds = ctrl.elapsed.inSeconds;
    Leaderboard.addEntry(difficulty, seconds);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完成!'),
        content: Text('用时 ${_formatDuration(ctrl.elapsed)}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _winShown = false);
              ctrl.newGame(difficulty);
            },
            child: const Text('再来一局'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _winShown = false);
            },
            child: const Text('欣赏棋盘'),
          ),
        ],
      ),
    );
  }

  void _confirmRestart() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重开本局?'),
        content: const Text('将清空所有已填入的数字与笔记。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _controller?.restart();
            },
            child: const Text('重开'),
          ),
        ],
      ),
    );
  }

  void _confirmNewGame() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final difficulty = ctrl.puzzle?.difficulty ?? Difficulty.easy;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新游戏?'),
        content: const Text('将放弃当前进度，生成新题目。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ctrl.newGame(difficulty);
            },
            child: const Text('新游戏'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  void _showLeaderboard() {
    showDialog<void>(
      context: context,
      builder: (context) => const _LeaderboardDialog(),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // 退出前立即存档（未通关的局）。
    final ctrl = _controller;
    if (ctrl != null) {
      if (_ownsController && ctrl.puzzle != null && !ctrl.solved) {
        GameSave.save(ctrl.toMap());
      }
      ctrl.removeListener(_onGameChanged);
      if (_ownsController) {
        ctrl.dispose();
      }
    }
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ctrl = _controller!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('数独'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _confirmNewGame,
            child: const Text('新局'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重开本局',
            onPressed: _confirmRestart,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Focus(
            focusNode: _keyboardFocus,
            autofocus: true,
            onKeyEvent: _handleKey,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListenableBuilder(
                        listenable: ctrl,
                        builder: (context, _) {
                          final current =
                              ctrl.puzzle?.difficulty ?? Difficulty.easy;
                          return SegmentedButton<Difficulty>(
                            segments: [
                              for (final d in Difficulty.values)
                                ButtonSegment(value: d, label: Text(d.label)),
                            ],
                            selected: {current},
                            onSelectionChanged: (selection) async {
                              final next = selection.first;
                              if (next == current) return;
                              final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('切换难度'),
                                      content: Text(
                                        '当前难度：${current.label}\n'
                                        '切换到：${next.label}\n\n'
                                        '切换难度将开始新游戏，当前进度会丢失。是否继续？',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('确认切换'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (confirmed && context.mounted) {
                                ctrl.newGame(next);
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: ctrl,
                        builder: (context, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, size: 18),
                              const SizedBox(width: 4),
                              Text(_formatDuration(ctrl.elapsed)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      BoardWidget(controller: ctrl),
                      const SizedBox(height: 16),
                      NumberPad(controller: ctrl),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showLeaderboard,
                          icon: const Icon(Icons.leaderboard_outlined),
                          label: const Text('排行榜'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
