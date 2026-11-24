/// Form validators shared by both apps. Messages in Spanish (Chile).
abstract final class KuuValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPasswordLength = 8;

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Ingresa tu correo';
    if (!_email.hasMatch(s)) return 'Correo no válido';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
    return null;
  }

  /// For account creation: length plus at least one letter and one digit.
  static String? newPassword(String? v) {
    if (v == null || v.length < minPasswordLength) {
      return 'Mínimo $minPasswordLength caracteres';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Debe incluir letras y números';
    }
    return null;
  }

  static String? Function(String?) confirm(String Function() original) =>
      (v) => v == original() ? null : 'Las contraseñas no coinciden';

  static String? required(String? v, [String field = 'este campo']) =>
      (v?.trim().isEmpty ?? true) ? 'Completa $field' : null;
}
