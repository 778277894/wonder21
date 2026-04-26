import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wonderful2/accounting/general_ledger_screen.dart';
import 'package:wonderful2/admin/admin_products_management.dart';
import 'package:wonderful2/admin/ads/admin_ads_management.dart';
import 'package:wonderful2/admin/branches_admin_screen.dart';
import 'package:wonderful2/admin/currencies/admin_currencies_screen.dart';
import 'package:wonderful2/admin/group/main_groups_screen.dart';
import 'package:wonderful2/products/all_products_screen.dart';
import 'admin_analytics.dart';
import 'admin_users_management.dart';
import 'admin_setting.dart';
import 'categories/categories_screen.dart';
import 'orders/admin_orders_screen.dart';
import 'excel_import_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  // إعداد السيرفر الديناميكي (نفس شاشة العميل)
  String get baseUrl {
    final ip = kIsWeb ? '127.0.0.1' : '192.168.0.16';
    return 'http://$ip';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة المدير"),
        backgroundColor: const Color.fromARGB(255, 225, 184, 60),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildCard(Icons.shopping_cart, "إدارة المنتجات", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AdminProductsManagement()),
            );
          }),
          _buildCard(Icons.people, "إدارة المستخدمين", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AdminUsersManagement()),
            );
          }),
          _buildCard(Icons.people, "إدارة الاستاذ العام", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const GeneralLedgerScreen()),
            );
          }),
          _buildCard(Icons.shopping_bag, "إدارة الطلبات", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AdminOrdersScreen()),
            );
          }),
          _buildCard(Icons.shopping_bag, " صفحة العملاء المنتجات", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AllProductsScreen()),
            );
          }),
          _buildCard(Icons.analytics, "الإحصائيات", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminAnalytics()),
            );
          }),
          _buildCard(Icons.analytics, "الفروع", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const BranchesAdminScreen()),
            );
          }),
          _buildCard(Icons.analytics, "المجموعات", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BranchesAdminScreen()),
            );
          }),
          _buildCard(Icons.analytics, "العملات", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AdminCurrenciesScreen()),
            );
          }),
          _buildCard(Icons.analytics, "الاعلانات", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AdminAdsManagement()),
            );
          }),
          _buildCard(Icons.settings, "الإعدادات", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminSetting()),
            );
          }),
          _buildCard(Icons.settings, "استيراد ملفات Excel", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExcelImportScreen()),
            );
          }),
          _buildCard(Icons.category, "الفئات", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoriesScreen()),
            );
          }),
          _buildCard(Icons.category, "المجموعات", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MainGroupsScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCard(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color.fromARGB(255, 198, 168, 130),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 50, color: const Color.fromARGB(255, 192, 145, 3)),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
