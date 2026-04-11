import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Splash-экран AkJol — иммерсивная анимация «погружения»
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Phase 1: Logo appears (0–800ms)
  late final AnimationController _enterController;
  // Phase 2: Text slides in (400–1200ms)
  late final AnimationController _textController;
  // Phase 3: Dive-in zoom effect (1800–2600ms)
  late final AnimationController _diveController;

  // Enter animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glowIntensity;

  // Text animations
  late final Animation<double> _akSlide;
  late final Animation<double> _jolSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _lineWidth;

  // Dive-in animations
  late final Animation<double> _diveScale;
  late final Animation<double> _diveOpacity;
  late final Animation<double> _bgBrightness;

  // Particles
  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Generate particles
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 1,
        speed: _random.nextDouble() * 0.5 + 0.2,
        opacity: _random.nextDouble() * 0.4 + 0.1,
      ));
    }

    // Phase 1: Logo enter
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: const Interval(0, 0.4, curve: Curves.easeOut)),
    );
    _glowIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: const Interval(0.3, 1.0, curve: Curves.easeInOut)),
    );

    // Phase 2: Text
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _akSlide = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _jolSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );
    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)),
    );

    // Phase 3: Dive-in (smooth zoom + fade)
    _diveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _diveScale = Tween<double>(begin: 1.0, end: 3.5).animate(
      CurvedAnimation(parent: _diveController, curve: Curves.easeInQuart),
    );
    _diveOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _diveController, curve: const Interval(0.2, 0.9, curve: Curves.easeIn)),
    );
    _bgBrightness = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _diveController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Phase 1
    await Future.delayed(const Duration(milliseconds: 150));
    _enterController.forward();

    // Phase 2
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();

    // Hold
    await Future.delayed(const Duration(milliseconds: 1800));

    // Determine destination
    final session = Supabase.instance.client.auth.currentSession;

    // Phase 3: DIVE IN!
    await _diveController.forward();

    if (!mounted) return;
    if (session != null) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _textController.dispose();
    _diveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFAFA),
      body: AnimatedBuilder(
        animation: Listenable.merge([_enterController, _textController, _diveController]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── Background with brightness shift ──
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color.lerp(
                        isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFAFA),
                        isDark ? const Color(0xFF0A1A0F) : const Color(0xFFEBFAF0),
                        _bgBrightness.value,
                      )!,
                      isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFAFA),
                    ],
                  ),
                ),
              ),

              // ── Floating particles ──
              ..._particles.map((p) {
                final yOffset = (_enterController.value * p.speed * 200) % screenSize.height;
                return Positioned(
                  left: p.x * screenSize.width,
                  top: (p.y * screenSize.height + yOffset) % screenSize.height,
                  child: Opacity(
                    opacity: p.opacity * _glowIntensity.value * (1 - _diveController.value),
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ),
                );
              }),

              // ── Main content with dive transform ──
              Center(
                child: Transform.scale(
                  scale: _diveScale.value,
                  child: Opacity(
                    opacity: _diveOpacity.value.clamp(0.0, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo ──
                        Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2ECC71).withValues(
                                      alpha: 0.35 * _glowIntensity.value,
                                    ),
                                    blurRadius: 50 * _glowIntensity.value,
                                    spreadRadius: 8 * _glowIntensity.value,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: Image.asset(
                                  'assets/images/akjol_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 44),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── AK JOL text ──
                        Opacity(
                          opacity: _textOpacity.value,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                offset: Offset(_akSlide.value, 0),
                                child: Text(
                                  'AK',
                                  style: TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: 4,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(_jolSlide.value, 0),
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C), Color(0xFF16A085)],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'JOL',
                                    style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Animated line ──
                        SizedBox(
                          width: 120 * _lineWidth.value,
                          height: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2ECC71).withValues(alpha: 0),
                                  const Color(0xFF2ECC71).withValues(alpha: 0.6 * _lineWidth.value),
                                  const Color(0xFF2ECC71).withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Subtitle ──
                        Opacity(
                          opacity: _subtitleOpacity.value,
                          child: Text(
                            'Биз Жакынбыз',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                              color: isDark
                                  ? const Color(0xFF6E7681)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x, y, size, speed, opacity;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}
