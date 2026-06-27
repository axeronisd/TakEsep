import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

/// A modern, overlay-based onboarding built into the dashboard.
/// It displays floating cards explaining key features.
class DashboardOnboardingOverlay extends StatefulWidget {
  final Widget child;

  const DashboardOnboardingOverlay({super.key, required this.child});

  @override
  State<DashboardOnboardingOverlay> createState() =>
      _DashboardOnboardingOverlayState();
}

class _DashboardOnboardingOverlayState extends State<DashboardOnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _showOverlay = false;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<double> _scale;

  final _steps = [
    (
      title: 'Добро пожаловать!',
      desc:
          'Это ваш умный Дашборд. Здесь вы видите выручку, продажи и средний чек в реальном времени.',
      icon: Icons.dashboard_customize_rounded,
      color: AppColors.primary,
      align: Alignment.center,
    ),
    (
      title: '4 Зоны Остатков',
      desc:
          'Мы разделили товары: Красный (критично), Желтый (внимание), Зеленый (норма), Синий (много). Удобно следить за складом.',
      icon: Icons.inventory_2_rounded,
      color: AppColors.warning,
      align: Alignment.bottomRight,
    ),
    (
      title: 'Быстрые операции',
      desc:
          'Все нужные действия под рукой: продажа, приход, перемещение и ревизия. Начните работу прямо сейчас!',
      icon: Icons.bolt_rounded,
      color: AppColors.success,
      align: Alignment.centerLeft,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.9, end: 1)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));

    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('has_onboarded_overlay') ?? false;

    if (!hasOnboarded) {
      if (mounted) {
        setState(() => _showOverlay = true);
        _anim.forward();
      }
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_onboarded_overlay', true);

    await _anim.reverse();
    if (mounted) {
      setState(() => _showOverlay = false);
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _anim.reverse().then((_) {
        setState(() => _currentStep++);
        _anim.forward();
      });
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOverlay) return widget.child;

    return Stack(
      children: [
        widget.child,

        // Dark dim background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Container(
              color: Colors.black.withValues(alpha: 0.6 * _fade.value),
            ),
          ),
        ),

        // Content
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final step = _steps[_currentStep];
              final isDesktop = MediaQuery.of(context).size.width >= 900;

              return SafeArea(
                child: Align(
                  alignment: step.align,
                  child: Padding(
                    padding: EdgeInsets.all(
                        isDesktop ? AppSpacing.xxl * 2 : AppSpacing.xl),
                    child: Opacity(
                      opacity: _fade.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Container(
                          width: 340,
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusLg),
                            boxShadow: [
                              BoxShadow(
                                  color: step.color.withValues(alpha: 0.2),
                                  blurRadius: 40,
                                  spreadRadius: 5),
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: step.color.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(step.icon,
                                        color: step.color, size: 28),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Text(
                                    'Шаг ${_currentStep + 1} из ${_steps.length}',
                                    style: AppTypography.labelLarge.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 20),
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    onPressed: _finishOnboarding,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(step.title,
                                  style: AppTypography.headlineMedium),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                step.desc,
                                style: AppTypography.bodyMedium.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    height: 1.5),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: List.generate(
                                      _steps.length,
                                      (i) => Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        height: 6,
                                        width: _currentStep == i ? 20 : 6,
                                        decoration: BoxDecoration(
                                          color: _currentStep == i
                                              ? step.color
                                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                                  .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  TEButton(
                                    label: _currentStep == _steps.length - 1
                                        ? 'Понятно'
                                        : 'Далее',
                                    onPressed: _nextStep,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
