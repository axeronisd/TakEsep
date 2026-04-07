import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile.dart';

/// AkJol Auth Service — единая авторизация для экосистемы
///
/// Регистрация: номер + username + пароль
/// Вход: username/номер + пароль + опционально биометрия
class AkJolAuthService {
  final SupabaseClient _client;

  AkJolAuthService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  // ─── Текущий пользователь ───────────────────

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── Регистрация ────────────────────────────

  /// Регистрация нового пользователя
  ///
  /// [phone] — номер без кода страны ("700123456")
  /// [username] — уникальный юзернейм
  /// [password] — пароль (мин. 6 символов)
  /// [name] — отображаемое имя
  Future<UserProfile> signUp({
    required String phone,
    required String username,
    required String password,
    String? name,
  }) async {
    final cleanPhone = _cleanPhone(phone);
    final cleanUsername = username.trim().toLowerCase();

    // Валидация
    if (cleanPhone.length < 9) {
      throw const AkJolAuthException('Введите корректный номер телефона');
    }
    if (cleanUsername.length < 3) {
      throw const AkJolAuthException('Username минимум 3 символа');
    }
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(cleanUsername)) {
      throw const AkJolAuthException('Username: только буквы, цифры, точка и _');
    }
    if (password.length < 6) {
      throw const AkJolAuthException('Пароль минимум 6 символов');
    }

    // Проверить уникальность username
    try {
      final existing = await _client
          .from('user_profiles')
          .select('id')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (existing != null) {
        throw const AkJolAuthException('Этот username уже занят');
      }
    } catch (e) {
      if (e is AkJolAuthException) rethrow;
      // Таблица может не существовать при первом запуске — пропускаем
    }

