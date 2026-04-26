// lib/admin/orders/admin_order_details_screen.dart
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

import '../server_config.dart'; // فيها kServerIp مثل: const kServerIp = "http://192.168.0.16";

class AdminOrderDetailsScreen extends StatefulWidget {
  final int orderId;
  final bool canEditStatus;

  const AdminOrderDetailsScreen({
    super.key,
    required this.orderId,
    this.canEditStatus = true,
  });

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
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

  // ---------- تغيير حالة الطلب من الشاشة ----------

  Future<void> _changeStatus(String newStatus) async {
    if (_order == null) return;
    final old = _order!;
    setState(() {
      _order = old.copyWith(status: newStatus);
    });

    try {
      final res = await http.post(
        Uri.parse('$kServerIp/update_order_status.php'),
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'order_id': old.id.toString(),
          'status': newStatus,
        },
      );

      Map<String, dynamic> j;
      try {
        j = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        j = {};
      }

      final ok = j['success'] == true;

      if (!ok) {
        setState(() {
          _order = old;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            j['message'] ??
                (ok ? 'تم تحديث حالة الطلب بنجاح' : 'فشل تحديث الحالة'),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _order = old;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التحديث: $e')),
      );
    }
  }

  // ========= الطباعة كـ PDF (مع خط أميري + بيانات الفرع من جدول branches) =========

  Future<void> _printOrder() async {
    if (_order == null) return;
    final o = _order!;
    final items = _items;

    // 1) تحميل خط Amiri من الأصول
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final amiri = pw.Font.ttf(fontData);

    // 2) إنشاء Theme يستعمل الخط العربي
    final theme = pw.ThemeData.withFont(
      base: amiri,
      bold: amiri,
      italic: amiri,
    );

    // 3) تجهيز بيانات رأس الفاتورة من جدول الفروع
    final String companyNameAr = (o.companyNameAr?.trim().isNotEmpty ?? false)
        ? o.companyNameAr!.trim()
        : 'روائع اليمن للألمنيوم';

    final String companyNameEn = (o.companyNameEn ?? '').trim();
    final String branchTitleAr = (o.branchName ?? '').trim();
    final String branchTitleEn = (o.branchNameEn ?? '').trim();

    String address = (o.branchAddress ?? '').trim();
    String phone1 = (o.branchPhone ?? '').trim();
    String phone2 = (o.branchMobile ?? '').trim();
    String whatsapp = (o.branchWhatsapp ?? '').trim();

    // 4) تحميل الشعار من حقل image_url في branches (branchLogoUrl)
    Uint8List? logoBytes;
    try {
      final raw = (o.branchLogoUrl ?? '').trim();
      if (raw.isNotEmpty) {
        final url = raw.startsWith('http') ? raw : '$kServerIp/$raw';
        final r = await http.get(Uri.parse(url));
        if (r.statusCode == 200) {
          logoBytes = r.bodyBytes;
        }
      }
    } catch (_) {
      logoBytes = null;
    }

    // 5) إنشاء المستند
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
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // --------- رأس الفاتورة مثل الصورة (إنجليزي يسار - شعار وسط - عربي يمين) ----------
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.black, width: 1.2),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // يسار (إنجليزي)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (companyNameEn.isNotEmpty)
                              pw.Text(
                                companyNameEn,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            if (branchTitleEn.isNotEmpty)
                              pw.Text(
                                branchTitleEn,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            if (address.isNotEmpty)
                              pw.Text(
                                address,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            if (phone1.isNotEmpty || phone2.isNotEmpty)
                              pw.Text(
                                'Tel: ${[
                                  if (phone1.isNotEmpty) phone1,
                                  if (phone2.isNotEmpty) phone2,
                                ].join(' - ')}',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                          ],
                        ),

                        // الشعار في المنتصف
                        pw.Container(
                          width: 100,
                          height: 100,
                          alignment: pw.Alignment.center,
                          child: logoBytes == null
                              ? pw.Text(
                                  'LOGO',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                )
                              : pw.Image(
                                  pw.MemoryImage(logoBytes),
                                  fit: pw.BoxFit.contain,
                                ),
                        ),

                        // يمين (عربي)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              companyNameAr,
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (branchTitleAr.isNotEmpty)
                              pw.Text(
                                branchTitleAr,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            if (address.isNotEmpty)
                              pw.Text(
                                address,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            if (phone1.isNotEmpty || phone2.isNotEmpty)
                              pw.Text(
                                'تلفون: ${[
                                  if (phone1.isNotEmpty) phone1,
                                  if (phone2.isNotEmpty) phone2,
                                ].join(' - ')}',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            if (whatsapp.isNotEmpty)
                              pw.Text(
                                'واتساب: $whatsapp',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ----------------- عنوان الفاتورة -----------------
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 3, horizontal: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.black, width: 1.0),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'فاتورة المبيعات',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // ----------------- بيانات عامة -----------------
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 3, horizontal: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.black, width: 1.0),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('رقم الفاتورة : ${o.id}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('التاريخ : ${o.date}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('العميل : ${o.userName}',
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 3, horizontal: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.black, width: 1.0),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الجوال : ${o.phone.isEmpty ? '-' : o.phone}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('العملة : YER',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('الحالة : ${_statusAr(o.status)}',
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 4),

                  // ----------------- جدول الأصناف -----------------
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.5), // رقم الصنف
                      1: const pw.FlexColumnWidth(4), // اسم الصنف
                      2: const pw.FlexColumnWidth(1.2), // الكمية
                      3: const pw.FlexColumnWidth(1.5), // السعر
                      4: const pw.FlexColumnWidth(1.8), // الإجمالي
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        children: [
                          _cellHeader('رقم الصنف'),
                          _cellHeader('اسم الصنف'),
                          _cellHeader('الكمية'),
                          _cellHeader('السعر'),
                          _cellHeader('الإجمالي'),
                        ],
                      ),
                      ...items.map((it) {
                        return pw.TableRow(
                          children: [
                            _cellBody(it.productId.toString()),
                            _cellBody(
                              it.name.isEmpty
                                  ? 'منتج #${it.productId}'
                                  : it.name,
                            ),
                            _cellBody(it.qty.toString()),
                            _cellBody(it.price.toStringAsFixed(2)),
                            _cellBody(it.lineTotal.toStringAsFixed(2)),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 6),

                  // ----------------- ملخص -----------------
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('عدد الأصناف : ${items.length}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(
                        'الإجمالي : ${o.total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  if (o.note != null && o.note!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'ملاحظات: ${o.note!}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],

                  pw.SizedBox(height: 18),

                  // ----------------- التواقيع -----------------
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('توقيع الموظف',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(height: 10),
                          pw.Container(
                            width: 160,
                            height: 1,
                            color: PdfColors.grey700,
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('توقيع العميل',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(height: 10),
                          pw.Container(
                            width: 160,
                            height: 1,
                            color: PdfColors.grey700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  // خلايا الجدول في PDF
  pw.Widget _cellHeader(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _cellBody(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  // ========= واجهة الشاشة =========

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
              tooltip: 'طباعة',
              onPressed: _order == null ? null : _printOrder,
              icon: const Icon(Icons.print),
            ),
            if (widget.canEditStatus && _order != null)
              PopupMenuButton<String>(
                tooltip: 'تغيير الحالة',
                icon: const Icon(Icons.more_vert),
                onSelected: _changeStatus,
                itemBuilder: (context) {
                  const statuses = [
                    'pending',
                    'paid',
                    'shipped',
                    'completed',
                    'canceled',
                  ];
                  return statuses
                      .map(
                        (s) => PopupMenuItem<String>(
                          value: s,
                          child: Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 10, color: _statusColor(s)),
                              const SizedBox(width: 8),
                              Text(_statusAr(s)),
                            ],
                          ),
                        ),
                      )
                      .toList();
                },
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  // ---------- كرت رأس الطلب + كرت الأصناف (مع الصور) ----------

  Widget _buildHeaderCard() {
    final o = _order!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'العميل: ${o.userName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('الجوال: ${o.phone.isEmpty ? '-' : o.phone}'),
            const SizedBox(height: 4),
            Text('التاريخ: ${o.date}'),
            const SizedBox(height: 4),
            Text(
              'الفرع: ${o.branchName?.isNotEmpty == true ? o.branchName! : (o.branchId == null ? "-" : "فرع ${o.branchId}")}',
            ),
            if ((o.branchAddress ?? '').isNotEmpty)
              Text('العنوان: ${o.branchAddress}'),
            if ((o.branchPhone ?? '').isNotEmpty ||
                (o.branchMobile ?? '').isNotEmpty)
              Text(
                [
                  if ((o.branchPhone ?? '').isNotEmpty)
                    'هاتف: ${o.branchPhone}',
                  if ((o.branchMobile ?? '').isNotEmpty)
                    'جوال: ${o.branchMobile}',
                ].join('   '),
              ),
            if ((o.branchWhatsapp ?? '').isNotEmpty)
              Text('واتساب: ${o.branchWhatsapp}'),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'الإجمالي: ${o.total.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
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
      final url = img.startsWith('http') ? img : '$kServerIp/$img'; // مسار نسبي
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 32),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: leading,
        title: Text(item.name.isEmpty ? 'منتج #${item.productId}' : item.name),
        subtitle: Text(
          'الكمية: ${item.qty} • السعر: ${item.price.toStringAsFixed(2)} ر.س',
        ),
        trailing: Text(
          item.lineTotal.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------- النماذج (Models) ----------

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

  // من جدول الفروع
  final String? companyNameAr;
  final String? companyNameEn;
  final String? branchNameEn;
  final String? branchAddress;
  final String? branchPhone;
  final String? branchMobile;
  final String? branchWhatsapp;
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
    this.branchAddress,
    this.branchPhone,
    this.branchMobile,
    this.branchWhatsapp,
    this.branchLogoUrl,
  });

  OrderHeader copyWith({String? status}) {
    return OrderHeader(
      id: id,
      userId: userId,
      userName: userName,
      phone: phone,
      total: total,
      status: status ?? this.status,
      date: date,
      branchId: branchId,
      branchName: branchName,
      note: note,
      companyNameAr: companyNameAr,
      companyNameEn: companyNameEn,
      branchNameEn: branchNameEn,
      branchAddress: branchAddress,
      branchPhone: branchPhone,
      branchMobile: branchMobile,
      branchWhatsapp: branchWhatsapp,
      branchLogoUrl: branchLogoUrl,
    );
  }

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
        branchAddress: j['branch_address']?.toString(),
        branchPhone: j['branch_phone']?.toString(),
        branchMobile: j['branch_mobile']?.toString(),
        branchWhatsapp: j['branch_whatsapp']?.toString(),
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

  OrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
    required this.lineTotal,
    required this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        productId: int.tryParse('${j['product_id'] ?? 0}') ?? 0,
        name: '${j['product_name'] ?? j['name'] ?? ''}',
        qty: int.tryParse('${j['quantity'] ?? 0}') ?? 0,
        price: double.tryParse('${j['price'] ?? 0}') ?? 0,
        lineTotal: double.tryParse('${j['line_total'] ?? 0}') ?? 0,
        imageUrl: '${j['image_url'] ?? ''}',
      );
}

// ---------- كرت الخطأ ----------

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
                SelectableText(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
