import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// موديل الصنف داخل الفاتورة
class PurchaseItem {
  String name;
  double qty;
  double price;

  PurchaseItem({
    required this.name,
    required this.qty,
    required this.price,
  });

  double get total => qty * price;
}

class PurchaseInvoiceScreen extends StatefulWidget {
  const PurchaseInvoiceScreen({super.key});

  @override
  State<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends State<PurchaseInvoiceScreen> {
  // Controllers
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  // جدول الأصناف في الفاتورة
  List<PurchaseItem> items = [];

  // المجاميع
  double total = 0;
  double discount = 0;
  double netTotal = 0;

  // منتجات MySQL
  List productsFromDB = [];
  String? selectedProductName;
  double selectedPurchasePrice = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();

    dateController.text =
        "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
  }

  // جلب المنتجات من MySQL عبر API
  Future<void> _loadProducts() async {
    final url = Uri.parse("http://192.168.0.16/get_products.php"); // عدل الرابط
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          productsFromDB = jsonDecode(response.body);
        });
      } else {
        print("Failed to load products: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching products: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة المشتريات'),
        centerTitle: true,
        backgroundColor: const Color(0xFFE9B270),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // المورد + التاريخ
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'اسم المورد',
                    controller: supplierController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDateField(),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // زر إضافة صنف
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة صنف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _addItemDialog,
              ),
            ),

            const SizedBox(height: 10),

            // جدول الأصناف
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5,
                    )
                  ],
                ),
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد أصناف مضافة',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE9B270),
                              child: Text('${index + 1}'),
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                                'الكمية: ${item.qty} × السعر: ${item.price}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.total.toStringAsFixed(2),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      items.removeAt(index);
                                      _calculateTotal();
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // الخصم
            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الخصم',
                prefixIcon: const Icon(Icons.money_off),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => _calculateTotal(),
            ),

            const SizedBox(height: 8),

            // الملخص
            _buildSummary(),

            const SizedBox(height: 10),

            // أزرار التحكم
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saveInvoice,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('إلغاء'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TextField عام
  Widget _buildField(
      {required String label, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // التاريخ
  Widget _buildDateField() {
    return TextField(
      controller: dateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'التاريخ',
        suffixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2022),
          lastDate: DateTime(2035),
        );

        if (picked != null) {
          setState(() {
            dateController.text =
                "${picked.year}-${picked.month}-${picked.day}";
          });
        }
      },
    );
  }

  // نافذة إضافة صنف من MySQL
  void _addItemDialog() {
    TextEditingController qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة صنف من المخزن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dropdown المنتجات
            DropdownButtonFormField(
              hint: const Text('اختر الصنف'),
              value: selectedProductName,
              items: productsFromDB.map((item) {
                return DropdownMenuItem(
                  value: item['name'],
                  child: Text(item['name']),
                );
              }).toList(),
              onChanged: (value) {
                final product = productsFromDB.firstWhere(
                  (e) => e['name'] == value,
                );
                setState(() {
                  selectedProductName = value.toString();
                  selectedPurchasePrice =
                      double.parse(product['purchase_price'].toString());
                });
              },
            ),

            const SizedBox(height: 10),

            // السعر تلقائي
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'سعر الشراء',
                hintText: selectedPurchasePrice.toString(),
              ),
            ),

            const SizedBox(height: 10),

            // الكمية
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('إضافة'),
            onPressed: () {
              if (selectedProductName == null || qtyController.text.isEmpty)
                return;

              setState(() {
                items.add(
                  PurchaseItem(
                    name: selectedProductName!,
                    qty: double.parse(qtyController.text),
                    price: selectedPurchasePrice,
                  ),
                );

                _calculateTotal();
              });

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // حساب الإجمالي
  void _calculateTotal() {
    total = 0;

    for (var item in items) {
      total += item.total;
    }

    discount = double.tryParse(discountController.text) ?? 0;

    netTotal = total - discount;

    setState(() {});
  }

  // ملخص الفاتورة
  Widget _buildSummary() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _row('الإجمالي', total),
            _row('الخصم', discount),
            const Divider(),
            _row('الصافي', netTotal, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value.toStringAsFixed(2),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // حفظ الفاتورة (يمكن تعديلها لاحقًا لإرسال MySQL)
  void _saveInvoice() {
    if (supplierController.text.isEmpty || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل المورد وأضف الأصناف أولاً')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الفاتورة بنجاح ✔')),
    );

    // لاحقًا: ارسال POST إلى MySQL
  }
}
