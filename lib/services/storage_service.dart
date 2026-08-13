import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_block.dart';

class StorageService {
  static const String _userNameKey = 'user_name';
  static const String _scheduleKey = 'study_schedule';

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  Future<void> saveSchedule(List<StudyBlock> blocks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(blocks.map((b) => b.toJson()).toList());
    await prefs.setString(_scheduleKey, jsonString);
  }

  Future<List<StudyBlock>?> getSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_scheduleKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => StudyBlock.fromJson(json)).toList();
    }
    return null;
  }
}
