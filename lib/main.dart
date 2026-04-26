// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wonderful2/account/my_account_screen.dart';
import 'package:wonderful2/client/main_groups_client_screen.dart';
import 'accounting/general_ledger_screen.dart';
import 'accounting/sales_invoice_screen.dart';
import 'accounting/purchase_invoice_screen.dart';
// -------------- Admin ----------------
import 'admin/admin_analytics.dart';
import 'admin/admin_dashboard.dart';
import 'admin/admin_products_management.dart';
import 'admin/admin_setting.dart';
import 'admin/admin_users_management.dart';
import 'admin/orders_screen.dart';
import 'admin/orders/order_details_screen.dart'; // ✅ أضفنا هذا السطر الجديد
import 'admin/excel_import_screen.dart';
// ---------------- Products / Client ----------------

import 'products/all_products_screen.dart';

import 'admin/orders/admin_orders_screen.dart';
// ---------------- Screens ----------------
import 'screen/forgotpassword_screen.dart';
import 'screen/home_screen.dart';
import 'screen/login_screen.dart';
import 'screen/profile_screen.dart';
import 'screen/signup_screen.dart';
import 'screen/splash_screen.dart';
import 'admin/orders/my_orders_screen.dart';
import 'admin/categories/categories_screen.dart';
import 'admin/group/main_groups_screen.dart';

// ---------------- Cart / Orders ----------------
import 'carts/cart.dart';
import 'carts/cart_screen.dart';
import 'admin/orders/order_success_screen.dart';

// ---------------- admin/categories ----------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await Cart.init();

  final prefs = await SharedPreferences.getInstance();
  final bool loggedIn = prefs.getBool('loggedIn') ?? false;
  final String userRole = prefs.getString('userRole') ?? 'user';
  final int? userId = prefs.getInt('userId') ?? prefs.getInt('user_id');

  final String initialRoute = !loggedIn
      ? '/login'
      : (userRole == 'admin' ? '/admin_dashboard' : '/home');

  runApp(MyApp(initialRoute: initialRoute, appUserId: userId));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final int? appUserId;
  const MyApp({super.key, required this.initialRoute, required this.appUserId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'روائع اليمن',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Tajawal',
      ),
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),

        '/profile_screen': (context) =>
            ProfileScreen(userId: (appUserId ?? 0).toString()),

        // ---------------- Admin ----------------
        '/admin_dashboard': (context) => const AdminDashboard(),
        '/admin_users_management': (context) => const AdminUsersManagement(),
        '/admin_products_management': (context) =>
            const AdminProductsManagement(),
        '/admin_setting': (context) => const AdminSetting(),
        '/admin_analytics': (context) => const AdminAnalytics(),
        '/orders_screen': (context) => const OrdersScreen(),
        '/categories_screen': (context) => const CategoriesScreen(),

        '/main_groups_clinet_screen': (context) =>
            const MainGroupsClientScreen(),

        // ✅ أضفنا هذا الراوت الجديد لصفحة تفاصيل الطلب
        '/order_details': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          final int orderId = int.tryParse('${args['order_id'] ?? 0}') ?? 0;
          return OrderDetailsScreen(orderId: orderId);
        },

        // ---------------- Products / Client ----------------

        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/main_groups_screen': (context) => const MainGroupsScreen(),
        '/my_orders_screen': (context) => const MyOrdersScreen(),

        '/account_screen': (context) => const AccountScreen(),
        '/admin_orders_screen': (context) => const AdminOrdersScreen(),
        '/general_ledger_screen': (context) => const GeneralLedgerScreen(),
        '/sales_invoice_screen': (context) => const SalesInvoiceScreen(),
        '/Purchase_Invoice_Screen': (context) => const PurchaseInvoiceScreen(),
        '/excel_import_screen': (context) => const ExcelImportScreen(),

        // ---------------- Cart / Orders ----------------
        '/cart': (context) => const CartScreen(),
        '/all_products_screen': (context) => const AllProductsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/order_success') {
          final Map<String, dynamic> args =
              (settings.arguments as Map?)?.cast<String, dynamic>() ?? {};
          final int orderId =
              int.tryParse('${args['orderId'] ?? args['order_id'] ?? 0}') ?? 0;
          final double total = double.tryParse('${args['total'] ?? 0}') ?? 0.0;
          final String? note = args['note']?.toString();
          final String? orderDate = args['orderDate']?.toString();

          return MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              orderId: orderId,
              total: total,
              note: note,
              orderDate: orderDate,
            ),
          );
        }
        return null;
      },
    );
  }
}
