import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // ✅ لإطلاق الروابط الخارجية
import 'package:shared_preferences/shared_preferences.dart'; // ✅ لجلب userId من الجوال

import '../carts/cart_models.dart';
import '../carts/cart_screen.dart';

import '../admin/server_config.dart'; // يحتوي kServerIp = "http://192.168.0.16" مثلاً

String fixImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path; // إذا كان الرابط كاملاً لا نغيره

  // تنظيف المسار وتحويل الـ Backslashes إلى Forward Slashes
  String cleanPath = path.replaceAll('\\', '/');

  // إزالة السلاش من البداية إذا وجد لتجنب التكرار //
  if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);

  // التأكد من وجود مجلد uploads في المسار
  if (!cleanPath.contains('uploads/')) {
    cleanPath = 'uploads/$cleanPath';
  }

  // دمجها مع رابط السيرفر الأساسي
  String base = kServerIp.endsWith('/') ? kServerIp : '$kServerIp/';
  return Uri.encodeFull("$base$cleanPath");
}
// ==================== الإعلانات أسفل الصفحة ====================

class AdItem {
  final int id;
  final String title;
  final String imageUrl;
  final String
      linkType; // url | product (أو product_id حسب ما في قاعدة بياناتك)
  final String targetUrl;
  final int? productId;
  final bool active;

  AdItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkType,
    required this.targetUrl,
    required this.productId,
    required this.active,
  });

  factory AdItem.fromMap(Map<String, dynamic> m) {
    int _asInt(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
    return AdItem(
      id: _asInt(m['ad_id'] ?? m['id']),
      title: (m['title'] ?? '').toString(),
      imageUrl: (m['image_url'] ?? m['imageRelative'] ?? '').toString(),
      linkType: (m['link_type'] ?? 'url').toString(),
      targetUrl: (m['target_url'] ?? '').toString(),
      productId: (m['product_id']?.toString().isNotEmpty ?? false)
          ? int.tryParse('${m['product_id']}')
          : null,
      active: (m['active'] ?? 1).toString() == '1',
    );
  }
}

class BottomAdsBar extends StatefulWidget {
  const BottomAdsBar({super.key, this.onRefreshed});
  final VoidCallback? onRefreshed;

  @override
  State<BottomAdsBar> createState() => _BottomAdsBarState();
}

class _BottomAdsBarState extends State<BottomAdsBar> {
  bool loading = true;
  String? error;
  List<AdItem> ads = [];

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await http.get(Uri.parse("$kServerIp/get_ads.php"));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final j = jsonDecode(r.body);
      if (j['success'] != true) {
        throw Exception(j['message'] ?? 'فشل جلب الإعلانات');
      }
      final List list = j['ads'] ?? [];
      final all = list.map((e) => AdItem.fromMap(e)).toList();
      ads = all.where((a) => a.active).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => loading = false);
      widget.onRefreshed?.call();
    }
  }

  /// ✅ عند الضغط على الإعلان
  void _onAdTap(AdItem ad) async {
    // لو كان الإعلان مرتبط بمنتج
    if (ad.linkType == 'product_id' && (ad.productId ?? 0) > 0) {
      Navigator.pushNamed(
        context,
        '/product_details_screen',
        arguments: {'product_id': ad.productId},
      );
      return;
    }

    // لو كان من نوع رابط
    if (ad.linkType == 'url' && ad.targetUrl.isNotEmpty) {
      String url = ad.targetUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الرابط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'خطأ في الإعلانات: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    if (ads.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: TextButton.icon(
            onPressed: _fetchAds,
            icon: const Icon(Icons.refresh),
            label: const Text('لا توجد إعلانات — تحديث'),
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.campaign, size: 18),
                const SizedBox(width: 6),
                const Text('إعلانات'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.teal),
                  tooltip: 'تحديث الإعلانات',
                  onPressed: _fetchAds,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: ads.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final ad = ads[i];
                final img = fixImageUrl(ad.imageUrl);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _onAdTap(ad),
                  child: Ink(
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: const Color.fromARGB(255, 20, 20, 20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: img.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  ad.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    ad.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 1),
        ],
      ),
    );
  }
}

// ==================== شريط المحفظة أعلى الصفحة ====================

class WalletEntry {
  final String code; // YER / SAR / USD
  final String name; // ريال يمني / ريال سعودي / دولار
  final double balance;

