import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lógica pura del minijuego "Sprint": un corredor en una pista de atletismo
/// de 3 carriles que esquiva vallas, conos y rivales y recoge monedas y
/// bebidas energéticas. Sin dependencias de UI más allá de [Color]; el
/// render vive en `sprint_painter.dart` y el bucle (Ticker) en la pantalla.
///
/// Coordenadas del mundo (metros):
///  * `lane` / `x`: carril 0..2 (valores continuos para el jugador).
///  * `z`: distancia hacia delante desde el jugador (0 = pies del jugador).
///  * `y`: altura sobre la pista.

enum SprintStatus { countdown, running, paused, over }

enum SprintEntityKind { hurdle, cone, rival, coin, drink }

enum SprintEventType { start, laneChange, jump, land, coin, drink, smash, hurdleCleared, levelUp, newBest, crash }

class SprintEntity {
  final SprintEntityKind kind;
  final int lane;
  double z;

  /// Ya se resolvió (recogido, saltado, esquivado o golpeado).
  bool resolved = false;

  /// No se dibuja (recogido o destruido con turbo).
  bool hidden = false;

  /// Semilla visual (colores de rivales, fase de animación).
  final double seed;

  SprintEntity(this.kind, this.lane, this.z, this.seed);

  bool get isObstacle =>
      kind == SprintEntityKind.hurdle || kind == SprintEntityKind.cone || kind == SprintEntityKind.rival;
}

class SprintParticle {
  double x, y, z, vx, vy, vz;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final bool gravity;

  SprintParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.life,
    required this.size,
    required this.color,
    this.gravity = true,
  }) : maxLife = life;
}

class SprintPopup {
  final String text;
  final Color color;
  final double size;
  double x, y;
  double life;
  final double maxLife;

  SprintPopup(this.text, this.color, this.x, this.y, {this.size = 20, this.life = 0.9}) : maxLife = life;
}

class SprintGame extends ChangeNotifier {
  // ── Ajustes de juego ──────────────────────────────────────────────
  static const int laneCount = 3;
  static const double spawnZ = 100;
  static const double drawFarZ = 105;
  static const double baseSpeed = 16; // m/s
  static const double speedPerLevel = 2.4;
  static const double maxSpeed = 44;
  static const double levelDistance = 350; // metros por nivel
  static const double jumpDuration = 0.62;
  static const double jumpPeak = 1.25;
  static const double hurdleClearHeight = 0.45;
  static const double comboWindow = 2.4;
  static const double turboDuration = 4.5;
  static const int coinPoints = 10;
  static const double countdownSeconds = 3;

  final math.Random _rng;

  /// Callback de eventos (hápticos, banners). Lo asigna la pantalla.
  void Function(SprintEventType type)? onEvent;

  /// Récord previo, para anunciar "¡Nuevo récord!" una sola vez.
  int bestScore;

  /// Sin colisiones letales (vista previa).
  final bool invincible;

  /// Piloto automático (vista previa).
  final bool autopilot;

  SprintStatus status = SprintStatus.countdown;
  SprintStatus _statusBeforePause = SprintStatus.running;

  double countdown = countdownSeconds;
  double elapsed = 0; // segundos corriendo
  double time = 0; // reloj de animación (siempre avanza salvo en pausa)
  double distance = 0;
  double speed = baseSpeed;
  int level = 1;
  double _score = 0;
  int coins = 0;
  int dodged = 0;
  int combo = 0;
  int maxCombo = 0;
  double comboTimer = 0;
  double turboTimer = 0;
  double overTimer = 0;
  double shake = 0;
  double levelBanner = 0; // segundos restantes del banner "Nivel N"

  /// La partida terminó por choque (no por abandono).
  bool crashed = false;

  double playerX = 1;
  int targetLane = 1;
  double _jumpTime = -1;
  bool _fastFall = false;
  double runPhase = 0;

  double _distSinceRow = 0;
  double _dustTimer = 0;
  bool _newBestAnnounced = false;

