import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda datos en el dispositivo (en web, en el almacenamiento del navegador).
/// Así la información no se pierde al cerrar la app.
/// Cuando el backend esté listo, los repositorios pueden leer de la API en vez de aquí.
class LocalStore {
  LocalStore._(this._prefs);
  final SharedPreferences _prefs;

  static Future<LocalStore> open() async => LocalStore._(await SharedPreferences.getInstance());

  static const _prefix = 'pettracker.';

  /// Usuario actual: cada usuario tiene su propio espacio de datos
  /// (así lo de la cuenta demo nunca se mezcla con un usuario real).
  String? _scope;
  String? get scope => _scope;
  void setScope(String? userId) => _scope = userId;

  /// Clave de datos del usuario actual.
  String _key(String key) => _scope == null ? '$_prefix$key' : '${_prefix}u.$_scope.$key';

  Object? readJson(String key) {
    final raw = _prefs.getString(_key(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object? value) =>
      _prefs.setString(_key(key), jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(_key(key));

  /// Lista de objetos guardada bajo [key].
  List<T> readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final v = readJson(key);
    if (v is! List) return [];
    final out = <T>[];
    for (final e in v) {
      try {
        out.add(fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        // Si un registro está dañado, se ignora en vez de romper la app.
      }
    }
    return out;
  }

  Future<void> writeList<T>(String key, List<T> items, Map<String, dynamic> Function(T) toJson) =>
      writeJson(key, items.map(toJson).toList());

  String? getString(String key) => _prefs.getString(_key(key));
  Future<void> setString(String key, String value) => _prefs.setString(_key(key), value);
  bool? getBool(String key) => _prefs.getBool(_key(key));
  Future<void> setBool(String key, bool value) => _prefs.setBool(_key(key), value);
  int? getInt(String key) => _prefs.getInt(_key(key));
  Future<void> setInt(String key, int value) => _prefs.setInt(_key(key), value);

  // ── Datos generales (no dependen del usuario): sesión, idioma, tema ──────
  Object? readGlobal(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeGlobal(String key, Object? value) => _prefs.setString('$_prefix$key', jsonEncode(value));
  Future<void> removeGlobal(String key) => _prefs.remove('$_prefix$key');
  bool? getGlobalBool(String key) => _prefs.getBool('$_prefix$key');
  Future<void> setGlobalBool(String key, bool value) => _prefs.setBool('$_prefix$key', value);

  /// Borra todos los datos del usuario actual (por ejemplo, para reiniciar la demo).
  Future<void> clearScope() async {
    if (_scope == null) return;
    final p = '${_prefix}u.$_scope.';
    for (final k in _prefs.getKeys().where((k) => k.startsWith(p)).toList()) {
      await _prefs.remove(k);
    }
  }

  /// Borra todo lo de la app (cerrar sesión y empezar de cero).
  Future<void> clearAll() async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await _prefs.remove(k);
    }
  }
}
