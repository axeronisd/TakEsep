import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile.dart';

/// AkJol Auth Service — единая авторизация для экосистемы
/// 
/// Один номер телефона (+996) = один аккаунт для всех сервисов.
/// По аналогии с Яндекс ID.
class AkJolAuthService {
  final SupabaseClient _client;

  AkJolAuthService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  // ─── Текущий пользователь ───────────────────

  /// Текущий auth user
  User? get currentUser => _client.auth.currentUser;

  /// Авторизован ли
  bool get isLoggedIn => currentUser != null;

  /// Поток авторизации
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── OTP Авторизация ────────────────────────

  /// Отправить SMS код на +996...
  /// 
  /// [phone] — номер без кода страны (например "700123456")
  Future<void> sendOtp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.length < 9) {
      throw AkJolAuthException('Введите корректный номер телефона');
    }

    try {
      await _client.auth.signInWithOtp(
        phone: '+996$cleanPhone',
      );
    } on AuthException catch (e) {
      throw AkJolAuthException(_parseAuthError(e.message));
    } catch (e) {
      throw AkJolAuthException('Ошибка отправки SMS. Попробуйте позже.');
    }
  }

  /// Подтвердить SMS код
  /// 
  /// [phone] — номер без кода страны
  /// [code] — 6-значный OTP код
  /// 
  /// Возвращает [UserProfile] при успешной авторизации
  Future<UserProfile> verifyOtp(String phone, String code) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    try {
      final response = await _client.auth.verifyOTP(
        phone: '+996$cleanPhone',
        token: code,
        type: OtpType.sms,
      );

      if (response.user == null) {
        throw AkJolAuthException('Неверный код');
      }

      // Получить или создать профиль
      final profile = await getOrCreateProfile(response.user!);
      return profile;
    } on AuthException catch (e) {
      throw AkJolAuthException(_parseAuthError(e.message));
    } on AkJolAuthException {
      rethrow;
    } catch (e) {
      throw AkJolAuthException('Ошибка верификации. Попробуйте позже.');
    }
  }

  // ─── Профиль ────────────────────────────────

  /// Получить профиль текущего пользователя
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

  /// Получить или создать профиль при первом входе
  Future<UserProfile> getOrCreateProfile(User user) async {
    try {
      // Попробуем получить существующий
      final existing = await _client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        return UserProfile.fromJson(existing);
      }

      // Создать новый (на случай если триггер не сработал)
      final newProfile = {
        'id': user.id,
        'phone': user.phone ?? '',
        'name': '',
        'is_customer': true,
      };

      final created = await _client
          .from('user_profiles')
          .upsert(newProfile, onConflict: 'id')
          .select()
          .single();

      return UserProfile.fromJson(created);
    } catch (_) {
      // Fallback — вернуть минимальный профиль
      return UserProfile(
        id: user.id,
        phone: user.phone ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Обновить профиль
  Future<UserProfile?> updateProfile({
    String? name,
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

  /// Активировать роль курьера
  Future<void> enableCourierRole() async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('user_profiles').update({
      'is_courier': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  /// Активировать роль водителя такси
  Future<void> enableDriverRole() async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('user_profiles').update({
      'is_driver': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  // ─── Выход ──────────────────────────────────

  /// Выход из аккаунта (на всех устройствах)
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Helpers ────────────────────────────────

  String _parseAuthError(String msg) {
    if (msg.contains('Invalid login credentials') ||
        msg.contains('Token has expired or is invalid')) {
      return 'Неверный или просроченный код';
    }
    if (msg.contains('Phone number') || msg.contains('phone')) {
      return 'Некорректный номер телефона';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Слишком много попыток. Подождите минуту.';
    }
    if (msg.contains('not enabled') || msg.contains('provider')) {
      return 'SMS авторизация не настроена';
    }
    return 'Ошибка авторизации';
  }
}

/// Ошибка AkJol Auth
class AkJolAuthException implements Exception {
  final String message;
  const AkJolAuthException(this.message);

  @override
  String toString() => message;
}
