import 'package:mybrev_flutter/models/priest_access_content.dart';

class PriestAccessException implements Exception {
  const PriestAccessException(this.code);
  final String code;
  bool get revoked => code == 'ACCESS_REQUIRED';
  bool get quotaExhausted => code == 'QUOTA_EXHAUSTED';
  String get message => switch (code) {
    'INVALID_CODE' => 'Няправільны код актывацыі.',
    'OFFLINE' => 'Няма злучэння з інтэрнэтам. Паспрабуйце пазней.',
    'ACCESS_REQUIRED' => 'Доступ гэтай прылады адкліканы.',
    'REVOKED' => 'Доступ адкліканы. Звяжыцеся з адміністратарам.',
    'GRANT_UNREADABLE' =>
      'Не атрымалася праверыць дазвол прылады. Паведаміце адміністратару.',
    'AUTH_DISABLED' =>
      'Ананімная аўтарызацыя выключана. Паведаміце адміністратару.',
    'TOO_MANY_ATTEMPTS' => 'Зашмат спроб. Паспрабуйце пазней.',
    'QUOTA_EXHAUSTED' => 'Ліміт чытання вычарпаны. Паспрабуйце пазней.',
    'STORAGE' =>
      'Не атрымалася бяспечна захаваць стан доступу. Паспрабуйце яшчэ раз.',
    _ => 'Сэрвіс доступу часова недаступны. Паспрабуйце пазней.',
  };
  @override
  String toString() => 'PriestAccessException($code)';
}

class PriestDeviceGrant {
  const PriestDeviceGrant(this.uid, this.active, {this.lastActiveAt});
  final String uid;
  final bool active;
  final DateTime? lastActiveAt;
}

/// Firebase Auth owns the signed session and token refresh. Local UID hints
/// never authorize a read; each private request is evaluated by Firestore Rules.
abstract class PriestAccessGateway {
  Future<String?> restoreSession();
  Future<String> ensureAnonymousSession();
  Future<PriestDeviceGrant?> grant(String uid);
  Stream<PriestDeviceGrant?> watchGrant(String uid);
  Future<void> createGrant(String uid, String proof, String deviceName);
  Future<void> disable(String uid);
  Future<void> signOut();
  Future<void> recordActivity(String uid);
  Future<String> help();
  Future<PrayerAccessContent> publicContent();
  Future<PrayerAccessContent> protectedContent(String uid);
  Future<Map<String, dynamic>?> readProtectedPrayer(String uid, String id);
  Future<void> clearProtectedMemory();
  Future<void> close();
}