  final List<SprintEntity> entities = [];
  final List<SprintParticle> particles = [];
  final List<SprintPopup> popups = [];

  /// Escudos: cada uno perdona un choque (boost por pasos reales del día).
  int shields;

  /// Segundos que quedan del destello del escudo al romperse (para el painter).
  double shieldFlash = 0;

  SprintGame({int? seed, this.bestScore = 0, this.invincible = false, this.autopilot = false, this.shields = 0})
      : _rng = math.Random(seed) {
    for (final z in [42.0, 64.0, 86.0]) {
      _spawnRow(z);
    }
  }

  /// Partida simulada unos segundos con piloto automático, para portadas.
  factory SprintGame.preview({int seed = 7}) {
    final game = SprintGame(seed: seed, invincible: true, autopilot: true)
      ..status = SprintStatus.running
      ..countdown = 0;
    for (var i = 0; i < 150; i++) {
      game._advance(1 / 60);
    }
    game.particles.clear();
    game.popups.clear();
    return game;
  }

  // ── Getters derivados ─────────────────────────────────────────────
  int get score => _score.floor();
  bool get isRunning => status == SprintStatus.running;
  bool get isOver => status == SprintStatus.over;
  bool get isPaused => status == SprintStatus.paused;
  bool get isTurbo => turboTimer > 0;
  bool get isJumping => _jumpTime >= 0;
  double get turboFraction => (turboTimer / turboDuration).clamp(0.0, 1.0);
  double get comboFraction => (comboTimer / comboWindow).clamp(0.0, 1.0);
  int get comboMultiplier => (1 + combo ~/ 5).clamp(1, 5);
  int get multiplier => comboMultiplier * (isTurbo ? 2 : 1);
  double get effectiveSpeed => speed * (isTurbo ? 1.25 : 1);
  double get levelProgress => (distance % levelDistance) / levelDistance;
  int get durationMs => (elapsed * 1000).round();

  /// Altura actual del salto (parábola).
  double get jumpHeight {
    if (_jumpTime < 0) return 0;
    final t = (_jumpTime / jumpDuration).clamp(0.0, 1.0);
    return 4 * jumpPeak * t * (1 - t);
  }

  /// Inclinación al cambiar de carril (-1..1).
  double get lean => (targetLane - playerX).clamp(-1.0, 1.0);

  // ── Controles ─────────────────────────────────────────────────────
  void moveLeft() => _moveTo(targetLane - 1);
  void moveRight() => _moveTo(targetLane + 1);

  void _moveTo(int lane) {
    if (status != SprintStatus.running) return;
    final clamped = lane.clamp(0, laneCount - 1);
    if (clamped == targetLane) return;
    targetLane = clamped;
    onEvent?.call(SprintEventType.laneChange);
  }

  void jump() {
    if (status != SprintStatus.running || _jumpTime >= 0) return;
    _jumpTime = 0;
    _fastFall = false;
    onEvent?.call(SprintEventType.jump);
  }

  /// Desliza hacia abajo durante un salto: cae más rápido.
  void drop() {
    if (_jumpTime >= 0) _fastFall = true;
  }

