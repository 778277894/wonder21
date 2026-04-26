import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const kLoggedIn = 'loggedIn';
  static const kUserId = 'user_Id';
  static const kUserRole = 'userRole';
  static const kBranchId = 'branch_id';

  static Future<void> saveLogin({
    required int userId,
    required String role,
    int? branchId,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kLoggedIn, true);
    await p.setInt(kUserId, userId);
    await p.setString(kUserRole, role);
    if (branchId != null) await p.setInt(kBranchId, branchId);
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(kLoggedIn);
    await p.remove(kUserId);
    await p.remove(kUserRole);
    await p.remove(kBranchId);
  }

  static Future<int?> get userId async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(kUserId);
  }

  static Future<String> get role async {
    final p = await SharedPreferences.getInstance();
    return p.getString(kUserRole) ?? 'user';
  }

  static Future<int?> get branchId async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(kBranchId);
  }
}
