import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SpaceInvadersApp());
}

class SpaceInvadersApp extends StatelessWidget {
  const SpaceInvadersApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Invaders',
      debugShowCheckedModeBanner: false,
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late SpaceInvadersGame game;

  @override
  void initState() {
    super.initState();
    game = SpaceInvadersGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: GameWidget(game: game),
      ),
    );
  }
}

class SpaceInvadersGame extends FlameGame with HasKeyboardHandlerComponents {
  static const double playerSpeed = 250;
  static const double bulletSpeed = 400;
  static const double alienSpeed = 50;
  static const double alienDropDistance = 30;

  late Player player;
  late TextComponent scoreText;
  late TextComponent livesText;
  late TextComponent gameOverText;
  late TextComponent startText;

  List<Alien> aliens = [];
  List<Bullet> bullets = [];
  List<AlienBullet> alienBullets = [];
  List<Star> stars = [];
  
  Random random = Random();
  int score = 0;
  int lives = 3;
  int level = 1;
  bool gameStarted = false;
  bool gameOver = false;
  bool alienDirectionRight = true;
  
  double timeSinceLastAlienShoot = 0;
  double alienShootInterval = 1.5;
  double timeSinceLastStarSpawn = 0;

  @override
  Future<void> onLoad() async {
    // Create starfield background
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF000011),
    ));

    // Create stars
    createStars();

    // Initialize player
    player = Player();
    add(player);

    // Initialize UI
    scoreText = TextComponent(
      text: 'Score: 0',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      position: Vector2(20, 30),
    );
    add(scoreText);

    livesText = TextComponent(
      text: 'Lives: 3',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      position: Vector2(20, 60),
    );
    add(livesText);

    startText = TextComponent(
      text: 'SPACE INVADERS\n\nUse ARROW KEYS to move\nSPACE to shoot\n\nPress SPACE to start!',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(startText);

    gameOverText = TextComponent(
      text: 'GAME OVER\n\nPress SPACE to restart',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.red,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
  }

  void createStars() {
    for (int i = 0; i < 100; i++) {
      final star = Star(
        position: Vector2(
          random.nextDouble() * size.x,
          random.nextDouble() * size.y,
        ),
      );
      stars.add(star);
      add(star);
    }
  }

  void createAliens() {
    aliens.clear();
    const int rows = 5;
    const int cols = 10;
    const double alienWidth = 40;
    const double alienHeight = 30;
    const double spacing = 50;
    
    double startX = (size.x - (cols * spacing)) / 2;
    double startY = 100;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final alien = Alien(
          position: Vector2(
            startX + col * spacing,
            startY + row * spacing,
          ),
          alienType: row < 2 ? AlienType.fast : AlienType.normal,
        );
        aliens.add(alien);
        add(alien);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!gameStarted || gameOver) return;

    // Update star movement
    timeSinceLastStarSpawn += dt;
    if (timeSinceLastStarSpawn > 0.1) {
      timeSinceLastStarSpawn = 0;
      if (stars.length < 150) {
        final star = Star(
          position: Vector2(random.nextDouble() * size.x, -5),
        );
        stars.add(star);
        add(star);
      }
    }

    // Remove off-screen stars
    stars.removeWhere((star) {
      if (star.position.y > size.y + 10) {
        star.removeFromParent();
        return true;
      }
      return false;
    });

    // Move aliens
    moveAliens(dt);

    // Alien shooting
    timeSinceLastAlienShoot += dt;
    if (timeSinceLastAlienShoot > alienShootInterval) {
      timeSinceLastAlienShoot = 0;
      alienShoot();
    }

    // Check bullet collisions
    checkBulletCollisions();

    // Check alien bullet collisions with player
    checkAlienBulletCollisions();

    // Check if player reached bottom
    checkAlienInvasion();

    // Check if all aliens destroyed
    if (aliens.isEmpty) {
      nextLevel();
    }

    // Remove off-screen bullets
    cleanupBullets();
  }

  void moveAliens(double dt) {
    if (aliens.isEmpty) return;

    bool shouldDrop = false;
    
    // Check if any alien hits the edge
    for (var alien in aliens) {
      if ((alienDirectionRight && alien.position.x > size.x - 60) ||
          (!alienDirectionRight && alien.position.x < 60)) {
        shouldDrop = true;
        break;
      }
    }

    if (shouldDrop) {
      alienDirectionRight = !alienDirectionRight;
      for (var alien in aliens) {
        alien.position.y += alienDropDistance;
      }
    } else {
      double moveAmount = alienSpeed * dt * (alienDirectionRight ? 1 : -1);
      for (var alien in aliens) {
        alien.position.x += moveAmount;
      }
    }
  }

  void alienShoot() {
    if (aliens.isEmpty) return;
    
    // Random alien shoots
    final shootingAlien = aliens[random.nextInt(aliens.length)];
    final bullet = AlienBullet(
      position: Vector2(
        shootingAlien.position.x + shootingAlien.size.x / 2,
        shootingAlien.position.y + shootingAlien.size.y,
      ),
    );
    alienBullets.add(bullet);
    add(bullet);
  }

  void checkBulletCollisions() {
    for (int i = bullets.length - 1; i >= 0; i--) {
      final bullet = bullets[i];
      
      for (int j = aliens.length - 1; j >= 0; j--) {
        final alien = aliens[j];
        
        if (bullet.position.x < alien.position.x + alien.size.x &&
            bullet.position.x + bullet.size.x > alien.position.x &&
            bullet.position.y < alien.position.y + alien.size.y &&
            bullet.position.y + bullet.size.y > alien.position.y) {
          
          // Hit!
          score += alien.alienType == AlienType.fast ? 20 : 10;
          updateScore();
          
          bullet.removeFromParent();
          bullets.removeAt(i);
          
          alien.removeFromParent();
          aliens.removeAt(j);
          
          HapticFeedback.lightImpact();
          break;
        }
      }
    }
  }

  void checkAlienBulletCollisions() {
    for (int i = alienBullets.length - 1; i >= 0; i--) {
      final bullet = alienBullets[i];
      
      if (bullet.position.x < player.position.x + player.size.x &&
          bullet.position.x + bullet.size.x > player.position.x &&
          bullet.position.y < player.position.y + player.size.y &&
          bullet.position.y + bullet.size.y > player.position.y) {
        
        // Player hit!
        bullet.removeFromParent();
        alienBullets.removeAt(i);
        
        lives--;
        updateLives();
        
        if (lives <= 0) {
          triggerGameOver();
        } else {
          HapticFeedback.mediumImpact();
        }
        break;
      }
    }
  }

  void checkAlienInvasion() {
    for (var alien in aliens) {
      if (alien.position.y + alien.size.y > size.y - 100) {
        triggerGameOver();
        break;
      }
    }
  }

  void cleanupBullets() {
    bullets.removeWhere((bullet) {
      if (bullet.position.y < -10) {
        bullet.removeFromParent();
        return true;
      }
      return false;
    });

    alienBullets.removeWhere((bullet) {
      if (bullet.position.y > size.y + 10) {
        bullet.removeFromParent();
        return true;
      }
      return false;
    });
  }

  void startGame() {
    gameStarted = true;
    startText.removeFromParent();
    createAliens();
  }

  void nextLevel() {
    level++;
    alienShootInterval = max(0.5, alienShootInterval - 0.1);
    createAliens();
  }

  void triggerGameOver() {
    gameOver = true;
    add(gameOverText);
    HapticFeedback.heavyImpact();
  }

  void restartGame() {
    gameStarted = false;
    gameOver = false;
    score = 0;
    lives = 3;
    level = 1;
    alienShootInterval = 1.5;
    alienDirectionRight = true;

    // Clear all game objects
    for (var alien in aliens) {
      alien.removeFromParent();
    }
    aliens.clear();

    for (var bullet in bullets) {
      bullet.removeFromParent();
    }
    bullets.clear();

    for (var bullet in alienBullets) {
      bullet.removeFromParent();
    }
    alienBullets.clear();

    // Reset player
    player.reset();

    // Reset UI
    updateScore();
    updateLives();
    gameOverText.removeFromParent();
    add(startText);
  }

  void updateScore() {
    scoreText.text = 'Score: $score';
  }

  void updateLives() {
    livesText.text = 'Lives: $lives';
  }

  void playerShoot() {
    if (bullets.length < 3) { // Limit bullets
      final bullet = Bullet(
        position: Vector2(
          player.position.x + player.size.x / 2 - 2,
          player.position.y,
        ),
      );
      bullets.add(bullet);
      add(bullet);
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.space)) {
        if (!gameStarted) {
          startGame();
        } else if (gameOver) {
          restartGame();
        } else {
          playerShoot();
        }
      }
    }

    if (gameStarted && !gameOver) {
      player.updateMovement(keysPressed);
    }

    return true;
  }
}

