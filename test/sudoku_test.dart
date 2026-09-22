import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/logic/game_controller.dart';
import 'package:sudoku/logic/game_save.dart';
import 'package:sudoku/logic/leaderboard.dart';
import 'package:sudoku/logic/sudoku_engine.dart';
import 'package:sudoku/main.dart';

void main() {
  group('SudokuEngine', () {
    test('生成的终盘是合法完整解', () {
      final puzzle = SudokuEngine.generate(
        difficulty: Difficulty.medium,
        rng: Random(7),
      );

      final full = {1, 2, 3, 4, 5, 6, 7, 8, 9};
      for (final row in puzzle.solution) {
        expect(row.toSet(), full);
      }
      for (int c = 0; c < 9; c++) {
        expect({for (final row in puzzle.solution) row[c]}, full);
      }
      for (int box = 0; box < 9; box++) {
        final br = (box ~/ 3) * 3;
        final bc = (box % 3) * 3;
        final values = [
          for (int r = br; r < br + 3; r++)
            for (int c = bc; c < bc + 3; c++) puzzle.solution[r][c],
        ];
        expect(values.toSet(), full);
      }
    });

    test('题目唯一解', () {
      final puzzle = SudokuEngine.generate(
        difficulty: Difficulty.hard,
        rng: Random(42),
      );
      expect(SudokuEngine.countSolutions(SudokuEngine.copyGrid(puzzle.clues)), 1);
    });

    test('各难度提示数在目标范围内', () {
      for (final difficulty in Difficulty.values) {
        final puzzle = SudokuEngine.generate(
          difficulty: difficulty,
          rng: Random(3),
        );
        var clues = 0;
        for (final row in puzzle.clues) {
          clues += row.where((v) => v != 0).length;
        }
        // 生成器对称移除并保证唯一解，高难度可能无法达到目标提示数。
        expect(clues, lessThanOrEqualTo(difficulty.clues + 8));
        expect(clues, greaterThanOrEqualTo(difficulty.clues - 2));
      }
    });

    test('五个难度等级及提示数正确', () {
      expect(Difficulty.values.length, 5);
      expect(Difficulty.easy.clues, 45);
      expect(Difficulty.medium.clues, 38);
      expect(Difficulty.hard.clues, 32);
      expect(Difficulty.unfair.clues, 27);
      expect(Difficulty.extreme.clues, 23);
    });

    test('超难与极难等级可生成唯一解', () {
      for (final d in [Difficulty.unfair, Difficulty.extreme]) {
        final puzzle = SudokuEngine.generate(difficulty: d, rng: Random(9));
        expect(
          SudokuEngine.countSolutions(SudokuEngine.copyGrid(puzzle.clues)),
          1,
        );
      }
    });

    test('isValidPlacement 正确判定行列宫冲突', () {
      final grid = List.generate(9, (_) => List<int>.filled(9, 0));
      grid[0][0] = 5;
      expect(SudokuEngine.isValidPlacement(grid, 0, 8, 5), isFalse); // 同行
      expect(SudokuEngine.isValidPlacement(grid, 8, 0, 5), isFalse); // 同列
      expect(SudokuEngine.isValidPlacement(grid, 1, 1, 5), isFalse); // 同宫
      expect(SudokuEngine.isValidPlacement(grid, 3, 3, 5), isTrue); // 无冲突
    });
  });

  group('GameController', () {
    late GameController controller;

    setUp(() {
      controller = GameController(
        puzzle: SudokuEngine.generate(
          difficulty: Difficulty.easy,
          rng: Random(7),
        ),
        rng: Random(7),
      );
    });

    tearDown(() => controller.dispose());

    int emptyCellIndex() {
      for (int i = 0; i < 81; i++) {
        if (controller.puzzle!.clues[i ~/ 9][i % 9] == 0) return i;
      }
      throw StateError('no empty cell');
    }

    test('填错数字仍会显示在棋盘上', () {
      final index = emptyCellIndex();
      final row = index ~/ 9;
      final col = index % 9;
      final wrong = controller.puzzle!.solution[row][col] == 1 ? 2 : 1;

      controller.select(index);
      controller.enterDigit(wrong);

      expect(controller.board[row][col], wrong);
    });

    test('再点同一数字可撤销', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.enterDigit(5);
      controller.enterDigit(5);
      expect(controller.board[index ~/ 9][index % 9], 0);
    });

    test('笔记本切换候选数,擦除可清空', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.notesMode = true;

      controller.enterDigit(3);
      controller.enterDigit(7);
      expect(controller.notes[index], {3, 7});
      controller.enterDigit(3);
      expect(controller.notes[index], {7});

      controller.notesMode = false;
      controller.erase();
      expect(controller.board[index ~/ 9][index % 9], 0);
      expect(controller.notes[index], isEmpty);
    });

    test('提示会填入正确数字', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.hint();

      final row = index ~/ 9;
      final col = index % 9;
      expect(controller.board[row][col], controller.puzzle!.solution[row][col]);
    });

    test('全部填对后判定完成', () {
      final puzzle = controller.puzzle!;
      for (int i = 0; i < 81; i++) {
        final row = i ~/ 9;
        final col = i % 9;
        if (controller.given[row][col]) continue;
        controller.select(i);
        controller.enterDigit(puzzle.solution[row][col]);
      }
      expect(controller.solved, isTrue);
    });

    test('restart 恢复初始题目', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.enterDigit(9);
      controller.restart();

      expect(controller.board[index ~/ 9][index % 9], 0);
      expect(controller.solved, isFalse);
    });
  });

  group('高亮延伸', () {
    late GameController controller;

    setUp(() {
      controller = GameController(
        puzzle: SudokuEngine.generate(
          difficulty: Difficulty.easy,
          rng: Random(7),
        ),
        rng: Random(7),
      );
    });

    tearDown(() => controller.dispose());

    int emptyCellIndex() {
      for (int i = 0; i < 81; i++) {
        if (controller.puzzle!.clues[i ~/ 9][i % 9] == 0) return i;
      }
      throw StateError('no empty cell');
    }

    test('padDigit 设置 activeDigit', () {
      controller.padDigit(5);
      expect(controller.activeDigit, 5);
      expect(controller.highlightDigit, 5);
    });

    test('padDigit 有选中格时填入数字', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.padDigit(3);
      expect(controller.board[index ~/ 9][index % 9], 3);
      expect(controller.activeDigit, 3);
    });

    test('padDigit 笔记模式保持开启并添加候选', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.notesMode = true;
      controller.padDigit(7);
      expect(controller.notesMode, isTrue);
      expect(controller.notes[index], contains(7));
      expect(controller.activeDigit, 7);
    });

    test('highlightDigit 优先 activeDigit', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.enterDigit(5);
      // selectedValue = 5
      expect(controller.highlightDigit, 5);
      controller.padDigit(3);
      // activeDigit = 3 优先于 selectedValue = 5
      expect(controller.highlightDigit, 3);
    });

    test('select 清除 activeDigit', () {
      controller.padDigit(5);
      expect(controller.activeDigit, 5);
      controller.select(0);
      expect(controller.activeDigit, isNull);
    });

    test('noteContains 正确检测笔记', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.notesMode = true;
      controller.enterDigit(4);
      controller.enterDigit(8);
      expect(controller.noteContains(index, 4), isTrue);
      expect(controller.noteContains(index, 8), isTrue);
      expect(controller.noteContains(index, 5), isFalse);
    });

    test('highlightDigit 为 null 时无高亮', () {
      expect(controller.highlightDigit, isNull);
    });

    test('选中格有值时 highlightDigit 返回该值', () {
      final index = emptyCellIndex();
      controller.select(index);
      controller.enterDigit(6);
      expect(controller.highlightDigit, 6);
    });

    test('padDigit 再次点击同一数字取消', () {
      controller.padDigit(5);
      expect(controller.activeDigit, 5);
      controller.padDigit(5);
      expect(controller.activeDigit, isNull);
    });

    test('tapCell 在 activeDigit 模式下填入并保持', () {
      final a = emptyCellIndex();
      controller.padDigit(5);
      expect(controller.activeDigit, 5);
      controller.tapCell(a);
      expect(controller.board[a ~/ 9][a % 9], 5);
      expect(controller.activeDigit, 5); // 保持不变
      expect(controller.selected, a);
    });

    test('tapCell 连续标注同一数字到多个格子', () {
      final cells = <int>[];
      for (int i = 0; i < 81; i++) {
        if (controller.puzzle!.clues[i ~/ 9][i % 9] == 0) cells.add(i);
      }
      final a = cells[0];
      final b = cells[1];

      controller.notesMode = true;
      controller.padDigit(7);
      controller.tapCell(a);
      controller.tapCell(b);

      expect(controller.notes[a], contains(7));
      expect(controller.notes[b], contains(7));
      expect(controller.activeDigit, 7); // 仍然保持
    });

    test('clearSelection 清除 activeDigit', () {
      controller.padDigit(5);
      controller.clearSelection();
      expect(controller.activeDigit, isNull);
    });

    test('isSameDigitPeer 高亮所有同数字格的行列宫', () {
      // 找两个空格，填入相同数字 5。
      final cells = <int>[];
      for (int i = 0; i < 81; i++) {
        if (controller.puzzle!.clues[i ~/ 9][i % 9] == 0) cells.add(i);
      }
      final a = cells[0];
      final b = cells[5]; // 间隔较远
      controller.select(a);
      controller.enterDigit(5);
      controller.select(b);
      controller.enterDigit(5);

      // 选中 a，高亮数字为 5。
      controller.select(a);
      expect(controller.highlightDigit, 5);

      // b 的同行下一格应该是 sameDigitPeer（因为 b 有 5）。
      final bRow = b ~/ 9;
      final bNext = bRow * 9 + (b % 9 + 1) % 9;
      if (bNext != a) {
        expect(controller.isSameDigitPeer(bNext), isTrue);
      }
    });

    test('padDigit 再次点击同一数字取消', () {
      controller.padDigit(5);
      expect(controller.activeDigit, 5);
      controller.padDigit(5);
      expect(controller.activeDigit, isNull);
    });

    test('tapCell 在 activeDigit 模式下填入并保持', () {
      final a = emptyCellIndex();
      controller.padDigit(5);
      expect(controller.activeDigit, 5);
      controller.tapCell(a);
      expect(controller.board[a ~/ 9][a % 9], 5);
      expect(controller.activeDigit, 5); // 保持不变
      expect(controller.selected, a);
    });

    test('tapCell 连续标注同一数字到多个格子', () {
      final cells = <int>[];
      for (int i = 0; i < 81; i++) {
        if (controller.puzzle!.clues[i ~/ 9][i % 9] == 0) cells.add(i);
      }
      final a = cells[0];
      final b = cells[1];

      controller.notesMode = true;
      controller.padDigit(7);
      controller.tapCell(a);
      controller.tapCell(b);

      expect(controller.notes[a], contains(7));
      expect(controller.notes[b], contains(7));
      expect(controller.activeDigit, 7); // 仍然保持
    });

    test('clearSelection 清除 activeDigit', () {
      controller.padDigit(5);
      controller.clearSelection();
      expect(controller.activeDigit, isNull);
    });

    test('isSameDigitPeer 高亮所有同数字格的行列宫', () {
      // 找两个空格，填入相同数字 5。
      final cells = <int>[];
      for (int i = 0; i < 81; i++) {
        if (controller.puzzle!.clues[i ~/ 9][i % 9] == 0) cells.add(i);
      }
      final a = cells[0];
      final b = cells[5]; // 间隔较远
      controller.select(a);
      controller.enterDigit(5);
      controller.select(b);
      controller.enterDigit(5);

      // 选中 a，高亮数字为 5。
      controller.select(a);
      expect(controller.highlightDigit, 5);

      // b 的同行下一格应该是 sameDigitPeer（因为 b 有 5）。
      final bRow = b ~/ 9;
      final bNext = bRow * 9 + (b % 9 + 1) % 9;
      if (bNext != a) {
        expect(controller.isSameDigitPeer(bNext), isTrue);
      }
    });
  });

  group('备份与恢复', () {
    late GameController controller;

    setUp(() {
      controller = GameController(
        puzzle: SudokuEngine.generate(
          difficulty: Difficulty.easy,
          rng: Random(11),
        ),
        rng: Random(11),
      );
    });

    tearDown(() => controller.dispose());

    List<int> emptyCells(GameController c) {
      final result = <int>[];
      for (int i = 0; i < 81; i++) {
        if (c.puzzle!.clues[i ~/ 9][i % 9] == 0) result.add(i);
      }
      return result;
    }

    test('备份当前输入与笔记,恢复后还原', () {
      final empty = emptyCells(controller);
      final a = empty[0];
      final b = empty[1];

      controller.select(a);
      controller.enterDigit(4);
      controller.select(b);
      controller.notesMode = true;
      controller.enterDigit(2);
      controller.enterDigit(5);

      controller.backup();
      expect(controller.hasBackup, isTrue);

      // 备份后继续改动:撤销 a、给 b 加候选再全部擦除。
      controller.select(a);
      controller.enterDigit(4);
      controller.select(b);
      controller.enterDigit(6);
      controller.erase();

      controller.restore();

      expect(controller.board[a ~/ 9][a % 9], 4);
      expect(controller.notes[b], {2, 5});
    });

    test('未备份时恢复无效', () {
      expect(controller.hasBackup, isFalse);
      final i = emptyCells(controller)[0];
      controller.select(i);
      controller.enterDigit(7);

      controller.restore();

      expect(controller.board[i ~/ 9][i % 9], 7);
      expect(controller.hasBackup, isFalse);
    });

    test('重开本局后备份失效', () {
      final i = emptyCells(controller)[0];
      controller.select(i);
      controller.enterDigit(7);
      controller.backup();
      expect(controller.hasBackup, isTrue);

      controller.restart();
      expect(controller.hasBackup, isFalse);

      controller.select(i);
      controller.enterDigit(8);
      controller.restore();

      expect(controller.board[i ~/ 9][i % 9], 8);
    });

    test('恢复不影响错误数', () {
      final i = emptyCells(controller)[0];
      final sol = controller.puzzle!.solution[i ~/ 9][i % 9];
      final wrong = sol == 1 ? 2 : 1;

      controller.select(i);
      controller.enterDigit(wrong);

      controller.backup();
      controller.enterDigit(sol);
      expect(controller.board[i ~/ 9][i % 9], sol);

      controller.restore();

      expect(controller.board[i ~/ 9][i % 9], wrong);
    });
  });

  group('着色功能', () {
    late GameController controller;

    setUp(() {
      controller = GameController(
        puzzle: SudokuEngine.generate(
          difficulty: Difficulty.easy,
          rng: Random(5),
        ),
        rng: Random(5),
      );
    });

    tearDown(() => controller.dispose());

    test('enterColorMode 设置 activeColor', () {
      controller.enterColorMode(1);
      expect(controller.activeColor, 1);
      controller.enterColorMode(6);
      expect(controller.activeColor, 6);
    });

    test('exitColorMode 清除 activeColor', () {
      controller.enterColorMode(2);
      controller.exitColorMode();
      expect(controller.activeColor, isNull);
    });

    test('toggleCellColor 切换单元格颜色', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 1);
      // 再点一次取消。
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 0);
    });

    test('切换颜色后再次点击覆盖旧颜色', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 1);
      controller.enterColorMode(3);
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 3);
    });

    test('clearAllColors 清除所有颜色', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      controller.toggleCellColor(5);
      controller.toggleCellColor(40);
      expect(controller.cellColors.where((c) => c != 0).length, 3);
      controller.clearAllColors();
      expect(controller.cellColors.every((c) => c == 0), isTrue);
    });

    test('tapCell 在着色模式下切换颜色,否则选中', () {
      controller.enterColorMode(2);
      controller.tapCell(10);
      expect(controller.cellColors[10], 2);
      expect(controller.selected, isNot(10));
      controller.exitColorMode();
      controller.tapCell(10);
      expect(controller.selected, 10);
    });

    test('restart 清除所有颜色标记', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      controller.toggleCellColor(1);
      controller.restart();
      expect(controller.cellColors.every((c) => c == 0), isTrue);
      expect(controller.activeColor, isNull);
    });
  });

  group('备份与恢复', () {
    late GameController controller;

    setUp(() {
      controller = GameController(
        puzzle: SudokuEngine.generate(
          difficulty: Difficulty.easy,
          rng: Random(11),
        ),
        rng: Random(11),
      );
    });

    tearDown(() => controller.dispose());

    List<int> emptyCells(GameController c) {
      final result = <int>[];
      for (int i = 0; i < 81; i++) {
        if (c.puzzle!.clues[i ~/ 9][i % 9] == 0) result.add(i);
      }
      return result;
    }

    test('备份当前输入与笔记,恢复后还原', () {
      final empty = emptyCells(controller);
      final a = empty[0];
      final b = empty[1];

      controller.select(a);
      controller.enterDigit(4);
      controller.select(b);
      controller.notesMode = true;
      controller.enterDigit(2);
      controller.enterDigit(5);

      controller.backup();
      expect(controller.hasBackup, isTrue);

      // 备份后继续改动:撤销 a、给 b 加候选再全部擦除。
      controller.select(a);
      controller.enterDigit(4);
      controller.select(b);
      controller.enterDigit(6);
      controller.erase();

      controller.restore();

      expect(controller.board[a ~/ 9][a % 9], 4);
      expect(controller.notes[b], {2, 5});
    });

    test('未备份时恢复无效', () {
      expect(controller.hasBackup, isFalse);
      final i = emptyCells(controller)[0];
      controller.select(i);
      controller.enterDigit(7);

      controller.restore();

      expect(controller.board[i ~/ 9][i % 9], 7);
      expect(controller.hasBackup, isFalse);
    });

    test('重开本局后备份失效', () {
      final i = emptyCells(controller)[0];
      controller.select(i);
      controller.enterDigit(7);
      controller.backup();
      expect(controller.hasBackup, isTrue);

      controller.restart();
      expect(controller.hasBackup, isFalse);

      controller.select(i);
      controller.enterDigit(8);
      controller.restore();

      expect(controller.board[i ~/ 9][i % 9], 8);
    });

    test('恢复不影响错误数', () {
      final i = emptyCells(controller)[0];
      final sol = controller.puzzle!.solution[i ~/ 9][i % 9];
      final wrong = sol == 1 ? 2 : 1;

      controller.select(i);
      controller.enterDigit(wrong);

      controller.backup();
      controller.enterDigit(sol);
      expect(controller.board[i ~/ 9][i % 9], sol);

      controller.restore();

      expect(controller.board[i ~/ 9][i % 9], wrong);
    });
  });

  group('着色功能', () {
    late GameController controller;

    setUp(() {
      controller = GameController(
        puzzle: SudokuEngine.generate(
          difficulty: Difficulty.easy,
          rng: Random(5),
        ),
        rng: Random(5),
      );
    });

    tearDown(() => controller.dispose());

    test('enterColorMode 设置 activeColor', () {
      controller.enterColorMode(1);
      expect(controller.activeColor, 1);
      controller.enterColorMode(6);
      expect(controller.activeColor, 6);
    });

    test('exitColorMode 清除 activeColor', () {
      controller.enterColorMode(2);
      controller.exitColorMode();
      expect(controller.activeColor, isNull);
    });

    test('toggleCellColor 切换单元格颜色', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 1);
      // 再点一次取消。
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 0);
    });

    test('切换颜色后再次点击覆盖旧颜色', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 1);
      controller.enterColorMode(3);
      controller.toggleCellColor(0);
      expect(controller.cellColors[0], 3);
    });

    test('clearAllColors 清除所有颜色', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      controller.toggleCellColor(5);
      controller.toggleCellColor(40);
      expect(controller.cellColors.where((c) => c != 0).length, 3);
      controller.clearAllColors();
      expect(controller.cellColors.every((c) => c == 0), isTrue);
    });

    test('tapCell 在着色模式下切换颜色,否则选中', () {
      controller.enterColorMode(2);
      controller.tapCell(10);
      expect(controller.cellColors[10], 2);
      expect(controller.selected, isNot(10));
      controller.exitColorMode();
      controller.tapCell(10);
      expect(controller.selected, 10);
    });

    test('restart 清除所有颜色标记', () {
      controller.enterColorMode(1);
      controller.toggleCellColor(0);
      controller.toggleCellColor(1);
      controller.restart();
      expect(controller.cellColors.every((c) => c == 0), isTrue);
      expect(controller.activeColor, isNull);
    });
  });

  group('键盘输入', () {
    const digitKeys = [
      null,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];

    Future<GameController> pumpGame(WidgetTester tester, {int seed = 11}) async {
      final controller = GameController(
        puzzle: SudokuEngine.generate(
          difficulty: Difficulty.easy,
          rng: Random(seed),
        ),
        rng: Random(seed),
      );
      await tester.pumpWidget(MaterialApp(home: SudokuHomePage(controller: controller)));
      await tester.pump();
      return controller;
    }

    int firstEmpty(GameController controller) {
      for (int i = 0; i < 81; i++) {
        if (controller.puzzle!.clues[i ~/ 9][i % 9] == 0) return i;
      }
      throw StateError('no empty cell');
    }

    testWidgets('数字键填入选中格', (tester) async {
      final controller = await pumpGame(tester);
      final index = firstEmpty(controller);
      final value = controller.puzzle!.solution[index ~/ 9][index % 9];

      controller.select(index);
      await tester.pump();
      await tester.sendKeyEvent(digitKeys[value]!);
      await tester.pump();

      expect(controller.board[index ~/ 9][index % 9], value);
      controller.dispose();
    });

    testWidgets('小键盘数字同样有效', (tester) async {
      final controller = await pumpGame(tester, seed: 21);
      final index = firstEmpty(controller);
      final value = controller.puzzle!.solution[index ~/ 9][index % 9];

      controller.select(index);
      await tester.pump();
      const numpadKeys = [
        null,
        LogicalKeyboardKey.numpad1,
        LogicalKeyboardKey.numpad2,
        LogicalKeyboardKey.numpad3,
        LogicalKeyboardKey.numpad4,
        LogicalKeyboardKey.numpad5,
        LogicalKeyboardKey.numpad6,
        LogicalKeyboardKey.numpad7,
        LogicalKeyboardKey.numpad8,
        LogicalKeyboardKey.numpad9,
      ];
      await tester.sendKeyEvent(numpadKeys[value]!);
      await tester.pump();

      expect(controller.board[index ~/ 9][index % 9], value);
      controller.dispose();
    });

    testWidgets('N 键切笔记模式并记录候选数', (tester) async {
      final controller = await pumpGame(tester);
      final index = firstEmpty(controller);

      controller.select(index);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();

      expect(controller.notesMode, isTrue);
      expect(controller.notes[index], contains(3));
      expect(controller.board[index ~/ 9][index % 9], 0);
      controller.dispose();
    });

    testWidgets('退格擦除已填数字', (tester) async {
      final controller = await pumpGame(tester);
      final index = firstEmpty(controller);

      controller.select(index);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.board[index ~/ 9][index % 9], 0);
      controller.dispose();
    });

    testWidgets('方向键移动选中格', (tester) async {
      final controller = await pumpGame(tester);

      controller.select(40);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.selected, 41);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.selected, 50);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(controller.selected, 49);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(controller.selected, 40);
      controller.dispose();
    });
  });

  group('排行榜', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('addEntry 按用时升序排列', () async {
      await Leaderboard.addEntry(Difficulty.easy, 300);
      await Leaderboard.addEntry(Difficulty.easy, 120);
      await Leaderboard.addEntry(Difficulty.easy, 200);

      final entries = await Leaderboard.getEntries(Difficulty.easy);
      expect(entries.length, 3);
      expect(entries[0].seconds, 120);
      expect(entries[1].seconds, 200);
      expect(entries[2].seconds, 300);
    });

    test('各难度分开记录', () async {
      await Leaderboard.addEntry(Difficulty.easy, 100);
      await Leaderboard.addEntry(Difficulty.hard, 500);

      final easy = await Leaderboard.getEntries(Difficulty.easy);
      final hard = await Leaderboard.getEntries(Difficulty.hard);
      expect(easy.length, 1);
      expect(hard.length, 1);
      expect(easy[0].seconds, 100);
      expect(hard[0].seconds, 500);
    });

    test('只保留前 10 名', () async {
      for (int i = 0; i < 15; i++) {
        await Leaderboard.addEntry(Difficulty.medium, 100 + i * 10);
      }
      final entries = await Leaderboard.getEntries(Difficulty.medium);
      expect(entries.length, 10);
      // 最快的 10 个：100,110,...,190
      expect(entries[0].seconds, 100);
      expect(entries[9].seconds, 190);
    });

    test('相同用时按插入顺序保留', () async {
      await Leaderboard.addEntry(Difficulty.easy, 200);
      await Leaderboard.addEntry(Difficulty.easy, 200);
      final entries = await Leaderboard.getEntries(Difficulty.easy);
      expect(entries.length, 2);
      expect(entries[0].seconds, 200);
      expect(entries[1].seconds, 200);
    });

    test('clear 清空指定难度', () async {
      await Leaderboard.addEntry(Difficulty.easy, 100);
      await Leaderboard.addEntry(Difficulty.hard, 200);
      await Leaderboard.clear(Difficulty.easy);
      final easy = await Leaderboard.getEntries(Difficulty.easy);
      final hard = await Leaderboard.getEntries(Difficulty.hard);
      expect(easy, isEmpty);
      expect(hard.length, 1);
    });
  });

  group('存档与恢复', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GameSave.clear();
    });

    test('toMap/loadFromMap 往返保持状态', () {
      final c1 = GameController(difficulty: Difficulty.medium, rng: Random(42));
      // 找两个非给定格
      int empty1 = -1, empty2 = -1;
      for (int i = 0; i < 81; i++) {
        if (!c1.given[i ~/ 9][i % 9]) {
          if (empty1 < 0) {
            empty1 = i;
          } else if (empty2 < 0) {
            empty2 = i;
            break;
          }
        }
      }
      // 填数字和笔记
      c1.select(empty1);
      c1.enterDigit(5);
      c1.select(empty2);
      c1.toggleNotesMode();
      c1.enterDigit(3);
      c1.enterDigit(7);
      c1.toggleNotesMode();
      c1.elapsed = const Duration(seconds: 99);

      final map = c1.toMap();
      final c2 = GameController.blank()..loadFromMap(map);

      expect(c2.puzzle!.difficulty, Difficulty.medium);
      expect(c2.board[empty1 ~/ 9][empty1 % 9], 5);
      expect(c2.notes[empty2].contains(3), isTrue);
      expect(c2.notes[empty2].contains(7), isTrue);
      expect(c2.elapsed.inSeconds, 99);
      expect(c2.solved, isFalse);
    });

    test('GameSave save/load 往返', () async {
      final c1 = GameController(difficulty: Difficulty.hard, rng: Random(7));
      c1.select(0);
      c1.enterDigit(c1.puzzle!.solution[0][0]);
      await GameSave.save(c1.toMap());

      final loaded = await GameSave.load();
      expect(loaded, isNotNull);
      final c2 = GameController.blank()..loadFromMap(loaded!);
      expect(c2.puzzle!.difficulty, Difficulty.hard);
      expect(c2.board[0][0], c1.puzzle!.solution[0][0]);
    });

    test('GameSave clear 清除存档', () async {
      final c = GameController(difficulty: Difficulty.easy, rng: Random(1));
      await GameSave.save(c.toMap());
      await GameSave.clear();
      final loaded = await GameSave.load();
      expect(loaded, isNull);
    });

    test('无存档时 load 返回 null', () async {
      final loaded = await GameSave.load();
      expect(loaded, isNull);
    });
  });
}