  WalletEntry({
    required this.code,
    required this.name,
    required this.balance,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> j) {
    return WalletEntry(
      code: '${j['currency_code'] ?? ''}',
      name: '${j['currency_name'] ?? j['name'] ?? ''}',
      balance: double.tryParse('${j['balance'] ?? 0}') ?? 0,
    );
  }
}

class WalletBar extends StatefulWidget {
  const WalletBar({super.key});

  @override
  State<WalletBar> createState() => _WalletBarState();
}

class _WalletBarState extends State<WalletBar> {
  bool _loading = false;
  String? _error;
  bool _obscure = true; // إخفاء/إظهار الرصيد
  List<WalletEntry> _wallet = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
      _wallet = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ??
          prefs.getInt('user_id'); // مثل ما نستخدمه في طلباتي

      if (userId == null || userId == 0) {
        // المستخدم زائر
        setState(() {
          _loading = false;
          _error = 'أنت حالياً تستخدم التطبيق كزائر. سجّل الدخول لعرض رصيدك.';
        });
        return;
      }

      final uri = Uri.parse('$kServerIp/get_user_wallets.php')
          .replace(queryParameters: {'user_id': '$userId'});

      final res =
          await http.get(uri, headers: const {'Accept': 'application/json'});

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }

      final Map<String, dynamic> j = jsonDecode(res.body);

      if (j['success'] != true) {
        throw Exception(j['message'] ?? 'فشل جلب رصيد المحفظة');
      }

      final List list = j['balances'] ?? [];
      _wallet = list
          .map((e) => WalletEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _wallet = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Card(
          child: SizedBox(
            height: 70,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Card(
          color: Colors.red.withOpacity(.04),
          child: ListTile(
            leading:
                const Icon(Icons.account_balance_wallet, color: Colors.red),
            title: const Text('المحفظة'),
            subtitle: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadWallet,
            ),
          ),
        ),
      );
    }