  void pause() {
    if (status == SprintStatus.running || status == SprintStatus.countdown) {
      _statusBeforePause = status;
      status = SprintStatus.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (status == SprintStatus.paused) {
      status = _statusBeforePause;
      notifyListeners();
    }
  }

  /// Termina la partida (abandono). No genera partículas de choque.
  void forfeit() {
    if (status == SprintStatus.over) return;
    status = SprintStatus.over;
    overTimer = 0;
    notifyListeners();
  }

  // ── Bucle ─────────────────────────────────────────────────────────
  /// Avanza la simulación [dt] segundos y notifica para repintar.
  void update(double dt) {
    if (status == SprintStatus.paused) return;
    _advance(dt.clamp(0.0, 0.05));
    notifyListeners();
  }

  void _advance(double dt) {
    time += dt;
    _updateEffects(dt);
    switch (status) {
      case SprintStatus.countdown:
        countdown -= dt;
        runPhase += dt * 3;
        if (countdown <= 0) {
          countdown = 0;
          status = SprintStatus.running;
          onEvent?.call(SprintEventType.start);
        }
        break;
      case SprintStatus.running:
        _step(dt);
        break;
      case SprintStatus.over:
        overTimer += dt;
        break;
      case SprintStatus.paused:
        break;
    }
  }

  void _step(double dt) {
    elapsed += dt;
    final targetSpeed = math.min(baseSpeed + (level - 1) * speedPerLevel, maxSpeed);
    speed += (targetSpeed - speed) * math.min(1.0, dt * 1.5);
    final move = effectiveSpeed * dt;
    distance += move;
    _score += move; // 1 punto por metro

    final newLevel = 1 + distance ~/ levelDistance;
    if (newLevel > level) {
      level = newLevel;
      levelBanner = 1.8;
      onEvent?.call(SprintEventType.levelUp);
    }

    if (autopilot) _autopilot();

    playerX += (targetLane - playerX) * math.min(1.0, dt * 16);

    if (_jumpTime >= 0) {
      _jumpTime += dt * (_fastFall ? 2.6 : 1);
      if (_jumpTime >= jumpDuration) {
        _jumpTime = -1;
        _fastFall = false;
        _burst(playerX, 0, 0.2, 8, const Color(0xFFE8C9A8), speed: 2.2, size: 0.09, life: 0.4);
        onEvent?.call(SprintEventType.land);
      }
    }

    runPhase += dt * (9 + speed * 0.22);

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        comboTimer = 0;
        combo = 0;
      }
    }
    if (turboTimer > 0) {
      turboTimer = math.max(0, turboTimer - dt);
    }
    if (shieldFlash > 0) {
      shieldFlash = math.max(0, shieldFlash - dt);
    }

    for (final e in entities) {
      e.z -= move;
      if (!e.resolved && status == SprintStatus.running) _resolve(e);
    }
    entities.removeWhere((e) => e.z < -8);

    _distSinceRow += move;
    final rowInterval = (1.25 - (level - 1) * 0.07).clamp(0.6, 1.25);
    if (_distSinceRow >= speed * rowInterval) {
      _distSinceRow = 0;
      _spawnRow(spawnZ);
    }

    // Polvo de las zapatillas
    if (!isJumping) {
      _dustTimer -= dt;
      if (_dustTimer <= 0) {
        _dustTimer = 0.09;
        particles.add(SprintParticle(
          x: playerX + (_rng.nextDouble() - 0.5) * 0.25,
          y: 0.02,
          z: -0.1,
          vx: (_rng.nextDouble() - 0.5) * 0.6,
          vy: 0.6 + _rng.nextDouble() * 0.6,
          vz: -2 - _rng.nextDouble() * 2,
          life: 0.35,
          size: 0.07,
          color: const Color(0x99E8C9A8),
        ));
      }
    }
    if (isTurbo && _rng.nextDouble() < 0.6) {
      particles.add(SprintParticle(
        x: playerX + (_rng.nextDouble() - 0.5) * 0.5,
        y: 0.3 + _rng.nextDouble() * 1.3 + jumpHeight,
        z: 0,
        vx: 0,
        vy: 0,
        vz: -9,
        life: 0.3,
        size: 0.06,
        color: const Color(0xFF22D3EE),
        gravity: false,
      ));
    }

