# 数独 (Sudoku)

Flutter 跨平台数独游戏，支持 Windows 桌面端与 Android 移动端。参考 [HoDoKu](https://github.com/sudoku/hodoku) 的难度分级与著色标记系统设计。

---

## 目录

- [功能一览](#功能一览)
- [技术栈](#技术栈)
- [专案结构](#专案结构)
- [快速开始](#快速开始)
- [构建指南](#构建指南)
- [开发过程](#开发过程)
- [架构设计](#架构设计)
- [测试](#测试)
- [已知问题](#已知问题)

---

## 功能一览

### 核心玩法
- **5 个难度等级**（对齐 HoDoKu）：简单 / 中等 / 困难 / 超难 / 极难
- **对称挖空生成**：从完整解中心对称移除，保证唯一解
- **笔记模式**：每格可标记 1-9 候选数，3×3 小数字排列
- **提示功能**：一键填入当前选中格或第一个空格的正确答案
- **冲突检测**：同行/列/宫重复数字红色标示
- **计时器**：自动计时，通关后停止

### 显示优化
- **同数字高亮**：选中某格或按数字键后，所有相同数字的格子蓝色高亮
- **同笔记高亮**：含相同候选数的空格浅黄色高亮
- **同数字关联高亮**：所有含该数字格子的行/列/宫灰色高亮
- **数字键盘联动**：点击底部数字键 (1-9) 触发同数字高亮，可连续填入
- **白底黑字**：简洁清晰的视觉风格

### 着色标记（HoDoKu 风格）
- **5 色对**：A(蓝) B(绿) C(粉) D(黄) E(紫)，每色有正色 + 反色
- **着色模式**：选色后点击格子着色，再点同色取消
- **键盘快捷键**：A-E 正色，Shift+A-E 反色
- **一键清色**：清除所有着色标记

### 排行榜
- **分难度记录**：每个难度独立排行榜
- **前 10 名**：按用时升序排列，🥇🥈🥉 标示前三
- **持久化存储**：基于 SharedPreferences，重启不丢失

### 自动存档
- **定时存档**：每 3 秒自动保存当前游戏状态
- **退出存档**：关闭应用前立即存档
- **启动恢复**：打开应用自动恢复上次未完成的局
- **通关清除**：完成后清除存档，记入排行榜

### 键盘操作（Windows）
| 按键 | 功能 |
|------|------|
| 1-9 / 小键盘 1-9 | 填数字 / 设定高亮数字 |
| A-E | 着色正色 1-5 |
| Shift+A-E | 着色反色 6-10 |
| N | 切换笔记模式 |
| H | 提示 |
| R | 清除所有颜色 |
| Backspace / Delete | 擦除 |
| 方向键 | 移动选中格 |
| Esc | 退出着色模式 / 清除选中 |

---

## 技术栈

| 组件 | 版本 / 说明 |
|------|------------|
| Flutter | 3.47.5 (stable) |
| Dart | ^3.13.4 |
| 状态管理 | `ChangeNotifier` + `ListenableBuilder` |
| 持久化 | `shared_preferences: ^2.3.3` |
| 平台 | Windows 11 + Android (SDK 36.0.0) |
| IDE | VS Code / Android Studio |
| 测试 | `flutter_test` (66 tests, 全部通过) |

---

## 专案结构

```
sudoku/
├── lib/
│   ├── main.dart                    # 应用入口、页面框架、自动存档、排行榜对话框
│   ├── logic/
│   │   ├── sudoku_engine.dart       # 数独核心：难度枚举、终盘生成、求解计数、题目生成
│   │   ├── game_controller.dart     # 游戏控制器：棋盘状态、笔记、着色、高亮、计时
│   │   ├── leaderboard.dart         # 排行榜：SharedPreferences 持久化，每难度前 10
│   │   └── game_save.dart           # 存档：当前游戏状态序列化/反序列化
│   └── ui/
│       ├── board_widget.dart        # 九宫格渲染：高亮、着色、笔记显示
│       └── number_pad.dart          # 数字键盘 + 功能按钮 + 着色面板
├── test/
│   └── sudoku_test.dart             # 66 个测试：引擎、控制器、高亮、着色、键盘、排行榜、存档
├── android/                         # Android 平台配置
├── windows/                         # Windows 平台配置
├── pubspec.yaml                     # 依赖声明
└── analysis_options.yaml            # Dart 静态分析规则
```

---

## 快速开始

### 环境要求

- Flutter 3.x (stable channel)
- Dart 3.13+
- Android: JDK 17 + Android SDK
- Windows: Visual Studio 2022 (Desktop development with C++ workload)

### 安装依赖

```bash
flutter pub get
```

### 运行

```bash
# Debug 模式
flutter run

# 指定设备
flutter run -d windows    # Windows 桌面
flutter run -d android    # Android 设备
```

---

## 构建指南

### Android APK

```bash
# 确保 JAVA_HOME 指向 JDK 17
export JAVA_HOME=/path/to/jdk-17

flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk (~44.6 MB)
```

### Windows EXE

```bash
# 需要 Visual Studio 2022 + C++ workload
flutter build windows --release
# 输出: build/windows/x64/runner/Release/sudoku.exe
```

> **注意**：Windows 构建需要 Visual Studio 2022 安装 "Desktop development with C++" 工作负载（含 MSVC、Windows SDK、CMake）。

### 跑测试

```bash
flutter test
# 66 tests passed
```

### 静态分析

```bash
flutter analyze
# No issues found
```

---

## 开发过程

本专案经历了以下迭代开发阶段：

### 阶段 1：基础数独引擎

**目标**：实现数独核心逻辑

- 建立 `SudokuEngine` 类，包含：
- `generateSolvedGrid()` — 回溯法生成完整合法终盘
- `countSolutions()` — 解计数（用于唯一解校验，limit=2 提前退出）
- `isValidPlacement()` — 行列宫冲突检测
- `generate()` — 对称挖空生成题目，每次挖空后校验唯一解
- 定义 `Difficulty` 枚举：easy / medium / hard / unfair / extreme
- 建立 `SudokuPuzzle` 资料类：solution + clues + difficulty

### 阶段 2：游戏控制器与 UI

**目标**：搭建可玩的数独界面

- 建立 `GameController extends ChangeNotifier`：
- 棋盘状态：`board` (9×9)、`given` (是否预填)、`notes` (每格候选集)
- 操作方法：`select()`、`enterDigit()`、`erase()`、`hint()`、`restart()`
- 计时器：每秒 tick，通关后停止
- 冲突检测：`hasConflict()`、通关判定：`_checkWin()`
- 建立 `BoardWidget`：GridView 9×9 渲染，粗细线区分宫
- 建立 `NumberPad`：数字键 1-9 + 功能按钮（笔记、擦除、提示、备份、恢复）
- 键盘事件处理：数字键、退格、方向键移动选中

### 阶段 3：HoDoKu 难度与著色系统

**目标**：对齐 HoDoKu 的 5 级难度与著色标记

- **难度调整**：设定各难度目标提示数
- Easy: 45 clues / Medium: 38 / Hard: 32 / Unfair: 27 / Extreme: 23
- **着色系统**：
- `cellColors` — List<int>(81)，0=无色，1-5=正色，6-10=反色
- `activeColor` — 当前画笔颜色
- `enterColorMode()` / `exitColorMode()` / `toggleCellColor()` / `clearAllColors()`
- 5 色对定义：A(蓝) B(绿) C(粉) D(黄) E(紫)，正色浅 + 反色深
- 颜色面板 UI：每色对显示正反两色圆点，点击=正色，长按=反色
- **键盘快捷键**：A-E 正色，Shift+A-E 反色，R 清色
- **白底黑字**：`scaffoldBackgroundColor: Colors.white`，给定字黑色，玩家字 black87
- **难度切换确认**：弹出 AlertDialog 确认后才切换

### 阶段 4：显示优化 — 同数字高亮

**目标**：选中数字后高亮所有相同数字

- 新增 `selectedValue` getter — 选中格的数字值
- 新增 `highlightDigit` getter — 驱动高亮的数字
- `BoardWidget` 中：
- `sameValue` — 所有与高亮数字相同的格子 → 蓝色 `#90CAF9`
- `sameNote` — 含高亮数字的笔记格 → 浅黄 `#FFF9C4`
- 笔记中的高亮数字 → 深蓝色加粗 `#1565C0`

### 阶段 5：数字键盘联动

**目标**：点击底部数字键也能触发同数字高亮，且可连续填入

- 新增 `activeDigit` — 数字键盘选中的数字
- `padDigit(digit)` — 切换 activeDigit，有选中格时填入
- `highlightDigit` = `activeDigit ?? selectedValue` — 优先级：键盘 > 选中格
- `tapCell(index)` — 路由：着色模式 → 着色；有 activeDigit → 填入并保持；否则 → 选中
- **连续标注**：activeDigit 保持不变，可连续点击多格填入同一数字
- **笔记模式保持**：padDigit 不关闭笔记模式，方便连续标记候选数

### 阶段 6：同数字关联高亮

**目标**：高亮所有含该数字格子的行/列/宫

- 新增 `isSameDigitPeer(index)` — 检查格子是否在任意同数字格的行/列/宫内
- `BoardWidget` 中：`samePeer` → 灰色 `#F0F0F0`
- 高亮优先级：peer/samePeer < sameNote < sameValue < selected < userColor

### 阶段 7：排行榜

**目标**：移除错误计数，改为排行榜系统

- 建立 `Leaderboard` 类：
- `addEntry(difficulty, seconds)` — 添加记录，按用时升序，保留前 10
- `getEntries(difficulty)` — 读取某难度排行榜
- `clear(difficulty)` — 清空某难度
- SharedPreferences 持久化，key = `leaderboard_{difficulty}`
- `_LeaderboardDialog` — 分难度 Tab，🥇🥈🥉 标示前三，显示用时 + 日期
- 通关后自动 `Leaderboard.addEntry()` 并弹出完成对话框

### 阶段 8：自动存档与恢复

**目标**：退出不丢失进度，启动自动恢复

- 建立 `GameSave` 类：SharedPreferences 存储当前游戏状态 JSON
- `GameController.toMap()` — 序列化：difficulty, solution, clues, board, notes, cellColors, elapsedSeconds, solved, notesMode
- `GameController.loadFromMap()` — 反序列化恢复完整状态
- `GameController.blank()` — 不生成新局的构造函数，用于存档恢复
- **自动存档**：`Timer.periodic(3 seconds)` 定时保存（非 debounce，避免 1 秒计时 tick 冲突）
- **启动恢复**：`_initFromSave()` 异步读取存档，有则恢复，无则新局
- **通关清除**：`GameSave.clear()` 通关后清除存档
- **退出存档**：`dispose()` 中立即保存未通关的局

### 阶段 9：环境配置与构建

**目标**：配置 Windows + Android 双平台构建环境

- **Flutter**：`D:\DevTools\flutter` (3.47.5 stable)
- **JDK**：`D:\DevTools\Java\jdk-17` (Temurin 17.0.20.1)，设定 `JAVA_HOME` 环境变数
- **Android SDK**：`D:\DevTools\Android\Sdk` (36.0.0)，接受所有 licenses
- **adb 冲突修复**：从系统 PATH 移除多余的 `D:\DevTools\ADB`
- **VS 2022**：`D:\DevTools\VS2022`（C++ workload，Windows 构建用）
- **Android 构建**：`flutter build apk --release` → 44.6 MB APK ✅
- **Windows 构建**：需 VS 2022 正确注册（见已知问题）

---

## 架构设计

### 状态管理

```
GameController (ChangeNotifier)
├── board: List<List<int>>       // 9×9 棋盘
├── given: List<List<bool>>     // 是否预填
├── notes: List<Set<int>>       // 每格候选数
├── cellColors: List<int>       // 每格著色 (0-10)
├── selected: int?              // 选中格索引
├── activeDigit: int?           // 键盘选中数字
├── activeColor: int?           // 当前画笔颜色
├── notesMode: bool             // 笔记模式
├── solved: bool                // 是否通关
├── elapsed: Duration           // 计时
└── puzzle: SudokuPuzzle?       // 当前题目
```

UI 层透过 `ListenableBuilder` 监听 `GameController`，控制器变更时自动重建。

### 高亮逻辑

```
highlightDigit = activeDigit ?? selectedValue

Cell 颜色判定优先级（低 → 高）：
1. 白色（预设）
2. 灰色（peer 或 sameDigitPeer）
3. 浅黄（sameNote — 含高亮数字的笔记）
4. 蓝色（sameValue — 与高亮数字相同）
5. 浅紫（selected — 选中格）
6. 用户着色（cellColors > 0，最高优先）
```

### 存档结构

```json
{
"difficulty": "medium",
"solution": [[9×9 完整解]],
"clues": [[9×9 初始题目]],
"board": [[9×9 当前棋盘]],
"notes": [[候选数列表]],
"cellColors": [81 个着色值],
"elapsedSeconds": 123,
"solved": false,
"notesMode": true
}
```

### 数独生成流程

```
1. generateSolvedGrid() — 回溯填满 9×9 合法终盘
2. 随机打乱 81 个位置
3. 逐个尝试对称挖空（pos + mirror）
4. 每次挖空后 countSolutions() 校验唯一解
5. 非唯一解则回退，保留该格
6. 达到目标提示数或遍历完毕 → 返回题目
```

---

## 测试

```bash
flutter test
```

**66 个测试，全部通过**，覆盖：

| 测试组 | 数量 | 覆盖范围 |
|--------|------|----------|
| SudokuEngine | 6 | 终盘合法性、唯一解、难度提示数、isValidPlacement |
| GameController | 6 | 填数、撤销、笔记、提示、通关判定、restart |
| 高亮延伸 | 16 | padDigit、highlightDigit 优先级、tapCell 连续标注、isSameDigitPeer |
| 备份与恢复 | 8 | backup/restore 往返、重开失效、不影响计时 |
| 着色功能 | 12 | enterColorMode、toggleCellColor、clearAllColors、tapCell 着色路由 |
| 键盘输入 | 5 | 数字键、小键盘、N 键笔记、退格、方向键 |
| 排行榜 | 5 | 升序排列、分难度、前 10 限制、clear |
| 存档与恢复 | 4 | toMap/loadFromMap 往返、GameSave save/load/clear |

---

## 已知问题

### Windows 构建需要 Visual Studio 2022

Windows EXE 构建需要 VS 2022 安装 "Desktop development with C++" 工作负载。如果 `flutter doctor` 显示 `Visual Studio not installed`：

```powershell
# 安装 VS 2022 到指定路径
vs_community.exe --installPath "D:\DevTools\VS2022" `
--add Microsoft.VisualStudio.Workload.NativeDesktop `
--add Microsoft.VisualStudio.Component.VC.CMake.Project `
--passive --norestart

# 验证
flutter doctor
flutter build windows --release
```

Android APK 构建不受此影响。

### resource.h 档案损坏

`windows/runner/resource.h` 偶尔会被覆盖为错误内容。构建前如遇到问题，恢复标准模板：

```cpp
#ifndef RUNNER_RESOURCE_H_
#define RUNNER_RESOURCE_H_

#define APP_NAME "sudoku"
#define APP_VERSION "1.0.0"
#define APP_VERSION_DWORD 1,0,0,0

#define IDC_APP_ICON 100
#define IDR_APP_MANIFEST 101

#endif  // RUNNER_RESOURCE_H_
```

---

## License

MIT