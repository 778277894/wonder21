// lib/admin/orders_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ====== Parsing helpers to run on isolate (optional performance) ======
class _OrdersPayload {
  final String body;
  _OrdersPayload(this.body);
}

class _ItemsPayload {
  final String body;
  _ItemsPayload(this.body);
}

Map<String, dynamic> _parseOrdersOnIsolate(_OrdersPayload p) {
  final j = jsonDecode(p.body);
  final total = (j['total_count'] is int)
      ? j['total_count'] as int
      : int.tryParse('${j['total_count'] ?? 0}') ?? 0;

  final List rowsRaw = (j['orders'] ?? const []);
  final rows = rowsRaw.map<Map<String, dynamic>>((e) {
    if (e is Map) {
      return e.map((k, v) => MapEntry('$k', v));
    }
    return <String, dynamic>{};
  }).toList();

  return {'total': total, 'rows': rows};
}

List<Map<String, dynamic>> _parseItemsOnIsolate(_ItemsPayload p) {
  final j = jsonDecode(p.body);
  final List raw = (j['items'] ?? const []);
  return raw.map<Map<String, dynamic>>((e) {
    if (e is Map) return e.cast<String, dynamic>();
    return <String, dynamic>{};
  }).toList();
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  // ===== إعداد السيرفر =====
  static const String serverIp = "192.168.0.16"; // بدّل حسب بيئتك
  String get baseUrl => "http://$serverIp";

  // ===== حالة عامة =====
  bool loading = true;
  bool loadingMore = false;
  String? error;
  String? lastErrorDetails; // لتفاصيل الخطأ

  // المستخدم الحالي (اقرأ من SharedPreferences في تطبيقك إن أردت)
  int? userId; // يمكن تمريره عبر prefs
  String userRole = 'admin'; // admin | accountant | user
  int? myBranchId;

  // الفلاتر
  String status = 'all';
  int? selectedBranchId;
  final TextEditingController _searchC = TextEditingController();

  // الترقيم
  int page = 1;
  final int limit = 20;
  int totalCount = 0;
  int get totalPages => (totalCount / limit).ceil().clamp(1, 999999);

  // البيانات
  List<Map<String, dynamic>> branches = [];
  final List<OrderRow> orders = [];

  // تمرير لا نهائي
  final ScrollController _sc = ScrollController();
  Timer? _debounce;

  Map<String, String> get _headers => const {'Accept': 'application/json'};

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _sc.addListener(_onScroll);
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // إن أردت: جلب userId/userRole/branchId من SharedPreferences
    // هنا سنضع قيمًا افتراضية للعرض
    userId = userId ?? 9; // مثال
    userRole = userRole; // كما تريد
    myBranchId = myBranchId; // كما تريد

    await _loadBranches();

    // المحاسب يرى فرعه فقط
    selectedBranchId = (userRole == 'accountant') ? myBranchId : null;

    await _refreshFirstPage();
  }

  Future<void> _loadBranches() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/get_branches.php"),
          headers: _headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          final List raw = j['branches'] ?? const [];
          branches = raw.map<Map<String, dynamic>>((e) {
            if (e is Map) return e.cast<String, dynamic>();
            return <String, dynamic>{};
          }).toList();
        }
      }
    } catch (_) {}
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await _refreshFirstPage();
    });
  }

  void _onScroll() {
    if (loadingMore || loading || error != null) return;
    if (_sc.position.pixels >= _sc.position.maxScrollExtent - 200) {
      if (page < totalPages) {
        _loadNextPage();
      }
    }
  }

  Future<void> _refreshFirstPage() async {
    setState(() {
      loading = true;
      error = null;
      lastErrorDetails = null;
      page = 1;
      totalCount = 0;
      orders.clear();
    });
    await _load();
    if (mounted) setState(() => loading = false);
  }

  Uri _ordersUri(int pageNum) {
    return Uri.parse("$baseUrl/get_orders.php").replace(queryParameters: {
      if (status != 'all') 'status': status,
      if (selectedBranchId != null) 'branch_id': '$selectedBranchId',
      if (userId != null) 'user_id': '$userId',
      if (_searchC.text.trim().isNotEmpty) 'q': _searchC.text.trim(),
      'page': '$pageNum',
      'limit': '$limit',
    });
  }

  Future<void> _load() async {
    try {
      final uri = _ordersUri(page);
      final started = DateTime.now();
      final res = await http.get(uri, headers: _headers);
      final took = DateTime.now().difference(started).inMilliseconds;

      if (res.statusCode != 200) {
        lastErrorDetails =
            "URL: $uri\nHTTP: ${res.statusCode}\nBody: ${res.body}\nms $took";
        throw Exception('HTTP ${res.statusCode}');
      }

      final parsed =
          await compute(_parseOrdersOnIsolate, _OrdersPayload(res.body));
      final int t = parsed['total'] as int;
      final List<Map<String, dynamic>> rows =
          parsed['rows'] as List<Map<String, dynamic>>;

      totalCount = t;
      final chunk = rows.map(OrderRow.fromJson).toList();
      orders.addAll(chunk);
    } catch (e, st) {
      error = 'خطأ غير متوقع أثناء الجلب';
      lastErrorDetails = [
        if (lastErrorDetails != null) lastErrorDetails,
        e.toString(),
        st.toString(),
      ].whereType<String>().join('\n\n');
    }
  }

  Future<void> _loadNextPage() async {
    if (page >= totalPages) return;
    setState(() => loadingMore = true);
    page += 1;
    try {
      await _load();
    } catch (e) {
      error ??= e.toString();
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<List<OrderItem>> _loadOrderItems(int orderId) async {
    final uri = Uri.parse("$baseUrl/get_order_details.php")
        .replace(queryParameters: {'order_id': '$orderId'});
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final list = await compute(_parseItemsOnIsolate, _ItemsPayload(res.body));
    return list.map(OrderItem.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canChooseBranch = userRole != 'accountant';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الطلبات'),
          backgroundColor: const Color(0xFFE6D64A),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh), onPressed: _refreshFirstPage),
          ],
        ),
        body: Column(
          children: [
            // البحث + الحالة
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _StatusFilter(
                      value: status,
                      onChanged: (v) {
                        status = v;
                        _refreshFirstPage();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchC,
                      decoration: const InputDecoration(
                        hintText: 'ابحث بالاسم أو الهاتف...',
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _refreshFirstPage(),
                    ),
                  ),
                ],
              ),
            ),
            // اختيار الفرع
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'الفرع',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: selectedBranchId,
                  underline: const SizedBox.shrink(),
                  items: [
                    if (canChooseBranch)
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('كل الفروع'),
                      ),
                    ...branches.map((b) => DropdownMenuItem<int?>(
                          value: toIntOrNull(b['id']),
                          child: Text('${b['name']}'),
                        )),
                  ],
                  onChanged: canChooseBranch
                      ? (v) {
                          selectedBranchId = v;
                          _refreshFirstPage();
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // القائمة
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshFirstPage,
                child: Builder(
                  builder: (_) {
                    if (loading && orders.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (error != null && orders.isEmpty) {
                      return _ErrorCard(
                        title: 'خطأ غير متوقع أثناء الجلب',
                        message: error!,
                        details: lastErrorDetails,
                        onRetry: _refreshFirstPage,
                      );
                    }
                    if (!loading && error == null && orders.isEmpty) {
                      return _EmptyState(onRefresh: _refreshFirstPage);
                    }

                    return ListView.builder(
                      controller: _sc,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      itemCount: orders.length + (loadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= orders.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final o = orders[i];
                        return _OrderTile(
                          order: o,
                          onTap: () async {
                            try {
                              final items = await _loadOrderItems(o.id);
                              if (!mounted) return;
                              showModalBottomSheet(
                                context: context,
                                showDragHandle: true,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                ),
                                builder: (_) =>
                                    _OrderDetailsSheet(order: o, items: items),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())));
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Utilities for safe parsing =====
int? toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

double toDoubleOrZero(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0.0;
}

// ===== Models =====
class OrderRow {
  final int id;
  final int? userId;
  final int? branchId;
  final String userName;
  final String phone;
  final String branchName;
  final double total;
  final String status;
  final DateTime date;

  OrderRow({
    required this.id,
    required this.userId,
    required this.branchId,
    required this.userName,
    required this.phone,
    required this.branchName,
    required this.total,
    required this.status,
    required this.date,
  });

  factory OrderRow.fromJson(Map<String, dynamic> j) {
    DateTime dt;
    try {
      dt = DateTime.parse('${j['order_date'] ?? j['date'] ?? ''}');
    } catch (_) {
      dt = DateTime.now();
    }

    return OrderRow(
      id: toIntOrNull(j['id'] ?? j['order_id']) ?? 0,
      userId: toIntOrNull(j['user_id']),
      branchId: toIntOrNull(j['branch_id']),
      userName: '${j['user_name'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      branchName: '${j['branch_name'] ?? ''}',
      total: toDoubleOrZero(j['total']),
      status: '${j['status'] ?? 'pending'}',
      date: dt,
    );
  }
}

class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double lineTotal;
  final String? imageUrl;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.lineTotal,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: toIntOrNull(j['id'] ?? j['item_id']) ?? 0,
        productId: toIntOrNull(j['product_id']) ?? 0,
        productName: '${j['product_name'] ?? j['name'] ?? ''}',
        quantity: toIntOrNull(j['quantity']) ?? 0,
        price: toDoubleOrZero(j['price']),
        lineTotal: toDoubleOrZero(j['line_total'] ??
            (toDoubleOrZero(j['price']) * (toIntOrNull(j['quantity']) ?? 0))),
        imageUrl: j['image_url']?.toString(),
      );
}

// ===== Widgets =====
class _StatusFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      {'k': 'all', 't': 'الكل'},
      {'k': 'pending', 't': 'قيد الانتظار'},
      {'k': 'paid', 't': 'مدفوع'},
      {'k': 'shipped', 't': 'تم الشحن'},
      {'k': 'completed', 't': 'مكتمل'},
      {'k': 'canceled', 't': 'ملغي'},
    ];
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'الحالة',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        underline: const SizedBox.shrink(),
        items: items
            .map((it) => DropdownMenuItem<String>(
                  value: it['k']!,
                  child: Text(it['t']!),
                ))
            .toList(),
        onChanged: (v) => onChanged(v ?? 'all'),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderRow order;
  final VoidCallback onTap;
  const _OrderTile({required this.order, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return const Color(0xFF00A6ED);
      case 'shipped':
        return const Color(0xFF7FB800);
      case 'completed':
        return const Color(0xFF3CB371);
      case 'canceled':
        return const Color(0xFFE55353);
      default:
        return const Color(0xFFE6C229);
    }
  }

  String _statusArabic(String s) {
    switch (s) {
      case 'pending':
        return 'قيد الانتظار';
      case 'paid':
        return 'مدفوع';
      case 'shipped':
        return 'تم الشحن';
      case 'completed':
        return 'مكتمل';
      case 'canceled':
        return 'ملغي';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = order.date.toLocal().toString().split(' ').first;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _statusColor(order.status).withOpacity(0.15),
          child: Icon(Icons.receipt_long, color: _statusColor(order.status)),
        ),
        title: Text(
            'طلب #${order.id} - ${order.userName.isEmpty ? order.phone : order.userName}'),
        subtitle: Text(
            'التاريخ: $d • الفرع: ${order.branchName.isNotEmpty ? order.branchName : (order.branchId ?? '-')} • الحالة: ${_statusArabic(order.status)}'),
        trailing: Text('${order.total.toStringAsFixed(2)} ر.س',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final OrderRow order;
  final List<OrderItem> items;
  const _OrderDetailsSheet({required this.order, required this.items});

  @override
  Widget build(BuildContext context) {
    final d = order.date.toLocal().toString().split(' ').first;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                width: 48,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(4)),
              ),
              Text('تفاصيل الطلب #${order.id}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                  'العميل: ${order.userName.isEmpty ? order.phone : order.userName}'),
              Text('التاريخ: $d  •  الحالة: ${order.status}'),
              if (order.branchName.isNotEmpty || order.branchId != null)
                Text(
                    'الفرع: ${order.branchName.isNotEmpty ? order.branchName : order.branchId}'),
              const Divider(height: 20),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return ListTile(
                      leading: it.imageUrl == null || it.imageUrl!.isEmpty
                          ? const Icon(Icons.shopping_bag)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                it.imageUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                      title: Text(it.productName),
                      subtitle: Text(
                          'الكمية: ${it.quantity} | السعر: ${it.price.toStringAsFixed(2)}'),
                      trailing: Text(it.lineTotal.toStringAsFixed(2)),
                    );
                  },
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('الإجمالي: ${order.total.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback onRetry;
  const _ErrorCard(
      {required this.title,
      required this.message,
      this.details,
      required this.onRetry});

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool showDetails = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 32),
          child: Card(
            color: Colors.red.withOpacity(0.06),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 36, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(widget.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(widget.message, textAlign: TextAlign.center),
                  if (widget.details != null &&
                      widget.details!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => showDetails = !showDetails),
                        icon: Icon(showDetails
                            ? Icons.expand_less
                            : Icons.expand_more),
                        label: Text(
                            showDetails ? 'إخفاء التفاصيل' : 'إظهار التفاصيل'),
                      ),
                    ),
                    if (showDetails)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: SelectableText(widget.details!,
                            style: const TextStyle(fontFamily: 'monospace')),
                      ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.inbox, size: 60, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('لا توجد طلبات حالياً'),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('تحديث'),
        ),
      ],
    );
  }
}
