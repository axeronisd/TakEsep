import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  double _pageOffset = 0.0;
  bool _isLoading = true;

  final _slides = [
    (
      title: 'Умный Дашборд',
      description:
          'Анализируйте выручку, чистую прибыль и средний чек в реальном времени. Графики адаптируются под любой экран.',
      icon: Icons.dashboard_customize_rounded,
      color: AppColors.primary,
    ),
    (
      title: '4 Зоны Остатков',
      description:
          'Товары разделены на зоны: Красная (критично), Желтая (внимание), Зеленая (норма) и Синяя (избыток).',
      icon: Icons.inventory_2_rounded,
      color: AppColors.warning,
    ),
    (
      title: 'Полный Контроль',
      description:
          'Управляйте продажами, приходами, перемещениями и ревизиями с удобным фильтром и сортировкой прямо из коробки.',
      icon: Icons.analytics_rounded,
      color: AppColors.success,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0.0;
      });
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('has_onboarded_v2') ?? false;

    if (hasOnboarded) {
      if (mounted) context.go('/dashboard');
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_onboarded_v2', true);
    if (mounted) context.go('/dashboard');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final int currentPage = _pageOffset.round();
    final currentColor =
        _slides[currentPage.clamp(0, _slides.length - 1)].color;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Dynamic ambient background blobs
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            top: currentPage == 0 ? -100 : (currentPage == 1 ? 100 : -50),
            left: currentPage == 0 ? -100 : (currentPage == 1 ? 200 : -100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            bottom: currentPage == 0 ? -100 : (currentPage == 1 ? -50 : 100),
            right: currentPage == 0 ? -100 : (currentPage == 1 ? -100 : 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _slides[(currentPage + 1) % _slides.length]
                    .color
                    .withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: Text('Пропустить',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final s = _slides[index];
                      // Calculate scale/opacity for parallax/transition effect
                      final double diff = (_pageOffset - index);
                      final double opacity = (1 - diff.abs()).clamp(0.0, 1.0);
                      final double scale =
                          (1 - (diff.abs() * 0.2)).clamp(0.8, 1.0);

                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icon with a glassmorphic card behind it
                                Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                      color: cs.surface.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.1),
                                          width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                s.color.withValues(alpha: 0.25),
                                            blurRadius: 50,
                                            spreadRadius: 5),
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10)),
                                      ]),
                                  child:
                                      Icon(s.icon, size: 100, color: s.color),
                                ),
                                const SizedBox(height: 60),
                                Text(s.title,
                                    style: AppTypography.displayMedium.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: AppSpacing.lg),
                                Text(s.description,
                                    style: AppTypography.bodyLarge.copyWith(
                                        color:
                                            cs.onSurface.withValues(alpha: 0.7),
                                        height: 1.6,
                                        fontSize: 16),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                      AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 8),
                            height: 10,
                            width: currentPage == index ? 32 : 10,
                            decoration: BoxDecoration(
                              color: currentPage == index
                                  ? currentColor
                                  : cs.outline.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(boxShadow: [
                          BoxShadow(
                              color: currentColor.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5)),
                        ]),
                        child: TEButton(
                          label: currentPage == _slides.length - 1
                              ? 'Начать работу'
                              : 'Далее',
                          icon: currentPage == _slides.length - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          onPressed: () {
                            if (currentPage == _slides.length - 1) {
                              _finishOnboarding();
                            } else {
                              _pageController.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutCubic);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
