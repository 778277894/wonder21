// lib/orders/my_orders_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'order_details_screen.dart';
import '../server_config.dart'; // يحتوي kServerIp مثل: http://192.168.0.16

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _searchC = TextEditingController();
  String _status = 'all';
  bool _loading = true;
  String? _error;
  int? _userId;

  List<_OrderRow> _orders = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ??
        prefs.getInt('user_id') ??
        int.tryParse(prefs.getString('id') ?? '');
    await _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_userId == null || _userId == 0) {
      setState(() {
        _loading = false;
        _error = 'يرجى تسجيل الدخول أولاً.';
        _orders = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri =
          Uri.parse('$kServerIp/get_orders.php').replace(queryParameters: {
        'user_id': '$_userId', // الخادم سيجلب طلبات هذا المستخدم فقط
        if (_status != 'all') 'status': _status,
        if (_searchC.text.trim().isNotEmpty) 'q': _searchC.text.trim(),
      });

      final res =
          await http.get(uri, headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }

      Map<String, dynamic> j;
      try {
        j = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        final preview = res.body.trim();
        throw FormatException(
          'استجابة غير صالحة من الخادم:\n${preview.substring(0, preview.length > 220 ? 220 : preview.length)}',
        );
      }

      if (j['success'] != true) {
        throw Exception(j['message'] ?? 'فشل جلب الطلبات');
      }

      final List list = j['orders'] ?? [];
      _orders = list
          .map((e) => _OrderRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _orders = [];
      });
    }
  }

  // ================= ميزة الطباعة والمعاينة المضافة =================
  void _printMyOrders() {
    final buffer = StringBuffer();
    buffer.writeln('تقرير طلباتي الشخصي:');
    buffer.writeln('-------------------------');
    for (final o in _orders) {
      buffer.writeln(
          'طلب #${o.id} | ${_statusAr(o.status)} | ${o.total.toStringAsFixed(2)} ر.س | فرع: ${o.branchName ?? o.branchId ?? '-'} | ${o.date}');
    }

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('معاينة طلباتي للطباعة'),
          content: SingleChildScrollView(
            child: SelectableText(buffer.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFE6C229);
      case 'paid':
        return const Color(0xFF00A6ED);
      case 'shipped':
        return const Color(0xFF7FB800);
      case 'completed':
        return const Color(0xFF3CB371);
      case 'canceled':
        return const Color(0xFFE55353);
      default:
        return Colors.grey;
    }
  }

  String _statusAr(String s) {
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE9B270),
          title: const Text('طلباتي'),
          actions: [
            // ✅ إضافة زر الطباعة هنا
            IconButton(
              tooltip: 'طباعة / معاينة',
              onPressed: _orders.isEmpty ? null : _printMyOrders,
              icon: const Icon(Icons.print),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatusFilter(
                      value: _status,
                      onChanged: (v) {
                        setState(() => _status = v);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchC,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'ابحث برقم الطلب...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ملخص بسيط للعميل
              if (_orders.isNotEmpty)
                Card(
                  color: Colors.blueGrey.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'إجمالي الطلبات: ${_orders.length} | المجموع: ${_orders.fold(0.0, (p, e) => p + e.total).toStringAsFixed(2)} ر.س',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _load)
              else if (_orders.isEmpty)
                const _EmptyState()
              else
                ..._orders.map((o) => Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailsScreen(orderId: o.id),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor:
                              _statusColor(o.status).withOpacity(0.15),
                          child: Icon(Icons.receipt_long,
                              color: _statusColor(o.status)),
                        ),
                        title: Text(
                          'طلب #${o.id} — ${o.branchName?.isNotEmpty == true ? o.branchName! : 'فرع ${o.branchId ?? '-'}'}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('التاريخ: ${o.date.split(' ').first}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(o.status)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _statusAr(o.status),
                                    style: TextStyle(
                                      color: _statusColor(o.status),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${o.total.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Models / Widgets ----------

class _OrderRow {
  final int id;
  final double total;
  final String status;
  final String date;
  final int? branchId;
  final String? branchName;

  _OrderRow({
    required this.id,
    required this.total,
    required this.status,
    required this.date,
    this.branchId,
    this.branchName,
  });

  factory _OrderRow.fromJson(Map<String, dynamic> j) => _OrderRow(
        id: int.tryParse('${j['order_id'] ?? j['id'] ?? 0}') ?? 0,
        total: double.tryParse('${j['total'] ?? 0}') ?? 0,
        status: '${j['status'] ?? 'pending'}',
        date: '${j['order_date'] ?? ''}',
        branchId:
            j['branch_id'] == null ? null : int.tryParse('${j['branch_id']}'),
        branchName: j['branch']?.toString() ?? j['branch_name']?.toString(),
      );
}

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
                value: it['k']!, child: Text(it['t']!)))
            .toList(),
        onChanged: (v) => onChanged(v ?? 'all'),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.red),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 30),
        Icon(Icons.inbox, size: 64, color: Colors.grey),
        SizedBox(height: 10),
        Text('لا توجد طلبات حتى الآن'),
        SizedBox(height: 12),
      ],
    );
  }
}
