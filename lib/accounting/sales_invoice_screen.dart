import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin/server_config.dart'; // فيها kServerIp مثل: const kServerIp = "http://192.168.0.16";

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _customerNameC = TextEditingController();
  final TextEditingController _noteC = TextEditingController();
  DateTime _invoiceDate = DateTime.now();

  final List<_InvoiceItem> _items = [
    _InvoiceItem(),
  ];

  bool _saving = false;
  String? _error;

  double get _total => _items.fold(0.0, (sum, e) => sum + (e.qty * e.price));

  @override
  void dispose() {
    _customerNameC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _invoiceDate,
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
    }
  }

  void _addRow() {
    setState(() {
      _items.add(_InvoiceItem());
    });
  }

  void _removeRow(int index) {
    if (_items.length == 1) return;
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _saveInvoice() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_items
        .where(
            (i) => i.productName.trim().isNotEmpty && i.qty > 0 && i.price > 0)
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنفاً واحداً على الأقل بشكل صحيح')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // تجهيز البيانات لإرسالها للسيرفر
      final payload = {
        'customer_name': _customerNameC.text.trim(),
        'note': _noteC.text.trim(),
        'invoice_date': _invoiceDate.toIso8601String().split('T').first,
        'items': _items
            .where((i) =>
                i.productName.trim().isNotEmpty && i.qty > 0 && i.price > 0)
            .map((e) => {
                  'product_name': e.productName.trim(),
                  'qty': e.qty,
                  'price': e.price,
                })
            .toList(),
      };

      final uri = Uri.parse('$kServerIp/add_sales_invoice.php');
      final res = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }

      final Map<String, dynamic> j = jsonDecode(res.body);
      if (j['success'] != true) {
        throw Exception(j['message'] ?? 'فشل حفظ الفاتورة');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(j['message']?.toString() ?? 'تم حفظ فاتورة المبيعات بنجاح'),
        ),
      );

      // تفريغ النموذج بعد الحفظ
      setState(() {
        _customerNameC.clear();
        _noteC.clear();
        _invoiceDate = DateTime.now();
        _items
          ..clear()
          ..add(_InvoiceItem());
      });
    } catch (e) {
      setState(() => _error = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${_invoiceDate.year}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.day.toString().padLeft(2, '0')}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE9B270),
          title: const Text('فاتورة المبيعات'),
          actions: [
            IconButton(
              tooltip: 'حفظ الفاتورة',
              onPressed: _saving ? null : _saveInvoice,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: _saving
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    if (_error != null) ...[
                      Card(
                        color: Colors.red.withOpacity(.05),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _customerNameC,
                              decoration: const InputDecoration(
                                labelText: 'اسم العميل',
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'أدخل اسم العميل';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.date_range),
                              title: const Text('تاريخ الفاتورة'),
                              subtitle: Text(dateText),
                              trailing: TextButton(
                                onPressed: _pickDate,
                                child: const Text('تغيير'),
                              ),
                            ),
                            TextFormField(
                              controller: _noteC,
                              decoration: const InputDecoration(
                                labelText: 'ملاحظات (اختياري)',
                                alignLabelWithHint: true,
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'الأصناف',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة صنف'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          // رأس الجدول
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: const [
                                Expanded(flex: 4, child: Text('الصنف')),
                                Expanded(flex: 2, child: Text('الكمية')),
                                Expanded(flex: 2, child: Text('السعر')),
                                SizedBox(width: 40),
                              ],
                            ),
                          ),
                          const Divider(height: 0),
                          // الصفوف
                          ..._items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: TextFormField(
                                          initialValue: item.productName,
                                          decoration: InputDecoration(
                                            hintText: 'اسم الصنف',
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onChanged: (v) =>
                                              item.productName = v,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: item.qty.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: 'الكمية',
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onChanged: (v) {
                                            final q =
                                                int.tryParse(v.trim()) ?? 0;
                                            setState(() => item.qty = q);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue:
                                              item.price.toStringAsFixed(2),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'السعر',
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onChanged: (v) {
                                            final p = double.tryParse(v
                                                    .replaceAll(',', '.')
                                                    .trim()) ??
                                                0.0;
                                            setState(() => item.price = p);
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        tooltip: 'حذف صف',
                                        onPressed: () => _removeRow(index),
                                      ),
                                    ],
                                  ),
                                ),
                                if (index != _items.length - 1)
                                  const Divider(height: 0),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'الإجمالي: ${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveInvoice,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ الفاتورة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 210, 156, 7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}

// نموذج صف في الفاتورة
class _InvoiceItem {
  String productName;
  int qty;
  double price;

  _InvoiceItem({
    this.productName = '',
    this.qty = 1,
    this.price = 0.0,
  });
}
