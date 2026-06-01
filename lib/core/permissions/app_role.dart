/// Papéis de aplicação (RBAC).
///
/// Perfis principais: Master, Admin, Suporte, Vendedor, Usuário.
/// Papéis `affiliate`, `partner`, `finance` permanecem para módulo comercial futuro.
enum AppRole {
  masterAdmin('masterAdmin', 'Administrador Master'),
  admin('admin', 'Administrador'),
  support('support', 'Suporte'),
  seller('seller', 'Vendedor'),
  user('user', 'Usuário'),

  /// Alias legado — preferir [user].
  student('student', 'Usuário'),

  affiliate('affiliate', 'Afiliado'),
  partner('partner', 'Parceiro'),
  finance('finance', 'Financeiro');

  final String key;
  final String label;

  const AppRole(this.key, this.label);

  /// Perfis exibidos no painel (5 principais).
  static const List<AppRole> primaryProfiles = [
    AppRole.masterAdmin,
    AppRole.admin,
    AppRole.support,
    AppRole.seller,
    AppRole.user,
  ];

  static AppRole? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;
    final normalized = key.trim();
    if (normalized == 'student') return AppRole.user;
    for (final r in AppRole.values) {
      if (r.key == normalized) return r;
    }
    return null;
  }

  static List<AppRole> fromKeys(Iterable<String>? keys) {
    if (keys == null) return const [];
    final out = <AppRole>[];
    for (final k in keys) {
      final r = fromKey(k.toString());
      if (r != null && !out.contains(r)) out.add(r);
    }
    return out;
  }
}