class Player extends RectangleComponent with HasGameRef<SpaceInvadersGame> {
  late Vector2 startPosition;

  @override
  Future<void> onLoad() async {
    size = Vector2(60, 40);
    final game = parent as SpaceInvadersGame;
    startPosition = Vector2(game.size.x / 2 - size.x / 2, game.size.y - 80);
    position = startPosition.clone();
    paint = Paint()..color = Colors.cyan;

    // Add ship details
    add(RectangleComponent(
      size: Vector2(20, 10),
      position: Vector2(20, 0),
      paint: Paint()..color = Colors.white,
    ));
  }

  void updateMovement(Set<LogicalKeyboardKey> keysPressed) {
    final game = parent as SpaceInvadersGame;
    double dt = 1/60; // Approximate delta time
    
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      position.x -= SpaceInvadersGame.playerSpeed * dt;
      position.x = max(0, position.x);
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      position.x += SpaceInvadersGame.playerSpeed * dt;
      position.x = min(game.size.x - size.x, position.x);
    }
  }

  void reset() {
    position = startPosition.clone();
  }
}

enum AlienType { normal, fast }

class Alien extends RectangleComponent {
  final AlienType alienType;

  Alien({required Vector2 position, required this.alienType})
      : super(position: position, size: Vector2(40, 30));