    if (!_newBestAnnounced && bestScore > 0 && score > bestScore) {
      _newBestAnnounced = true;
      popups.add(SprintPopup('¡NUEVO RÉCORD!', const Color(0xFFF59E0B), playerX, 2.6, size: 24, life: 1.6));
      onEvent?.call(SprintEventType.newBest);
    }
  }

  void _resolve(SprintEntity e) {
    final overlaps = e.z < 0.9 && e.z > -0.7 && (e.lane - playerX).abs() < 0.55;
    if (overlaps) {
      switch (e.kind) {
        case SprintEntityKind.coin:
          e.resolved = true;
          e.hidden = true;
          coins++;
          combo++;
          if (combo > maxCombo) maxCombo = combo;
          comboTimer = comboWindow;
          final pts = coinPoints * multiplier;
          _score += pts;
          _popup('+$pts', const Color(0xFFFFD166));
          if (combo % 5 == 0 && comboMultiplier > 1) {
            popups.add(SprintPopup('COMBO x$comboMultiplier', const Color(0xFFFF6B35), playerX, 2.9, size: 22, life: 1.1));
          }
          _burst(e.lane.toDouble(), 0.9 + jumpHeight * 0.5, 0.3, 14, const Color(0xFFFFD166));
          onEvent?.call(SprintEventType.coin);
          return;
        case SprintEntityKind.drink:
          e.resolved = true;
          e.hidden = true;
          turboTimer = turboDuration;
          popups.add(SprintPopup('¡TURBO!', const Color(0xFF22D3EE), playerX, 2.6, size: 26, life: 1.3));
          _burst(e.lane.toDouble(), 0.9, 0.3, 22, const Color(0xFF22D3EE), speed: 4.5);
          onEvent?.call(SprintEventType.drink);
          return;
        case SprintEntityKind.hurdle:
          if (jumpHeight > hurdleClearHeight) {
            e.resolved = true;
            dodged++;
            final pts = 15 * multiplier;
            _score += pts;
            _popup('¡Salto! +$pts', const Color(0xFF10B981));
            onEvent?.call(SprintEventType.hurdleCleared);
            return;
          }
          _hit(e);
          return;
        case SprintEntityKind.cone:
        case SprintEntityKind.rival:
          _hit(e);
          return;
      }
    } else if (e.z <= -0.7) {
      e.resolved = true;
      if (e.isObstacle) {
        dodged++;
        _score += 5 * multiplier;
      }
    }
  }

  void _hit(SprintEntity e) {
    if (isTurbo || invincible) {
      e.resolved = true;
      e.hidden = true;
      dodged++;
      final pts = 20 * multiplier;
      _score += pts;
      _popup('¡BOOM! +$pts', const Color(0xFF22D3EE));
      _burst(e.lane.toDouble(), 0.6, 0.4, 18, _obstacleColor(e), speed: 5);
      shake = math.max(shake, 0.18);
      onEvent?.call(SprintEventType.smash);
      return;
    }
    if (shields > 0) {
      shields--;
      shieldFlash = 0.6;
      e.resolved = true;
      e.hidden = true;
      popups.add(SprintPopup('¡ESCUDO!', const Color(0xFF60A5FA), playerX, 2.6, size: 26, life: 1.3));
      _burst(e.lane.toDouble(), 0.8, 0.3, 24, const Color(0xFF60A5FA), speed: 5);
      shake = math.max(shake, 0.25);
      onEvent?.call(SprintEventType.smash);
      return;
    }
    e.resolved = true;
    crashed = true;
    status = SprintStatus.over;
    overTimer = 0;
    turboTimer = 0;
    shake = 0.5;
    _burst(playerX, 1.0, 0.3, 30, const Color(0xFFEF4444), speed: 5.5);
    _burst(playerX, 1.0, 0.3, 16, Colors.white, speed: 4);
    onEvent?.call(SprintEventType.crash);
  }

  Color _obstacleColor(SprintEntity e) {
    switch (e.kind) {
      case SprintEntityKind.cone:
        return const Color(0xFFFF6B35);
      case SprintEntityKind.rival:
        return const Color(0xFFEF4444);
      default:
        return Colors.white;
    }
  }

  void _popup(String text, Color color) {
    popups.add(SprintPopup(text, color, playerX, 2.1));
  }

  void _burst(double x, double y, double z, int count, Color color,
      {double speed = 3.2, double size = 0.11, double life = 0.7}) {
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final s = speed * (0.4 + _rng.nextDouble() * 0.8);
      particles.add(SprintParticle(
        x: x,
        y: y,
        z: z,
        vx: math.cos(a) * s * 0.35, // en carriles (≈2 m)
        vy: math.sin(a).abs() * s + 1,
        vz: (_rng.nextDouble() - 0.5) * s,
        life: life * (0.6 + _rng.nextDouble() * 0.6),
        size: size * (0.6 + _rng.nextDouble() * 0.8),
        color: color,
      ));
    }
  }

  void _updateEffects(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      if (p.gravity) p.vy -= 9 * dt;
      if (p.y < 0) {
        p.y = 0;
        p.vy = -p.vy * 0.3;
      }
    }
    particles.removeWhere((p) => p.life <= 0);
    if (particles.length > 400) particles.removeRange(0, particles.length - 400);

    for (final p in popups) {
      p.life -= dt;
      p.y += dt * 1.2;
    }
    popups.removeWhere((p) => p.life <= 0);

    if (shake > 0) shake = math.max(0, shake - dt);
    if (levelBanner > 0) levelBanner = math.max(0, levelBanner - dt);
  }

  // ── Generación de filas ───────────────────────────────────────────
  void _spawnRow(double z) {
    final lanes = List<int>.generate(laneCount, (i) => i)..shuffle(_rng);

    var obstacleCount = 1;
    if (level <= 2 && _rng.nextDouble() < 0.15) {
      obstacleCount = 0; // fila de respiro
    } else if (level >= 3 && _rng.nextDouble() < math.min(0.15 + level * 0.04, 0.55)) {
      obstacleCount = 2;
    }

    final blocked = lanes.take(obstacleCount).toList();
    final free = lanes.skip(obstacleCount).toList();

    // Monedas previas que quedarían encima de un obstáculo nuevo
    entities.removeWhere((e) =>
        !e.isObstacle && blocked.contains(e.lane) && (e.z - z).abs() < 3);

    for (final lane in blocked) {
      entities.add(SprintEntity(_pickObstacle(), lane, z, _rng.nextDouble()));
    }

    if (free.isEmpty) return;
    final pickupLane = free[_rng.nextInt(free.length)];
    final roll = _rng.nextDouble();
    if (!isTurbo && roll < 0.07 + math.min(level, 8) * 0.005) {
      entities.add(SprintEntity(SprintEntityKind.drink, pickupLane, z, _rng.nextDouble()));
    } else if (roll < 0.62) {
      final count = 3 + _rng.nextInt(3);
      for (var i = 0; i < count; i++) {
        entities.add(SprintEntity(SprintEntityKind.coin, pickupLane, z + 2 + i * 3.0, i * 0.4));
      }
    }
  }

  SprintEntityKind _pickObstacle() {
    final r = _rng.nextDouble();
    if (level >= 2 && r < 0.22) return SprintEntityKind.rival;
    if (r < 0.62) return SprintEntityKind.hurdle;
    return SprintEntityKind.cone;
  }

  void _autopilot() {
    bool blockedAt(int lane) => entities.any((e) =>
        !e.resolved && e.isObstacle && e.kind != SprintEntityKind.hurdle && e.lane == lane && e.z > 0 && e.z < 16);
    SprintEntity? hurdleAhead = entities.cast<SprintEntity?>().firstWhere(
        (e) => !e!.resolved && e.kind == SprintEntityKind.hurdle && e.lane == targetLane && e.z > 0 && e.z < 4.5,
        orElse: () => null);
    if (hurdleAhead != null && !isJumping) {
      _jumpTime = 0;
    }
    if (blockedAt(targetLane)) {
      for (final lane in [targetLane - 1, targetLane + 1, targetLane - 2, targetLane + 2]) {
        if (lane >= 0 && lane < laneCount && !blockedAt(lane)) {
          targetLane = lane;
          break;
        }
      }
    }
  }
}