    if (_wallet.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Card(
          child: ListTile(
            leading:
                const Icon(Icons.account_balance_wallet, color: Colors.orange),
            title: const Text('المحفظة'),
            subtitle: const Text('لا يوجد رصيد حالياً.'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadWallet,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Color(0xFFFF9800)),
                  const SizedBox(width: 6),
                  const Text(
                    'محفظتي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    tooltip: _obscure ? 'إظهار الرصيد' : 'إخفاء الرصيد',
                    onPressed: () {
                      setState(() => _obscure = !_obscure);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 50,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.95),
                  itemCount: _wallet.length,
                  itemBuilder: (context, index) {
                    final w = _wallet[index];
                    final amount =
                        _obscure ? '••••••' : w.balance.toStringAsFixed(2);
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              w.name.isNotEmpty ? w.name : w.code,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            amount,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            w.code,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== عرض صورة الفرع حسب المستخدم ====================

class BranchItem {
  final int id;
  final String name;
  final String imageUrl;
  final bool active;

  BranchItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.active,
  });

  factory BranchItem.fromJson(Map<String, dynamic> j) {
    // نقوم بجلب النص الخام للصورة أولاً
    String rawPath =
        '${j['image_url'] ?? j['branch_image'] ?? j['image'] ?? ''}';

    return BranchItem(
      id: int.tryParse('${j['branch_id'] ?? j['id'] ?? 0}') ?? 0,
      name: '${j['branch_name'] ?? j['name'] ?? ''}',
      // هنا نستخدم دالة الإصلاح لضمان تحويل المسار إلى رابط كامل
      imageUrl: fixImageUrl(rawPath),
      active: (j['active'] ?? 1).toString() == '1',
    );
  }
}

class BranchHeader extends StatefulWidget {
  const BranchHeader({super.key});

  @override
  State<BranchHeader> createState() => _BranchHeaderState();
}

class _BranchHeaderState extends State<BranchHeader> {
  bool _loading = true;
  String? _error;
  List<BranchItem> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loading = true;
      _error = null;
      _branches = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ??
          prefs.getInt('user_id') ??
          0; // من تسجيل الدخول

      if (userId == 0) {
        // زائر -> لا نعرض فرع محدد
        setState(() {
          _loading = false;
          _error = 'تستخدم التطبيق كزائر. سجّل الدخول لعرض فرعك.';
        });
        return;
      }

      final uri = Uri.parse('$kServerIp/get_branches.php').replace(
        queryParameters: {
          'user_id': '$userId',
          'active_only': '1',
        },
      );

      final res =
          await http.get(uri, headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }

      final Map<String, dynamic> j = jsonDecode(res.body);
      if (j['success'] != true) {
        throw Exception(j['message'] ?? 'فشل جلب الفروع');
      }

      final List list = j['branches'] ?? [];
      _branches = list
          .map((e) => BranchItem.fromJson(Map<String, dynamic>.from(e)))
          .where((b) => b.id != 0)
          .toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _branches = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // لو حابب تخفي الكرت نهائياً للزوار، تقدر ترجع SizedBox.shrink في حالة _error فيها نص الزائر
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
        child: Card(
          child: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
        child: Card(
          color: Colors.blueGrey.withOpacity(0.03),
          child: ListTile(
            leading: const Icon(Icons.store_mall_directory,
                color: Color.fromARGB(255, 134, 88, 19)),
            title: const Text('فرعي'),
            subtitle: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBranches,
            ),
          ),
        ),
      );
    }

    if (_branches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
        child: Card(
          child: ListTile(
            leading:
                const Icon(Icons.store_mall_directory, color: Colors.orange),
            title: const Text('فرعي'),
            subtitle: const Text('لا يوجد فرع محدد لهذا المستخدم.'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBranches,
            ),
          ),
        ),
      );
    }

    // لو مدير أو عنده أكثر من فرع: نعرض سوايب بين الفروع
    if (_branches.length > 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
        child: Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.store_mall_directory, color: Color(0xFFFF9800)),
                    SizedBox(width: 6),
                    Text(
                      'فروعي',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 110,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.9),
                    itemCount: _branches.length,
                    itemBuilder: (_, i) {
                      final b = _branches[i];
                      final img = fixImageUrl(b.imageUrl);
                      return Container(
                        margin: const EdgeInsets.only(left: 6, right: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color.fromARGB(255, 195, 126, 126),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(12)),
                              child: img.isEmpty
                                  ? Container(
                                      width: 90,
                                      height: 110,
                                      color: const Color.fromARGB(
                                          255, 204, 126, 126),
                                      child: const Icon(Icons.store,
                                          size: 40,
                                          color:
                                              Color.fromARGB(255, 225, 84, 84)),
                                    )
                                  : Image.network(
                                      img,
                                      width: 90,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 90,
                                        height: 110,
                                        color: const Color.fromARGB(
                                            255, 211, 105, 105),
                                        child: const Icon(Icons.broken_image,
                                            size: 32),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // حالة فرع واحد فقط (مستخدم عادي أو محاسب)
    final b = _branches.first;
    final img = fixImageUrl(b.imageUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          height: 110,
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(14)),
                child: img.isEmpty
                    ? Container(
                        width: 110,
                        height: 110,
                        color: const Color.fromARGB(255, 211, 150, 59),
                        child: const Icon(Icons.store,
                            size: 40, color: Color.fromARGB(255, 239, 173, 60)),
                      )
                    : Image.network(
                        img,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 110,
                          height: 110,
                          color: const Color.fromARGB(255, 206, 148, 66),
                          child: const Icon(Icons.broken_image,
                              size: 32,
                              color: Color.fromARGB(255, 226, 122, 58)),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== الصفحة الرئيسية ====================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool reloading = false;

  void _refreshPage() {
    setState(() => reloading = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => reloading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مرحباً بك في تطبيق روائع اليمن للألمنيوم'),
        backgroundColor: const Color.fromARGB(255, 210, 156, 7),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الصفحة',
            onPressed: _refreshPage,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, size: 28),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                ),
                ValueListenableBuilder<int>(
                  valueListenable: Cart.count,
                  builder: (_, count, __) {
                    if (count <= 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 6, right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: reloading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const WalletBar(), // ✅ شريط المحفظة في أعلى الصفحة
                  const SizedBox(height: 6),
                  const BranchHeader(), // ✅ صورة الفرع حسب المستخدم
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SectionCard(
                      title: 'منتجاتنا',
                      icon: Icons.category,
                      route: '/all_products_screen'),
                  const SectionCard(
                      title: 'طلباتي',
                      icon: Icons.inventory,
                      route: '/my_orders_screen'),
                  const SectionCard(
                      title: 'حسابي',
                      icon: Icons.person,
                      route: '/profile_screen'),
                  const SectionCard(
                      title: 'مجموعاتي',
                      icon: Icons.auto_graph_outlined,
                      route: '/main_groups_clinet_screen'),
                  const SizedBox(height: 20),
                  const BottomAdsBar(), // ✅ إعلانات من القاعدة مع زر تحديث
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? route;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFF9800)),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (route != null) {
            Navigator.pushNamed(context, route!);
          }
        },
      ),
    );
  }
}
