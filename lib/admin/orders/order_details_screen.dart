// lib/orders/order_details_screen.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// الطباعة
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// لتحميل الخط من الأصول
import 'package:flutter/services.dart' show rootBundle;

import '../server_config.dart'; // تحتوي kServerIp مثل: const kServerIp = "http://192.168.0.16";

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _loading = true;
  String? _error;

  OrderHeader? _order;
  List<OrderItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$kServerIp/get_order_details.php')
          .replace(queryParameters: {'order_id': '${widget.orderId}'});

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
        throw Exception(j['message'] ?? 'فشل جلب تفاصيل الطلب');
      }

      _order = OrderHeader.fromJson(
          Map<String, dynamic>.from(j['order'] as Map<String, dynamic>));

      final List list = j['items'] ?? [];
      _items = list
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _order = null;
        _items = [];
      });
    }
  }

  // ---------- ألوان + ترجمة حالة الطلب ----------

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

  // ========= ميزة الطباعة الفنية المضافة للعميل (PDF) =========

  Future<void> _printOrder() async {
    if (_order == null) return;
    final o = _order!;
    final items = _items;

    // 1) تحميل خط Amiri من الأصول (تأكد من وجود المسار في pubspec.yaml)
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final amiri = pw.Font.ttf(fontData);

    final theme =
        pw.ThemeData.withFont(base: amiri, bold: amiri, italic: amiri);

    // 2) تجهيز بيانات الترويسة
    final String companyAr = o.companyNameAr?.isNotEmpty == true
        ? o.companyNameAr!
        : 'روائع اليمن للألمنيوم';
    final String companyEn = o.companyNameEn ?? '';

    Uint8List? logoBytes;
    try {
      final rawLogo = o.branchLogoUrl ?? '';
      if (rawLogo.isNotEmpty) {
        final url =
            rawLogo.startsWith('http') ? rawLogo : '$kServerIp/$rawLogo';
        final r = await http.get(Uri.parse(url));
        if (r.statusCode == 200) logoBytes = r.bodyBytes;
      }
    } catch (_) {}

    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5)),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                children: [
                  // رأس الفاتورة
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1.2))),
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                            crossAxisAlignment:
                                pw.TextDirection.ltr == pw.TextDirection.rtl
                                    ? pw.CrossAxisAlignment.end
                                    : pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(companyEn,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10)),
                              pw.Text(o.branchNameEn ?? '',
                                  style: const pw.TextStyle(fontSize: 9)),
                            ]),
                        if (logoBytes != null)
                          pw.Image(pw.MemoryImage(logoBytes),
                              width: 80, height: 80)
                        else
                          pw.SizedBox(
                              width: 80,
                              child: pw.Center(child: pw.Text('LOGO'))),
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(companyAr,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 12)),
                              pw.Text(o.branchName ?? '',
                                  style: const pw.TextStyle(fontSize: 9)),
                            ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Center(
                      child: pw.Text('فاتورة مبيعات',
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold))),
                  pw.Divider(),
                  // بيانات الفاتورة
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('رقم الفاتورة: ${o.id}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('التاريخ: ${o.date}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('العميل: ${o.userName}',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  // الجدول
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey300),
                          children: [
                            _pdfCell('رقم الصنف', isHeader: true),
                            _pdfCell('اسم الصنف', isHeader: true),
                            _pdfCell('الكمية', isHeader: true),
                            _pdfCell('السعر', isHeader: true),
                            _pdfCell('الإجمالي', isHeader: true),
                          ]),
                      ...items.map((it) => pw.TableRow(children: [
                            _pdfCell(it.productId.toString()),
                            _pdfCell(it.name),
                            _pdfCell(it.qty.toString()),
                            _pdfCell(it.price.toStringAsFixed(2)),
                            _pdfCell(it.lineTotal.toStringAsFixed(2)),
                          ])),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                            'الإجمالي النهائي: ${o.total.toStringAsFixed(2)} ر.س',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: isHeader ? pw.FontWeight.bold : null))),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _ErrorCard(message: _error!, onRetry: _load);
    } else if (_order == null) {
      body = const Center(child: Text('الطلب غير موجود.'));
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              const Center(child: Text('لا توجد أصناف في هذا الطلب'))
            else
              ..._items.map(_buildItemTile),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE9B270),
          title: Text('تفاصيل الطلب #${widget.orderId}'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'طباعة الفاتورة',
              onPressed: _order == null ? null : _printOrder,
              icon: const Icon(Icons.print),
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  // --------- UI helpers ---------

  Widget _buildHeaderCard() {
    final o = _order!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العميل: ${o.userName}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('الجوال: ${o.phone.isEmpty ? '-' : o.phone}'),
            const SizedBox(height: 4),
            Text('التاريخ: ${o.date}'),
            const SizedBox(height: 4),
            Text(
                'الفرع: ${o.branchName?.isNotEmpty == true ? o.branchName! : (o.branchId == null ? "-" : "فرع ${o.branchId}")}'),
            const SizedBox(height: 8),
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
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text('الإجمالي: ${o.total.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            if (o.note != null && o.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              Text('ملاحظات:', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 4),
              Text(o.note!, style: const TextStyle(height: 1.3)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(OrderItem item) {
    final img = item.imageUrl.trim();
    Widget leading;
    if (img.isEmpty) {
      leading = const CircleAvatar(child: Icon(Icons.image_not_supported));
    } else {
      final url = img.startsWith('http') ? img : '$kServerIp/$img';
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 32)),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: leading,
        title: Text(item.name.isEmpty ? 'منتج #${item.productId}' : item.name),
        subtitle: Text(
            'الكمية: ${item.qty} • السعر: ${item.price.toStringAsFixed(2)} ر.س'),
        trailing: Text(item.lineTotal.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --------- Models ---------

class OrderHeader {
  final int id;
  final int userId;
  final String userName;
  final String phone;
  final double total;
  final String status;
  final String date;
  final int? branchId;
  final String? branchName;
  final String? note;

  // حقول الفرع المضافة للطباعة
  final String? companyNameAr;
  final String? companyNameEn;
  final String? branchNameEn;
  final String? branchLogoUrl;

  OrderHeader({
    required this.id,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.total,
    required this.status,
    required this.date,
    this.branchId,
    this.branchName,
    this.note,
    this.companyNameAr,
    this.companyNameEn,
    this.branchNameEn,
    this.branchLogoUrl,
  });

  factory OrderHeader.fromJson(Map<String, dynamic> j) => OrderHeader(
        id: int.tryParse('${j['order_id'] ?? j['id'] ?? 0}') ?? 0,
        userId: int.tryParse('${j['user_id'] ?? 0}') ?? 0,
        userName: '${j['user_name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        total: double.tryParse('${j['total'] ?? 0}') ?? 0,
        status: '${j['status'] ?? 'pending'}',
        date: '${j['order_date'] ?? ''}',
        branchId:
            j['branch_id'] == null ? null : int.tryParse('${j['branch_id']}'),
        branchName: j['branch_name']?.toString(),
        note: j['note']?.toString(),
        companyNameAr: j['company_name_ar']?.toString(),
        companyNameEn: j['company_name_en']?.toString(),
        branchNameEn: j['branch_name_en']?.toString(),
        branchLogoUrl: j['branch_logo_url']?.toString(),
      );
}

class OrderItem {
  final int productId;
  final String name;
  final int qty;
  final double price;
  final double lineTotal;
  final String imageUrl;

  OrderItem(
      {required this.productId,
      required this.name,
      required this.qty,
      required this.price,
      required this.lineTotal,
      required this.imageUrl});

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        productId: int.tryParse('${j['product_id'] ?? 0}') ?? 0,
        name: '${j['product_name'] ?? j['name'] ?? ''}',
        qty: int.tryParse('${j['quantity'] ?? 0}') ?? 0,
        price: double.tryParse('${j['price'] ?? 0}') ?? 0,
        lineTotal: double.tryParse('${j['line_total'] ?? 0}') ?? 0,
        imageUrl: '${j['image_url'] ?? ''}',
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.red.withOpacity(0.06),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                SelectableText(message, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
