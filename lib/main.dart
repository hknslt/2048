import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = openDatabase(
    join(await getDatabasesPath(), 'score_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE scores(id INTEGER PRIMARY KEY, highscore INTEGER)',
      );
    },
    version: 1,
  );
  runApp(GameWidget(game: Game2048(database: database)));
}

class Game2048 extends FlameGame with PanDetector {
  static const int gridSize = 4;
  late List<List<int>> grid;
  late List<List<int>> previousGrid;
  int score = 0;
  int highScore = 0;
  int previousScore = 0;
  bool gameOver = false;
  final Future<Database> database;
  late Rect restartButtonRect;

  Game2048({required this.database});

  @override
  Future<void> onLoad() async {
    await loadHighScore();
    resetGrid();
  }

  Future<void> loadHighScore() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('scores');
    if (maps.isNotEmpty) {
      highScore = maps.first['highscore'];
    } else {
      await db.insert('scores', {'id': 1, 'highscore': 0});
    }
  }

  Future<void> updateHighScore() async {
    if (score > highScore) {
      highScore = score;
      final db = await database;
      await db.update('scores', {'highscore': highScore}, where: 'id = ?', whereArgs: [1]);
    }
  }

  void savePreviousState() {
    previousGrid = grid.map((row) => List<int>.from(row)).toList();
    previousScore = score;
  }

  void undoMove() {
    grid = previousGrid.map((row) => List<int>.from(row)).toList();
    score = previousScore;
    gameOver = false;
  }

  void resetGrid() {
    previousGrid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    previousScore = 0;
    grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    score = 0;
    gameOver = false;
    addNewTile();
    addNewTile();
  }

  void addNewTile() {
    final empty = <Point<int>>[];
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (grid[y][x] == 0) empty.add(Point(x, y));
      }
    }
    if (empty.isNotEmpty) {
      final spot = empty[Random().nextInt(empty.length)];
      grid[spot.y][spot.x] = Random().nextBool() ? 2 : 4;
    } else if (!canMove()) {
      gameOver = true;
    }
  }

  bool canMove() {
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final val = grid[y][x];
        if (val == 0) return true;
        if (x < gridSize - 1 && val == grid[y][x + 1]) return true;
        if (y < gridSize - 1 && val == grid[y + 1][x]) return true;
      }
    }
    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final boardSize = size.x < size.y ? size.x * 0.9 : size.y * 0.9;
    final sizePerTile = boardSize / gridSize;
    canvas.translate((size.x - boardSize) / 2, (size.y - boardSize) / 2);

    final bgPaint = Paint()..color = const Color(0xFFBBADA0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, boardSize, boardSize),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final val = grid[y][x];
        final tilePaint = Paint()..color = getTileColor(val);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x * sizePerTile + 6, y * sizePerTile + 6, sizePerTile - 12, sizePerTile - 12),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, tilePaint);

        if (val != 0) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: '$val',
              style: TextStyle(
                fontSize: val < 100 ? 32 : val < 1000 ? 28 : 24,
                color: val <= 4 ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(
            canvas,
            Offset(x * sizePerTile + (sizePerTile - textPainter.width) / 2,
                y * sizePerTile + (sizePerTile - textPainter.height) / 2),
          );
        }
      }
    }

    final scorePainter = TextPainter(
      text: TextSpan(
        text: 'Score: $score   Best: $highScore',
        style: const TextStyle(fontSize: 20, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scorePainter.paint(canvas, Offset(0, -40));

    final btnWidth = 50.0;
    final btnHeight = 50.0;
    final restartRect = Rect.fromLTWH(boardSize - btnWidth, -60, btnWidth, btnHeight);
    restartButtonRect = restartRect;
    final btnPaint = Paint()..color = Colors.orange;
    canvas.drawRRect(RRect.fromRectAndRadius(restartRect, Radius.circular(12)), btnPaint);

    final icon = Icons.refresh.codePoint;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon),
        style: const TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(canvas, Offset(restartRect.left + 13, restartRect.top + 12));

    if (gameOver) {
      final gameOverText = TextPainter(
        text: const TextSpan(
          text: 'Game Over',
          style: TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      gameOverText.paint(canvas, Offset((boardSize - gameOverText.width) / 2, boardSize / 2 - 20));
    }
  }

  Color getTileColor(int value) {
    switch (value) {
      case 2:
        return const Color(0xFFEEE4DA);
      case 4:
        return const Color(0xFFEDE0C8);
      case 8:
        return const Color(0xFFF2B179);
      case 16:
        return const Color(0xFFF59563);
      case 32:
        return const Color(0xFFF67C5F);
      case 64:
        return const Color(0xFFF65E3B);
      case 128:
        return const Color(0xFFEDCF72);
      case 256:
        return const Color(0xFFEDCC61);
      case 512:
        return const Color(0xFFEDC850);
      case 1024:
        return const Color(0xFFEDC53F);
      case 2048:
        return const Color(0xFFEDC22E);
      default:
        return const Color(0xFFCDC1B4);
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (gameOver) return;
    savePreviousState();

    final dx = info.velocity.x;
    final dy = info.velocity.y;

    bool moved = false;
    if (dx.abs() > dy.abs()) {
      moved = dx > 0 ? moveRight() : moveLeft();
    } else {
      moved = dy > 0 ? moveDown() : moveUp();
    }

    if (moved) {
      addNewTile();
      updateHighScore();
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    final boardSize = size.x < size.y ? size.x * 0.9 : size.y * 0.9;
    final offset = Vector2((size.x - boardSize) / 2, (size.y - boardSize) / 2);
    final tapPos = info.eventPosition.global - offset;
    if (restartButtonRect.contains(Offset(tapPos.x, tapPos.y))) {
      resetGrid();
      onGameResize(size);


    }
  }

  bool moveLeft() {
    bool moved = false;
    for (int y = 0; y < gridSize; y++) {
      final row = grid[y].where((e) => e != 0).toList();
      for (int i = 0; i < row.length - 1; i++) {
        if (row[i] == row[i + 1]) {
          row[i] *= 2;
          score += row[i];
          row[i + 1] = 0;
          moved = true;
        }
      }
      final newRow = row.where((e) => e != 0).toList();
      while (newRow.length < gridSize) newRow.add(0);
      if (!listEquals(grid[y], newRow)) {
        grid[y] = newRow;
        moved = true;
      }
    }
    return moved;
  }

  bool moveRight() {
    flipHorizontal();
    final moved = moveLeft();
    flipHorizontal();
    return moved;
  }

  bool moveUp() {
    transpose();
    final moved = moveLeft();
    transpose();
    return moved;
  }

  bool moveDown() {
    transpose();
    final moved = moveRight();
    transpose();
    return moved;
  }

  void transpose() {
    for (int y = 0; y < gridSize; y++) {
      for (int x = y + 1; x < gridSize; x++) {
        final temp = grid[y][x];
        grid[y][x] = grid[x][y];
        grid[x][y] = temp;
      }
    }
  }

  void flipHorizontal() {
    for (int y = 0; y < gridSize; y++) {
      grid[y] = grid[y].reversed.toList();
    }
  }
}
