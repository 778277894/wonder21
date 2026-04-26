import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  // تخزين حالة تسجيل الدخول
  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', value);
  }

  // قراءة حالة تسجيل الدخول
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('loggedIn') ?? false;
  }

  // تخزين بيانات المستخدم بصيغة JSON
  static Future<void> setUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  // استرجاع بيانات المستخدم
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString == null) return null;
    return jsonDecode(userString);
  }

  // تسجيل الخروج ومسح جميع البيانات
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedIn');
    await prefs.remove('user');
  }
}
