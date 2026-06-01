/// Limites de paginação alinhados às regras Firestore (anti-scraping).
class ContentQueryLimits {
  ContentQueryLimits._();

  static const maxSearchResults = 30;
  static const maxPickerResults = 200;
  static const maxWhereInIds = 30;
  static const maxStudySubtema = 500;
  static const maxAdminListPage = 400;
}
