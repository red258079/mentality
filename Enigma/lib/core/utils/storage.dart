import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/user.dart';

class StorageUtil {
  static late SharedPreferences _prefs;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Generic Preferences
  static Future<bool> setString(String key, String value) async => await _prefs.setString(key, value);
  static String? getString(String key) => _prefs.getString(key);

  static Future<bool> setBool(String key, bool value) async => await _prefs.setBool(key, value);
  static bool? getBool(String key) => _prefs.getBool(key);

  static Future<bool> remove(String key) async => await _prefs.remove(key);
  static Future<bool> clear() async => await _prefs.clear();

  // ── Secure Token Storage ──────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  static Future<void> deleteToken() async {
    await _secureStorage.delete(key: 'access_token');
  }

  static Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: 'refresh_token', value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  static Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: 'refresh_token');
  }

  /// Clear cả access + refresh token khi logout
  static Future<void> clearAllTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _prefs.remove(_keyCompleteProfileSkipped);
  }

  // ── Biometric & Remember Login Helpers ─────────────────────────────────────
  static bool get isBiometricEnabled => _prefs.getBool('biometric_enabled') ?? false;
  static Future<void> setBiometricEnabled(bool value) async =>
      await _prefs.setBool('biometric_enabled', value);

  static Future<void> saveBiometricCredentials(String email, String password) async {
    await _secureStorage.write(key: 'bio_email', value: email);
    await _secureStorage.write(key: 'bio_password', value: password);
  }

  static Future<Map<String, String>?> getBiometricCredentials() async {
    final email = await _secureStorage.read(key: 'bio_email');
    final password = await _secureStorage.read(key: 'bio_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  static Future<void> clearBiometricCredentials() async {
    await _secureStorage.delete(key: 'bio_email');
    await _secureStorage.delete(key: 'bio_password');
  }

  // App specific helpers
  static bool get hasSeenOnboarding => _prefs.getBool('has_seen_onboarding') ?? false;
  static Future<void> setHasSeenOnboarding(bool value) async =>
      await _prefs.setBool('has_seen_onboarding', value);

  static const _keyCompleteProfileSkipped = 'complete_profile_skipped';
  static bool get hasSkippedCompleteProfile => _prefs.getBool(_keyCompleteProfileSkipped) ?? false;
  static Future<void> setCompleteProfileSkipped(bool value) async =>
      await _prefs.setBool(_keyCompleteProfileSkipped, value);

  // ── Remember Login Credentials (Secure) ────────────────────────────────────
  /// Lưu email + password vào secure storage cho tính năng "Ghi nhớ đăng nhập"
  static Future<void> saveRememberCredentials(String email, String password) async {
    await _secureStorage.write(key: 'remember_email', value: email);
    await _secureStorage.write(key: 'remember_password', value: password);
  }

  /// Đọc credentials đã lưu cho tính năng "Ghi nhớ đăng nhập"
  static Future<Map<String, String>?> getRememberCredentials() async {
    final email = await _secureStorage.read(key: 'remember_email');
    final password = await _secureStorage.read(key: 'remember_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  /// Xóa credentials khi user tắt "Ghi nhớ đăng nhập" hoặc logout
  static Future<void> clearRememberCredentials() async {
    await _secureStorage.delete(key: 'remember_email');
    await _secureStorage.delete(key: 'remember_password');
  }

  // ── Cached User Profile (Offline-First Auth) ──────────────────────────────
  static const String _keyCachedUser = 'cached_user_profile';

  static Future<void> saveCachedUser(User user) async {
    await _prefs.setString(_keyCachedUser, jsonEncode(user.toJson()));
  }

  static User? getCachedUser() {
    final str = _prefs.getString(_keyCachedUser);
    if (str == null || str.isEmpty) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return User.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCachedUser() async {
    await _prefs.remove(_keyCachedUser);
    await _prefs.remove(_keyCompleteProfileSkipped);
  }

  // ── Offline Sync Queue ────────────────────────────────────────────────────
  static const String _keySyncQueue = 'offline_sync_queue';

  static List<Map<String, dynamic>> getSyncQueue() {
    final str = _prefs.getString(_keySyncQueue);
    if (str == null || str.isEmpty) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSyncQueue(List<Map<String, dynamic>> queue) async {
    await _prefs.setString(_keySyncQueue, jsonEncode(queue));
  }

  static Future<void> addToSyncQueue(Map<String, dynamic> item) async {
    final queue = getSyncQueue();
    queue.add(item);
    await saveSyncQueue(queue);
  }

  static Future<void> removeSyncQueueItem(String id) async {
    final queue = getSyncQueue();
    queue.removeWhere((item) => item['id'] == id);
    await saveSyncQueue(queue);
  }

  static Future<void> clearSyncQueue() async {
    await _prefs.remove(_keySyncQueue);
  }

  static int getPendingSyncCount() {
    return getSyncQueue().length;
  }

  // ── Offline Feature Data Caches ──────────────────────────────────────────
  static const String _keyCachedTasks = 'cached_tasks_list';
  static const String _keyCachedDashboard = 'cached_dashboard_summary';
  static const String _keyCachedTodayCheckin = 'cached_today_checkin';
  static const String _keyCachedTodayLifeLog = 'cached_today_lifelog';

  static Future<void> saveCachedTasks(List<dynamic> tasks) async {
    await _prefs.setString(_keyCachedTasks, jsonEncode(tasks));
  }

  static List<dynamic>? getCachedTasks() {
    final str = _prefs.getString(_keyCachedTasks);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCachedDashboard(Map<String, dynamic> data) async {
    await _prefs.setString(_keyCachedDashboard, jsonEncode(data));
  }

  static Map<String, dynamic>? getCachedDashboard() {
    final str = _prefs.getString(_keyCachedDashboard);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCachedTodayCheckin(Map<String, dynamic> data) async {
    await _prefs.setString(_keyCachedTodayCheckin, jsonEncode(data));
  }

  static Map<String, dynamic>? getCachedTodayCheckin() {
    final str = _prefs.getString(_keyCachedTodayCheckin);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCachedTodayLifeLog(Map<String, dynamic> data) async {
    await _prefs.setString(_keyCachedTodayLifeLog, jsonEncode(data));
  }

  static Map<String, dynamic>? getCachedTodayLifeLog() {
    final str = _prefs.getString(_keyCachedTodayLifeLog);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Sleep Reminder Preferences ───────────────────────────────────────────
  static bool get isSleepReminderEnabled => _prefs.getBool('reminder_sleep_enabled') ?? false;
  static Future<void> setSleepReminderEnabled(bool value) async =>
      await _prefs.setBool('reminder_sleep_enabled', value);

  static int get sleepReminderHour => _prefs.getInt('reminder_sleep_hour') ?? 8;
  static int get sleepReminderMinute => _prefs.getInt('reminder_sleep_minute') ?? 30;
  static Future<void> setSleepReminderTime(int hour, int minute) async {
    await _prefs.setInt('reminder_sleep_hour', hour);
    await _prefs.setInt('reminder_sleep_minute', minute);
  }

  static bool get isNoonReminderEnabled => _prefs.getBool('reminder_noon_enabled') ?? false;
  static Future<void> setNoonReminderEnabled(bool value) async =>
      await _prefs.setBool('reminder_noon_enabled', value);
}