    try {
      final response = await _client.auth.signUp(
        phone: '+996$cleanPhone',
        password: password,
        data: {
          'username': cleanUsername,
          'name': name ?? '',
        },
      );

      if (response.user == null) {
        throw const AkJolAuthException('Ошибка регистрации');
      }
      
      if (response.session == null) {
        throw const AkJolAuthException(
            'Аккаунт создан, но Supabase требует подтверждения телефона по SMS. '
            'Пожалуйста, отключите "Confirm phone" в настройках Supabase (Authentication -> Providers -> Phone).');
      }

      // Обновить профиль с username
      try {
        await _client.from('user_profiles').upsert({
          'id': response.user!.id,
          'phone': '+996$cleanPhone',
          'username': cleanUsername,
          'name': name ?? '',
          'is_customer': true,
        }, onConflict: 'id');
      } catch (_) {
        // Триггер handle_new_user обработает
      }

      return await getOrCreateProfile(response.user!);
    } on AuthException catch (e) {
      throw AkJolAuthException(_parseAuthError(e.message));
    } on AkJolAuthException {
      rethrow;
    } catch (e) {
      throw const AkJolAuthException('Ошибка регистрации. Попробуйте позже.');
    }
  }

  // ─── Вход по паролю ─────────────────────────

  /// Вход по номеру телефона и паролю
  Future<UserProfile> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = _cleanPhone(phone);
    if (cleanPhone.length < 9) {
      throw const AkJolAuthException('Введите корректный номер телефона');
    }

    try {
      final response = await _client.auth.signInWithPassword(
        phone: '+996$cleanPhone',
        password: password,
      );

      if (response.user == null) {
        throw const AkJolAuthException('Неверный номер или пароль');
      }

      return await getOrCreateProfile(response.user!);
    } on AuthException catch (e) {
      throw AkJolAuthException(_parseAuthError(e.message));
    } on AkJolAuthException {
      rethrow;
    } catch (e) {
      throw const AkJolAuthException('Ошибка входа. Попробуйте позже.');
    }
  }

  /// Вход по username и паролю
  Future<UserProfile> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    // Найти номер телефона по username
    try {
      final result = await _client
          .from('user_profiles')
          .select('phone')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (result == null) {
        throw const AkJolAuthException('Пользователь не найден');
      }

      final phone = result['phone'] as String;
      if (phone.isEmpty) {
        throw const AkJolAuthException('Номер телефона не привязан');
      }

      // Вход по номеру
      final response = await _client.auth.signInWithPassword(
        phone: phone,
        password: password,
      );

      if (response.user == null) {
        throw const AkJolAuthException('Неверный пароль');
      }

      return await getOrCreateProfile(response.user!);
    } on AuthException catch (e) {
      throw AkJolAuthException(_parseAuthError(e.message));
    } on AkJolAuthException {
      rethrow;
    } catch (e) {
      throw const AkJolAuthException('Ошибка входа. Попробуйте позже.');
    }
  }

  /// Умный вход — по номеру или username
  Future<UserProfile> signIn({
    required String login,
    required String password,
  }) async {
    final trimmed = login.trim();

    // Если начинается с цифры или + → это номер
    if (trimmed.startsWith('+') || RegExp(r'^\d').hasMatch(trimmed)) {
      final phone = trimmed.replaceAll(RegExp(r'[^\d]'), '');
      // Убрать 996 в начале если есть
      final cleanPhone = phone.startsWith('996') ? phone.substring(3) : phone;
      return signInWithPhone(phone: cleanPhone, password: password);
    }

    // Иначе — username. Убираем @ если пользователь ввел его.
    final cleanUsername = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return signInWithUsername(username: cleanUsername, password: password);
  }

  // ─── OTP (для подтверждения телефона) ────────

  /// Отправить SMS код (для верификации при регистрации)
  Future<void> sendOtp(String phone) async {
    final cleanPhone = _cleanPhone(phone);
    if (cleanPhone.length < 9) {
      throw const AkJolAuthException('Введите корректный номер телефона');
    }

    try {
      await _client.auth.signInWithOtp(phone: '+996$cleanPhone');
    } on AuthException catch (e) {
      throw AkJolAuthException(_parseAuthError(e.message));
    } catch (e) {
      throw const AkJolAuthException('Ошибка отправки SMS.');
    }
  }

  /// Подтвердить SMS код
  Future<UserProfile> verifyOtp(String phone, String code) async {
    final cleanPhone = _cleanPhone(phone);
    try {
      final response = await _client.auth.verifyOTP(
        phone: '+996$cleanPhone',
        token: code,
        type: OtpType.sms,
      );

      if (response.user == null) {
        throw const AkJolAuthException('Неверный код');
      }

      return await getOrCreateProfile(response.user!);
    } on AuthException catch (e) {
      throw AkJolAuthException(_parseAuthError(e.message));
    } on AkJolAuthException {
      rethrow;
    } catch (e) {
      throw const AkJolAuthException('Ошибка верификации.');
    }
  }

  // ─── Профиль ────────────────────────────────

  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> getOrCreateProfile(User user) async {
    try {
      final existing = await _client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) return UserProfile.fromJson(existing);

      final newProfile = {
        'id': user.id,
        'phone': user.phone ?? '',
        'name': user.userMetadata?['name'] ?? '',
        'username': user.userMetadata?['username'],
        'is_customer': true,
      };

      final created = await _client
          .from('user_profiles')
          .upsert(newProfile, onConflict: 'id')
          .select()
          .single();

      return UserProfile.fromJson(created);
    } catch (_) {
      return UserProfile(
        id: user.id,
        phone: user.phone ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<UserProfile?> updateProfile({
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
    String? city,
    String? defaultAddress,
    double? defaultLat,
    double? defaultLng,
    String? language,
  }) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('user_profiles')
          .update({
            if (name != null) 'name': name,
            if (username != null) 'username': username.toLowerCase(),
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            if (bio != null) 'bio': bio,
            if (city != null) 'city': city,
            if (defaultAddress != null) 'default_address': defaultAddress,
            if (defaultLat != null) 'default_lat': defaultLat,
            if (defaultLng != null) 'default_lng': defaultLng,
            if (language != null) 'language': language,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id)
          .select()
          .single();

      return UserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> enableCourierRole() async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('user_profiles').update({
      'is_courier': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> enableDriverRole() async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('user_profiles').update({
      'is_driver': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  // ─── Выход ──────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Helpers ────────────────────────────────

  String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  }

  String _parseAuthError(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return 'Неверный логин или пароль';
    }
    if (msg.contains('User already registered') || msg.contains('already registered')) {
      return 'Этот номер телефона уже зарегистрирован';
    }
    if (msg.contains('Token has expired or is invalid')) {
      return 'Неверный или просроченный код';
    }
    if (msg.contains('Password should be')) {
      return 'Пароль должен быть минимум 6 символов';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Слишком много попыток. Подождите минуту.';
    }
    if (msg.contains('not enabled') || msg.contains('provider')) {
      return 'Способ входа не настроен';
    }
    // Если неизвестная ошибка, вернуть её так, как передана Supabase
    // Это поможет понять проблемы (например Database error)
    return 'Ошибка: $msg';
  }
}

/// Ошибка AkJol Auth
class AkJolAuthException implements Exception {
  final String message;
  const AkJolAuthException(this.message);

  @override
  String toString() => message;
}
