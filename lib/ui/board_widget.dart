import 'package:flutter/material.dart';

import '../logic/game_controller.dart';

class _Colors {
  static const cell = Colors.white;
  static const peer = Color(0xFFF0F0F0);
  static const same = Color(0xFF90CAF9); // 同数字：中蓝（更醒目）
  static const sameNote = Color(0xFFFFF9C4); // 同笔记：浅黄
  static const selected = Color(0xFFD0D0FF);
  static const gridThin = Color(0xFFCCCCCC);
  static const gridThick = Color(0xFF666666);
  static const givenText = Colors.black;
  static const userText = Colors.black87;
  static const errorText = Color(0xFFCC0000);
  static const noteText = Color(0xFF888888);
  static const noteHighlight = Color(0xFF1565C0); // 高亮笔记数字：深蓝
}

/// HoDoKu 风格的 5 色对（正色 1-5，反色 6-10）。
const List<Color> kCellColorPalette = [
  Color(0xFFB3D9FF), // 1 浅蓝 A
  Color(0xFFB3FFB3), // 2 浅绿 B
  Color(0xFFFFD9D9), // 3 浅粉 C
  Color(0xFFFFF3B3), // 4 浅黄 D
  Color(0xFFE6D9FF), // 5 浅紫 E
  Color(0xFF6699CC), // 6 深蓝 A'
  Color(0xFF66CC66), // 7 深绿 B'
  Color(0xFFE07878), // 8 深红 C'
  Color(0xFFFFCC66), // 9 橙色 D'
  Color(0xFFD99BE0), // 10 品红 E'
];

/// 九宫格棋盘。
class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: _Colors.cell,
          border: Border.all(color: _Colors.gridThick, width: 2),
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
            ),
            itemCount: 81,
            itemBuilder: (context, index) =>
                _CellView(controller: controller, index: index),
          ),
        ),
      ),
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({required this.controller, required this.index});

  final GameController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final row = index ~/ 9;
    final col = index % 9;
    final value = controller.board[row][col];
    final isSelected = controller.selected == index;
    final hl = controller.highlightDigit;
    final sameValue = !isSelected && value != 0 && value == hl;
    final sameNote = !isSelected && value == 0 && hl != null && controller.noteContains(index, hl);
    final peer = !isSelected && controller.isPeer(index);
    final samePeer = !isSelected && !sameValue && controller.isSameDigitPeer(index);
    final conflict = value != 0 && controller.hasConflict(row, col);
    final isGiven = controller.given[row][col];
    final colorIdx = controller.cellColors[index];

    var fill = _Colors.cell;
    if (peer || samePeer) fill = _Colors.peer;
    if (sameNote) fill = _Colors.sameNote;
    if (sameValue) fill = _Colors.same;
    if (isSelected) fill = _Colors.selected;
    // 用户着色优先级最高。
    if (colorIdx > 0) fill = kCellColorPalette[colorIdx - 1];

    final thick = const BorderSide(color: _Colors.gridThick, width: 1.5);
    final thin = const BorderSide(color: _Colors.gridThin, width: 0.6);

    return GestureDetector(
      onTap: () => controller.tapCell(index),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          border: Border(
            left: col % 3 == 0 ? thick : thin,
            top: row % 3 == 0 ? thick : thin,
          ),
        ),
        alignment: Alignment.center,
        child: value != 0
            ? Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: isGiven ? FontWeight.w700 : FontWeight.w500,
                  color: conflict
                      ? _Colors.errorText
                      : isGiven
                          ? _Colors.givenText
                          : _Colors.userText,
                ),
              )
            : _NotesView(notes: controller.notes[index], highlightDigit: hl),
      ),
    );
  }
}

class _NotesView extends StatelessWidget {
  const _NotesView({required this.notes, this.highlightDigit});

  final Set<int> notes;
  final int? highlightDigit;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final cell = constraints.biggest.shortestSide / 3;
      return Column(
        children: [
          for (int r = 0; r < 3; r++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int c = 0; c < 3; c++)
                  SizedBox(
                    width: cell,
                    height: cell,
                    child: Center(
                      child: Builder(builder: (context) {
                        final n = r * 3 + c + 1;
                        if (!notes.contains(n)) return const SizedBox.shrink();
                        final isHl = n == highlightDigit;
                        return Text(
                          '$n',
                          style: TextStyle(
                            fontSize: isHl ? 12 : 10,
                            fontWeight: isHl ? FontWeight.w700 : FontWeight.w400,
                            color: isHl ? _Colors.noteHighlight : _Colors.noteText,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
        ],
      );
    });
  }
}
