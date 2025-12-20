import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

class PreferencesService {
  static const String _preferencesKey = 'user_preferences';

  Future<UserPreferences> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_preferencesKey);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return UserPreferences.fromJson(json);
      }
      
      // Return default preferences
      return const UserPreferences();
    } catch (e) {
      // If there's an error loading, return defaults
      return const UserPreferences();
    }
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(preferences.toJson());
      await prefs.setString(_preferencesKey, jsonString);
    } catch (e) {
      throw Exception('Failed to save preferences: $e');
    }
  }

  Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preferencesKey);
    } catch (e) {
      throw Exception('Failed to clear preferences: $e');
    }
  }
}

