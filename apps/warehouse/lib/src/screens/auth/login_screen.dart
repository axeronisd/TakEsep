import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../providers/auth_providers.dart';

/// Login Screen with two modes: Owner (license key) and Employee (login + pin)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _keyController = TextEditingController();
  final _loginController = TextEditingController();
  final _pinController = TextEditingController();
  final _keyFocus = FocusNode();
  final _loginFocus = FocusNode();
  final _pinFocus = FocusNode();

  bool _obscurePin = true;
  bool _isOwnerMode = true;
  bool _biometricAvailable = false;
  bool _hasSavedCredentials = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyFocus.requestFocus();
      _checkBiometric();
    });
  }

  Future<void> _checkBiometric() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      final hasCreds = ref.read(authProvider.notifier).hasBiometricCredentials;
      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck;
          _hasSavedCredentials = hasCreds;
        });
      }
    } catch (_) {
      // Biometric not available on this device
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _loginController.dispose();
    _pinController.dispose();
    _keyFocus.dispose();
    _loginFocus.dispose();
    _pinFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitOwner() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    final authNotifier = ref.read(authProvider.notifier);
    authNotifier.clearError();

    final success = await authNotifier.loginCompany(key);
    if (success && mounted) {
      final state = ref.read(authProvider);
      if (!state.hasWarehouseSelected) {
        context.go('/select-warehouse');
      } else {
        _navigateBasedOnPermissions(state);
      }
    }
  }

  Future<void> _submitEmployee() async {
    final login = _loginController.text.trim();
    final pin = _pinController.text.trim();
    if (login.isEmpty || pin.isEmpty) return;

    final authNotifier = ref.read(authProvider.notifier);
    authNotifier.clearError();

    final success = await authNotifier.loginByNameAndPassword(login, pin);
    if (success && mounted) {
      final state = ref.read(authProvider);
      if (!state.hasWarehouseSelected) {
        context.go('/select-warehouse');
      } else {
        _navigateBasedOnPermissions(state);
      }
    }
  }

  void _navigateBasedOnPermissions(AuthState authState) {
    final permissions = authState.currentRole?.permissions ?? [];
    const routeMap = <String, String>{
      'dashboard': '/dashboard',
      'sales': '/sales',
      'income': '/income',
      'transfer': '/transfer',
      'audit': '/audit',
      'inventory': '/inventory',
      'services': '/services',
      'clients': '/clients',
      'employees': '/employees',
      'reports': '/reports',
      'settings': '/settings',
    };
    String target = '/dashboard';
    for (final perm in permissions) {
      if (routeMap.containsKey(perm)) {
        target = routeMap[perm]!;
        break;
      }
    }
    context.go(target);
  }

  Future<void> _submitBiometric() async {
    try {
      final auth = LocalAuthentication();
      final didAuth = await auth.authenticate(
        localizedReason: 'Войдите в TakEsep',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (!didAuth || !mounted) return;

      final authNotifier = ref.read(authProvider.notifier);
      authNotifier.clearError();
      final success = await authNotifier.loginWithSavedCredentials();
      if (success && mounted) {
        final state = ref.read(authProvider);
        if (!state.hasWarehouseSelected) {
          context.go('/select-warehouse');
        } else {
          _navigateBasedOnPermissions(state);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Биометрия недоступна')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Subtle animated background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surfaceContainerLowest,
                    cs.surface,
                    cs.surfaceContainerLowest,
                  ],
                ),
              ),
            ),
          ),

          // Decorative orbs
          Positioned(
            top: -180,
            right: -80,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -250,
            left: -120,
            child: Container(
              width: 650,
              height: 650,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? AppSpacing.lg : AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ═══ Header ═══
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
                          child: Column(
                            children: [
                              // Logo
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.primary.withValues(alpha: 0.2),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.JPG',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Вход в TakEsep',
                                style: AppTypography.headlineMedium.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ═══ Mode toggle ═══
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 0),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final tabWidth = constraints.maxWidth / 2;
                                return Stack(
                                  children: [
                                    // Animated sliding indicator
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      left: _isOwnerMode ? 0 : tabWidth,
                                      top: 0,
                                      bottom: 0,
                                      width: tabWidth,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cs.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Tab buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTab(
                                            cs,
                                            label: 'Владелец',
                                            icon: Icons.shield_outlined,
                                            isActive: _isOwnerMode,
                                            onTap: () {
                                              setState(() => _isOwnerMode = true);
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildTab(
                                            cs,
                                            label: 'Сотрудник',
                                            icon: Icons.badge_outlined,
                                            isActive: !_isOwnerMode,
                                            onTap: () {
                                              setState(() => _isOwnerMode = false);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ═══ Form ═══
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(0, 0, 0, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                alignment: Alignment.topCenter,
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  child: _isOwnerMode
                                      ? _buildOwnerForm(cs)
                                      : _buildEmployeeForm(cs),
                                ),
                              ),

                              // Error
                              if (authState.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppSpacing.md),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color:
                                          cs.error.withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: cs.error
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                            Icons
                                                .error_outline_rounded,
                                            color: cs.error,
                                            size: 18),
                                        const SizedBox(
                                            width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            authState.error!,
                                            style: AppTypography
                                                .bodySmall
                                                .copyWith(
                                              color: cs.error,
                                              fontWeight:
                                                  FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 24),

                              // Submit button
                              SizedBox(
                                height: 52,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    gradient: authState.isLoading
                                        ? null
                                        : const LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              Color(0xFF7C5CE0),
                                            ],
                                          ),
                                    boxShadow: authState.isLoading
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(
                                                      alpha: 0.3),
                                              blurRadius: 16,
                                              offset:
                                                  const Offset(0, 6),
                                            ),
                                          ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: authState.isLoading
                                          ? null
                                          : (_isOwnerMode
                                              ? _submitOwner
                                              : _submitEmployee),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      child: Center(
                                        child: authState.isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.login_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(
                                                      width: 8),
                                                  Text(
                                                    'Войти',
                                                    style: AppTypography
                                                        .labelLarge
                                                        .copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ═══ Biometric button ═══
                        if (_biometricAvailable && _hasSavedCredentials)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'или',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: cs.onSurface.withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3))),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 52,
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: authState.isLoading ? null : _submitBiometric,
                                    icon: const Icon(Icons.fingerprint_rounded, size: 22),
                                    label: const Text('Войти по биометрии'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: AppTypography.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom: version
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'TakEsep v0.1.0',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    ColorScheme cs, {
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? AppColors.primary
                    : cs.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isActive
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.45),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerForm(ColorScheme cs) {
    return Column(
      key: const ValueKey('owner'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Лицензионный ключ', icon: Icons.vpn_key_outlined),
        const SizedBox(height: 8),
        TextFormField(
          controller: _keyController,
          focusNode: _keyFocus,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            fontFamily: 'monospace',
          ),
          decoration: _inputDecoration(
            cs,
            hint: 'XXXX-XXXX-XXXX-XXXX',
            icon: Icons.vpn_key_outlined,
          ),
          onFieldSubmitted: (_) => _submitOwner(),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildEmployeeForm(ColorScheme cs) {
    return Column(
      key: const ValueKey('employee'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Ключ сотрудника', icon: Icons.key_rounded),
        const SizedBox(height: 8),
        TextFormField(
          controller: _loginController,
          focusNode: _loginFocus,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500),
          decoration: _inputDecoration(
            cs,
            hint: 'AB3K-Q7YZ',
            icon: Icons.key_rounded,
          ),
          onFieldSubmitted: (_) => _pinFocus.requestFocus(),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),
        const _FieldLabel(label: 'PIN-код роли', icon: Icons.pin_outlined),
        const SizedBox(height: 8),
        TextFormField(
          controller: _pinController,
          focusNode: _pinFocus,
          obscureText: _obscurePin,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: _obscurePin ? 4.0 : 1.0,
          ),
          decoration: _inputDecoration(
            cs,
            hint: '• • • •',
            icon: Icons.pin_outlined,
            showToggle: true,
          ),
          onFieldSubmitted: (_) => _submitEmployee(),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    ColorScheme cs, {
    required String hint,
    required IconData icon,
    bool showToggle = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyLarge.copyWith(
        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        letterSpacing: 0,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      suffixIcon: showToggle
          ? IconButton(
              icon: Icon(
                _obscurePin
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
              splashRadius: 20,
            )
          : null,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

/// Label widget for form fields
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}