  @override
  Future<void> onLoad() async {
    paint = Paint()..color = alienType == AlienType.fast ? Colors.red : Colors.green;

    // Add alien details
    add(RectangleComponent(
      size: Vector2(10, 10),
      position: Vector2(5, 5),
      paint: Paint()..color = Colors.white,
    ));
    add(RectangleComponent(
      size: Vector2(10, 10),
      position: Vector2(25, 5),
      paint: Paint()..color = Colors.white,
    ));
  }
}

class Bullet extends RectangleComponent {
  Bullet({required Vector2 position}) : super(position: position, size: Vector2(4, 10));

  @override
  Future<void> onLoad() async {
    paint = Paint()..color = Colors.yellow;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= SpaceInvadersGame.bulletSpeed * dt;
  }
}

class AlienBullet extends RectangleComponent {
  AlienBullet({required Vector2 position}) : super(position: position, size: Vector2(4, 10));

  @override
  Future<void> onLoad() async {
    paint = Paint()..color = Colors.red;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += SpaceInvadersGame.bulletSpeed * dt;
  }
}

class Star extends CircleComponent {
  double speed;

  Star({required Vector2 position})
      : speed = Random().nextDouble() * 50 + 25,
        super(
          position: position,
          radius: Random().nextDouble() * 1.5 + 0.5,
          paint: Paint()..color = Colors.white.withOpacity(Random().nextDouble() * 0.8 + 0.2),
        );

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;
  }
}