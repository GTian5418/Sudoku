import 'dart:math';

/// 难度等级（对齐 HoDoKu 的五级：Easy / Medium / Hard / Unfair / Extreme）。
enum Difficulty { easy, medium, hard, unfair, extreme }

extension DifficultyX on Difficulty {
  /// 目标提示数(挖空后保留的格子数量上限)。
  int get clues => switch (this) {
        Difficulty.easy => 45,
        Difficulty.medium => 38,
        Difficulty.hard => 32,
        Difficulty.unfair => 27,
        Difficulty.extreme => 23,
      };

  String get label => switch (this) {
        Difficulty.easy => '简单',
        Difficulty.medium => '中等',
        Difficulty.hard => '困难',
        Difficulty.unfair => '超难',
        Difficulty.extreme => '极难',
      };
}

/// 一盘数独:完整解 + 挖空后的题目。
class SudokuPuzzle {
  final List<List<int>> solution;
  final List<List<int>> clues;
  final Difficulty difficulty;

  const SudokuPuzzle({
    required this.solution,
    required this.clues,
    required this.difficulty,
  });
}

/// 数独核心算法:合法性校验、求解计数、题目生成。
class SudokuEngine {
  static const int size = 9;

  /// 在 [row][col] 放 [value] 是否与行/列/宫冲突。
  static bool isValidPlacement(List<List<int>> grid, int row, int col, int value) {
    for (int i = 0; i < size; i++) {
      if (grid[row][i] == value || grid[i][col] == value) return false;
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if (grid[r][c] == value) return false;
      }
    }
    return true;
  }

  static List<List<int>> copyGrid(List<List<int>> grid) => [
        for (final row in grid) List<int>.of(row),
      ];

  /// 回溯生成一张完整合法的终盘。
  static List<List<int>> generateSolvedGrid(Random rng) {
    final grid = List.generate(size, (_) => List<int>.filled(size, 0));
    final digits = List<int>.generate(size, (i) => i + 1);

    bool fill(int pos) {
      if (pos == size * size) return true;
      final row = pos ~/ size;
      final col = pos % size;
      digits.shuffle(rng);
      for (final value in digits) {
        if (isValidPlacement(grid, row, col, value)) {
          grid[row][col] = value;
          if (fill(pos + 1)) return true;
          grid[row][col] = 0;
        }
      }
      return false;
    }

    fill(0);
    return grid;
  }

  /// 统计解的数量,达到 [limit] 即提前返回(用于唯一解校验)。
  static int countSolutions(List<List<int>> grid, {int limit = 2}) {
    int count = 0;

    void solve() {
      if (count >= limit) return;
      int target = -1;
      for (int i = 0; i < size * size; i++) {
        if (grid[i ~/ size][i % size] == 0) {
          target = i;
          break;
        }
      }
      if (target < 0) {
        count++;
        return;
      }
      final row = target ~/ size;
      final col = target % size;
      for (int value = 1; value <= size; value++) {
        if (isValidPlacement(grid, row, col, value)) {
          grid[row][col] = value;
          solve();
          grid[row][col] = 0;
          if (count >= limit) return;
        }
      }
    }

    solve();
    return count;
  }

  /// 生成题目:从终盘对称挖空,每次挖空后校验唯一解。
  static SudokuPuzzle generate({
    Difficulty difficulty = Difficulty.easy,
    Random? rng,
  }) {
    final random = rng ?? Random();
    final solution = generateSolvedGrid(random);
    final puzzle = copyGrid(solution);
    final target = difficulty.clues;

    final positions = List<int>.generate(size * size, (i) => i)..shuffle(random);
    int cluesLeft = size * size;

    for (final pos in positions) {
      if (cluesLeft <= target) break;
      final mirror = size * size - 1 - pos;
      final cells = pos == mirror ? [pos] : [pos, mirror];
      final backup = [for (final c in cells) puzzle[c ~/ size][c % size]];
      if (backup.every((v) => v == 0)) continue;

      for (final c in cells) {
        puzzle[c ~/ size][c % size] = 0;
      }
      if (countSolutions(copyGrid(puzzle)) != 1) {
        for (int i = 0; i < cells.length; i++) {
          puzzle[cells[i] ~/ size][cells[i] % size] = backup[i];
        }
      } else {
        cluesLeft -= cells.length;
      }
    }

    return SudokuPuzzle(
      solution: solution,
      clues: puzzle,
      difficulty: difficulty,
    );
  }
}
