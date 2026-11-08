import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the CRM sign-in password in the operating system's secure storage.
class AppCredentials {
  AppCredentials._();

  static const _storage = FlutterSecureStorage();
  static const _passwordKey = 'steel_wings_crm_login_password_v1';
  static const _defaultPassword = 'Mushroomkingdom24?';

  static Future<String> loadPassword() async =>
      await _storage.read(key: _passwordKey) ?? _defaultPassword;

  static Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final currentPassword = await loadPassword();
    if (oldPassword != currentPassword) return false;

    await _storage.write(key: _passwordKey, value: newPassword);
    if (await _storage.read(key: _passwordKey) != newPassword) {
      throw StateError('The new password could not be verified.');
    }
    return true;
  }
}
