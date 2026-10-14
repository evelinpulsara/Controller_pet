import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de iniciar sesión o crear la cuenta.
enum LoginStatus { ok, invalid, confirmEmail, error }

class LoginResult {
  const LoginResult(this.status, [this.message]);
  final LoginStatus status;
  final String? message;
  bool get ok => status == LoginStatus.ok;
  static const success = LoginResult(LoginStatus.ok);
}

/// Inicio de sesión de las cuentas reales.
abstract class AuthService {
  /// Correo de la sesión guardada (null si no hay).
  String? get currentEmail;
  Future<LoginResult> signIn(String email, String password);
  Future<LoginResult> signUp(String email, String password, {String? fullName});
  Future<void> signOut();
}

/// Cuentas reales con Supabase Auth. Al registrarse se marca `app: pettracker`
/// para que la base de datos cree el perfil solo para esta app.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);
  final SupabaseClient _client;

  @override
  String? get currentEmail => _client.auth.currentSession == null ? null : _client.auth.currentUser?.email;

  @override
  Future<LoginResult> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await _ensureProfile();
      return LoginResult.success;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('not confirmed')) return const LoginResult(LoginStatus.confirmEmail);
      if (m.contains('invalid')) return const LoginResult(LoginStatus.invalid);
      return LoginResult(LoginStatus.error, e.message);
    } catch (e) {
      return LoginResult(LoginStatus.error, '$e');
    }
  }

  @override
  Future<LoginResult> signUp(String email, String password, {String? fullName}) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'app': 'pettracker', 'full_name': fullName ?? email.split('@').first},
      );
      // Si Supabase pide confirmar el correo, no hay sesión todavía.
      if (res.session == null) return const LoginResult(LoginStatus.confirmEmail);
      await _ensureProfile();
      return LoginResult.success;
    } on AuthException catch (e) {
      return LoginResult(LoginStatus.error, e.message);
    } catch (e) {
      return LoginResult(LoginStatus.error, '$e');
    }
  }

  /// Por si la cuenta se creó por fuera de la app: asegura que tenga perfil.
  Future<void> _ensureProfile() async {
    final u = _client.auth.currentUser;
    if (u == null) return;
    await _client.from('profiles').upsert({'id': u.id, 'full_name': u.email?.split('@').first}, ignoreDuplicates: true);
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
