// lib/admin/orders/admin_orders_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wonderful2/admin/orders/admin_order_details_screen.dart';

import './../server_config.dart'; // تأكد من المسار الصحيح
import '../orders/order_details_screen.dart'; // شاشة تفاصيل الطلب (العميل/المدير) عدّل المسار حسب مشروعك

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  // بحث برقم الطلب
  final TextEditingController _searchC = TextEditingController();

  // حالة الطلب
  String _status = 'all';

  // فلترة بالتاريخ
  DateTime? _fromDate;
  DateTime? _toDate;

  // فلترة بالفرع
  int? _branchIdFilter; // null = كل الفروع

  // حالة التحميل
  bool _loading = true;
  String? _error;

  // الطلبات القادمة من السيرفر
  List<_AdminOrderRow> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // ================== API ==================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final qp = <String, String>{};

      if (_status != 'all') qp['status'] = _status;

      if (_searchC.text.trim().isNotEmpty) {
        qp['q'] = _searchC.text.trim();
      }

      if (_fromDate != null) {
        qp['from_date'] = _fmtDate(_fromDate!);
      }
      if (_toDate != null) {
        qp['to_date'] = _fmtDate(_toDate!);
      }

      if (_branchIdFilter != null) {
        qp['branch_id'] = '$_branchIdFilter';
      }

      final uri = Uri.parse('$kServerIp/get_orders_admin.php')
          .replace(queryParameters: qp.isEmpty ? null : qp);

      final res =
          await http.get(uri, headers: const {'Accept': 'application/json'});

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }

      Map<String, dynamic> j;
      try {
        j = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        final body = res.body.trim();
        throw FormatException(
          'استجابة غير صالحة من الخادم:\n'
          '${body.substring(0, body.length > 220 ? 220 : body.length)}',
        );
      }

      if (j['success'] != true) {
        throw Exception(j['message'] ?? 'فشل جلب الطلبات');
      }

      final List list = j['orders'] ?? [];
      _orders = list
          .map((e) => _AdminOrderRow.fromJson(Map<String, dynamic>.from(e)))
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

  Future<void> _updateStatus(_AdminOrderRow order, String newStatus) async {
    try {
      final res = await http.post(
        Uri.parse('$kServerIp/update_order_status.php'),
        body: {
          'order_id': order.id.toString(),
          'status': newStatus,
        },
      );

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }

      final j = jsonDecode(res.body);
      final ok = j['success'] == true;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(j['message']?.toString() ??
              (ok ? 'تم تحديث الحالة بنجاح' : 'فشل تحديث الحالة')),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );

      if (ok) {
        // إعادة التحميل لتحديث القائمة
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء تحديث الحالة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================== Helpers ==================

  String _fmtDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final init = _fromDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _load();
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final init = _toDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _load();
    }
  }

  void _clearDates() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _load();
  }

  void _printOrders() {
    // طباعة بسيطة كنص – يمكنك لاحقًا ربطها بـ pdf أو مكتبة printing
    final buffer = StringBuffer();
    buffer.writeln('تقرير الطلبات:');
    buffer.writeln('-------------------------');
    for (final o in _filteredOrders) {
      buffer.writeln(
          'طلب #${o.id} | ${_statusAr(o.status)} | ${o.total.toStringAsFixed(2)} | فرع: ${o.branchName ?? o.branchId ?? '-'} | ${o.date}');
    }

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('معاينة للطباعة'),
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

  // قائمة الفروع المتاحة في الطلبات الحالية
  List<_BranchOption> get _branchOptions {
    final map = <int, String>{};
    for (final o in _orders) {
      if (o.branchId != null) {
        map[o.branchId!] = o.branchName?.toString().trim().isNotEmpty == true
            ? o.branchName!
            : 'فرع ${o.branchId}';
      }
    }
    final list = map.entries
        .map((e) => _BranchOption(id: e.key, name: e.value))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<_AdminOrderRow> get _filteredOrders {
    return _orders.where((o) {
      if (_branchIdFilter != null && o.branchId != _branchIdFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  double get _sumTotal {
    return _filteredOrders.fold(
        0.0, (p, e) => p + (e.total.isNaN ? 0.0 : e.total));
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // الصف الأول: حالة + بحث
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

          const SizedBox(height: 8),

          // صف فلترة الفروع
          if (_branchOptions.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'الفرع',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      value: _branchIdFilter,
                      hint: const Text('كل الفروع'),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('كل الفروع')),
                        ..._branchOptions.map(
                          (b) => DropdownMenuItem<int?>(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _branchIdFilter = v);
                      },
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 8),

          // صف التاريخ من/إلى + زر مسح
          Row(
            children: [
              IconButton(
                tooltip: 'مسح التاريخ',
                onPressed:
                    (_fromDate == null && _toDate == null) ? null : _clearDates,
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _DateChip(
                  label:
                      'من: ${_fromDate == null ? 'اختر تاريخاً' : _fmtDate(_fromDate!)}',
                  icon: Icons.calendar_today,
                  onTap: _pickFromDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateChip(
                  label:
                      'إلى: ${_toDate == null ? "اختر تاريخاً" : _fmtDate(_toDate!)}',
                  icon: Icons.calendar_today,
                  onTap: _pickToDate,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ملخص
          _SummaryCard(
            count: _filteredOrders.length,
            total: _sumTotal,
          ),

          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_filteredOrders.isEmpty)
            const _EmptyState()
          else
            ..._filteredOrders.map(_buildOrderTile),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE9B270),
          title: const Text('إدارة الطلبات (مدير)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              tooltip: 'طباعة / معاينة',
              onPressed: _filteredOrders.isEmpty ? null : _printOrders,
              icon: const Icon(Icons.print),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  // عنصر الطلب في القائمة مع قائمة تغيير الحالة
  Widget _buildOrderTile(_AdminOrderRow o) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () {
          // فتح تفاصيل الطلب
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminOrderDetailsScreen(orderId: o.id),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: _statusColor(o.status).withOpacity(0.15),
          child: Icon(Icons.receipt_long, color: _statusColor(o.status)),
        ),
        title: Text(
          'طلب #${o.id} — ${o.branchName?.isNotEmpty == true ? o.branchName! : (o.branchId == null ? "بدون فرع" : "فرع ${o.branchId}")}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العميل: ${o.userName.isEmpty ? "غير معروف" : o.userName}'),
            Text('التاريخ: ${o.date.split(' ').first}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(o.status).withOpacity(0.15),
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              o.total.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            PopupMenuButton<String>(
              tooltip: 'خيارات',
              onSelected: (value) {
                if (value == 'details') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminOrderDetailsScreen(orderId: o.id),
                    ),
                  );
                } else {
                  _updateStatus(o, value);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Text('عرض التفاصيل'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'pending', child: Text('تعيين: قيد الانتظار')),
                const PopupMenuItem(value: 'paid', child: Text('تعيين: مدفوع')),
                const PopupMenuItem(
                    value: 'shipped', child: Text('تعيين: تم الشحن')),
                const PopupMenuItem(
                    value: 'completed', child: Text('تعيين: مكتمل')),
                const PopupMenuItem(
                    value: 'canceled', child: Text('تعيين: ملغي')),
              ],
              child: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== Models & small widgets ==================

class _AdminOrderRow {
  final int id;
  final int userId;
  final String userName;
  final double total;
  final String status;
  final String date;
  final int? branchId;
  final String? branchName;

  _AdminOrderRow({
    required this.id,
    required this.userId,
    required this.userName,
    required this.total,
    required this.status,
    required this.date,
    this.branchId,
    this.branchName,
  });

  factory _AdminOrderRow.fromJson(Map<String, dynamic> j) => _AdminOrderRow(
        id: int.tryParse('${j['order_id'] ?? j['id'] ?? 0}') ?? 0,
        userId: int.tryParse('${j['user_id'] ?? 0}') ?? 0,
        userName: '${j['user_name'] ?? j['username'] ?? ''}',
        total: double.tryParse('${j['total'] ?? 0}') ?? 0,
        status: '${j['status'] ?? 'pending'}',
        date: '${j['order_date'] ?? ''}',
        branchId:
            j['branch_id'] == null ? null : int.tryParse('${j['branch_id']}'),
        branchName: j['branch_name']?.toString(),
      );
}

class _BranchOption {
  final int id;
  final String name;
  _BranchOption({required this.id, required this.name});
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
                  value: it['k']!,
                  child: Text(it['t']!),
                ))
            .toList(),
        onChanged: (v) => onChanged(v ?? 'all'),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DateChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int count;
  final double total;

  const _SummaryCard({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'ملخص الطلبات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('عدد الطلبات: $count'),
                const SizedBox(height: 4),
                Text('إجمالي المبالغ: ${total.toStringAsFixed(2)} ر.س'),
              ],
            ),
          ],
        ),
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
        Text('لا توجد طلبات في الفترة الحالية'),
        SizedBox(height: 12),
      ],
    );
  }
}
