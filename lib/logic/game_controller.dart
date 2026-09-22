import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'sudoku_engine.dart';

/// 游戏状态:棋盘、笔记、选中格、计时。
class GameController extends ChangeNotifier {
  GameController({
    SudokuPuzzle? puzzle,
    Difficulty difficulty = Difficulty.easy,
    Random? rng,
  }) : _rng = rng ?? Random() {
    _start(puzzle ?? SudokuEngine.generate(difficulty: difficulty, rng: _rng));
  }

  /// 不生成新局,仅用于从存档恢复。
  GameController.blank({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  Timer? _timer;
  SudokuPuzzle? _puzzle;

  late List<List<int>> board;
  late List<List<bool>> given;
  late List<Set<int>> notes;

  /// 每格的着色标记：0=无色，1-5=正色 A-E，6-10=反色 A-E。
  late List<int> cellColors;

  /// 当前画笔颜色（null=非着色模式）。
  int? activeColor;

  /// 当前从数字键盘选中的数字（null=未选）。用于同数字高亮延伸。
  int? activeDigit;

  int? selected;
  bool notesMode = false;
  bool solved = false;
  Duration elapsed = Duration.zero;

  List<List<int>>? _backupBoard;
  List<Set<int>>? _backupNotes;

  SudokuPuzzle? get puzzle => _puzzle;

  /// 是否存在可恢复的备份。
  bool get hasBackup => _backupBoard != null && _backupNotes != null;

  /// 当前选中格上的数字(空格返回 null),用于同数字高亮。
  int? get selectedValue {
    final sel = selected;
    if (sel == null) return null;
    final value = board[sel ~/ 9][sel % 9];
    return value == 0 ? null : value;
  }

  /// 当前高亮延伸的数字：优先数字键盘选中，其次选中格的值。
  int? get highlightDigit => activeDigit ?? selectedValue;

  /// [index] 格的笔记中是否包含 [digit]。
  bool noteContains(int index, int digit) => notes[index].contains(digit);

  // ── 存档序列化 ──

  /// 将当前游戏状态序列化为可 JSON 化的 Map。
  Map<String, dynamic> toMap() => {
        'difficulty': _puzzle!.difficulty.name,
        'solution': _puzzle!.solution,
        'clues': _puzzle!.clues,
        'board': board,
        'notes': [for (final s in notes) s.toList()..sort()],
        'cellColors': cellColors,
        'elapsedSeconds': elapsed.inSeconds,
        'solved': solved,
        'notesMode': notesMode,
      };

  /// 从存档 Map 恢复游戏状态。
  void loadFromMap(Map<String, dynamic> map) {
    final difficulty = Difficulty.values.firstWhere(
      (d) => d.name == map['difficulty'],
    );
    final solution = (map['solution'] as List<dynamic>)
        .map((r) => List<int>.from(r as List<dynamic>))
        .toList();
    final clues = (map['clues'] as List<dynamic>)
        .map((r) => List<int>.from(r as List<dynamic>))
        .toList();
    _puzzle = SudokuPuzzle(
      solution: solution,
      clues: clues,
      difficulty: difficulty,
    );

    board = (map['board'] as List<dynamic>)
        .map((r) => List<int>.from(r as List<dynamic>))
        .toList();
    given = [for (final row in clues) [for (final v in row) v != 0]];
    notes = (map['notes'] as List<dynamic>)
        .map((s) => Set<int>.from(s as List<dynamic>))
        .toList();
    cellColors = List<int>.from(map['cellColors'] as List<dynamic>);
    elapsed = Duration(seconds: map['elapsedSeconds'] as int);
    solved = map['solved'] as bool;
    notesMode = map['notesMode'] as bool;
    activeColor = null;
    activeDigit = null;
    selected = null;
    _backupBoard = null;
    _backupNotes = null;

    if (!solved) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
    notifyListeners();
  }

  void _start(SudokuPuzzle puzzle) {
    _puzzle = puzzle;
    board = [for (final row in puzzle.clues) List<int>.of(row)];
    given = [for (final row in puzzle.clues) [for (final v in row) v != 0]];
    notes = List.generate(81, (_) => <int>{});
    cellColors = List<int>.filled(81, 0);
    activeColor = null;
    activeDigit = null;
    selected = null;
    notesMode = false;
    solved = false;
    elapsed = Duration.zero;
    _backupBoard = null;
    _backupNotes = null;
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!solved) {
        elapsed += const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  void newGame(Difficulty difficulty) =>
      _start(SudokuEngine.generate(difficulty: difficulty, rng: _rng));

  /// 清空玩家填入的数字,回到初始题目。
  void restart() {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    board = [for (final row in puzzle.clues) List<int>.of(row)];
    notes = List.generate(81, (_) => <int>{});
    cellColors = List<int>.filled(81, 0);
    activeColor = null;
    activeDigit = null;
    solved = false;
    elapsed = Duration.zero;
    _backupBoard = null;
    _backupNotes = null;
    _startTimer();
    notifyListeners();
  }

  /// 备份当前玩家输入与笔记(换局/重开时自动清除)。
  void backup() {
    _backupBoard = [for (final row in board) List<int>.of(row)];
    _backupNotes = [for (final cell in notes) Set<int>.of(cell)];
    notifyListeners();
  }

  /// 恢复到最近一次备份的输入与笔记;不影响错误数与计时。
  void restore() {
    final backupBoard = _backupBoard;
    final backupNotes = _backupNotes;
    if (backupBoard == null || backupNotes == null) return;
    board = [for (final row in backupBoard) List<int>.of(row)];
    notes = [for (final cell in backupNotes) Set<int>.of(cell)];
    // 若已通关后恢复旧备份,棋盘不再完整,恢复计时。
    if (solved && !_matchesSolution()) {
      solved = false;
      _startTimer();
    }
    notifyListeners();
  }

  void select(int index) {
    if (solved) return;
    selected = index;
    activeDigit = null; // 选中格子时以格子值为高亮基准。
    notifyListeners();
  }

  void clearSelection() {
    if (selected == null && activeDigit == null) return;
    selected = null;
    activeDigit = null;
    notifyListeners();
  }

  /// 从数字键盘选数字：设置高亮延伸，并在有选中格时填入。
  /// 笔记模式下保持笔记开启，方便连续标注同一数字。
  /// 再次点击同一数字取消键盘选中模式。
  void padDigit(int digit) {
    if (activeDigit == digit) {
      activeDigit = null;
    } else {
      activeDigit = digit;
      if (selected != null) {
        enterDigit(digit);
      }
    }
    notifyListeners();
  }

  // ── 着色标记（仿 HoDoKu Coloring）──

  /// 进入着色模式并设置画笔颜色（1-10）。
  void enterColorMode(int color) {
    activeColor = color;
    notifyListeners();
  }

  /// 退出着色模式。
  void exitColorMode() {
    activeColor = null;
    notifyListeners();
  }

  /// 对格子切换当前画笔颜色：已有同色则清除，否则着色。
  void toggleCellColor(int index) {
    final color = activeColor;
    if (color == null) return;
    cellColors[index] = cellColors[index] == color ? 0 : color;
    notifyListeners();
  }

  /// 清除所有颜色标记。
  void clearAllColors() {
    cellColors = List<int>.filled(81, 0);
    notifyListeners();
  }

  /// 点击格子：着色模式下着色，有数字键盘选中时填入并保持，否则选中。
  void tapCell(int index) {
    if (solved) return;
    if (activeColor != null) {
      toggleCellColor(index);
    } else if (activeDigit != null) {
      // 数字键盘模式：填入选中数字并保持 activeDigit，方便连续标注。
      selected = index;
      enterDigit(activeDigit!);
      notifyListeners();
    } else {
      select(index);
    }
  }

  void toggleNotesMode() {
    notesMode = !notesMode;
    notifyListeners();
  }

  /// 填数字。笔记模式下切换候选数;普通模式下填入/再次点击可取消。
  void enterDigit(int digit) {
    final sel = selected;
    final puzzle = _puzzle;
    if (solved || puzzle == null || sel == null) return;
    final row = sel ~/ 9;
    final col = sel % 9;
    if (given[row][col]) return;

    if (notesMode) {
      if (board[row][col] != 0) return;
      final cell = notes[sel];
      cell.contains(digit) ? cell.remove(digit) : cell.add(digit);
      notifyListeners();
      return;
    }

    if (board[row][col] == digit) {
      board[row][col] = 0;
      notifyListeners();
      return;
    }

    board[row][col] = digit;
    if (digit == puzzle.solution[row][col]) {
      notes[sel].clear();
      _clearPeerNotes(row, col, digit);
    }
    notifyListeners();
    _checkWin();
  }

  void erase() {
    final sel = selected;
    if (solved || sel == null) return;
    final row = sel ~/ 9;
    final col = sel % 9;
    if (given[row][col]) return;
    if (board[row][col] != 0) {
      board[row][col] = 0;
    } else {
      notes[sel].clear();
    }
    notifyListeners();
  }

  /// 提示:优先填当前选中格,否则填第一个空格。
  void hint() {
    final puzzle = _puzzle;
    if (solved || puzzle == null) return;

    int? target;
    final sel = selected;
    if (sel != null && !given[sel ~/ 9][sel % 9]) {
      if (board[sel ~/ 9][sel % 9] != puzzle.solution[sel ~/ 9][sel % 9]) {
        target = sel;
      }
    }
    if (target == null) {
      for (int i = 0; i < 81; i++) {
        if (board[i ~/ 9][i % 9] != puzzle.solution[i ~/ 9][i % 9]) {
          target = i;
          break;
        }
      }
    }
    if (target == null) return;

    final row = target ~/ 9;
    final col = target % 9;
    final value = puzzle.solution[row][col];
    board[row][col] = value;
    notes[target].clear();
    _clearPeerNotes(row, col, value);
    selected = target;
    activeDigit = null;
    notifyListeners();
    _checkWin();
  }

  /// [index] 是否与当前选中格同行/列/宫。
  bool isPeer(int index) {
    final sel = selected;
    if (sel == null || index == sel) return false;
    final r1 = sel ~/ 9, c1 = sel % 9;
    final r2 = index ~/ 9, c2 = index % 9;
    if (r1 == r2 || c1 == c2) return true;
    return (r1 ~/ 3) == (r2 ~/ 3) && (c1 ~/ 3) == (c2 ~/ 3);
  }

  /// [index] 是否与任意同数字格同行/列/宫（用于同数字高亮延伸）。
  /// 例如高亮数字为 5 时，所有含 5 的格子的行/列/宫都会灰色高亮。
  bool isSameDigitPeer(int index) {
    final hl = highlightDigit;
    if (hl == null) return false;
    final r2 = index ~/ 9, c2 = index % 9;
    for (int i = 0; i < 81; i++) {
      if (i == index) continue;
      if (board[i ~/ 9][i % 9] != hl) continue;
      final r1 = i ~/ 9, c1 = i % 9;
      if (r1 == r2 || c1 == c2) return true;
      if ((r1 ~/ 3) == (r2 ~/ 3) && (c1 ~/ 3) == (c2 ~/ 3)) return true;
    }
    return false;
  }

  /// 是否存在同行/列/宫的重复数字。
  bool hasConflict(int row, int col) {
    final value = board[row][col];
    if (value == 0) return false;
    for (int i = 0; i < 9; i++) {
      if (i != col && board[row][i] == value) return true;
      if (i != row && board[i][col] == value) return true;
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if ((r != row || c != col) && board[r][c] == value) return true;
      }
    }
    return false;
  }

  void _clearPeerNotes(int row, int col, int value) {
    for (int i = 0; i < 9; i++) {
      notes[row * 9 + i].remove(value);
      notes[i * 9 + col].remove(value);
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        notes[r * 9 + c].remove(value);
      }
    }
  }

  bool _matchesSolution() {
    final puzzle = _puzzle;
    if (puzzle == null) return false;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] != puzzle.solution[r][c]) return false;
      }
    }
    return true;
  }

  bool _checkWin() {
    if (!_matchesSolution()) return false;
    solved = true;
    _timer?.cancel();
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
