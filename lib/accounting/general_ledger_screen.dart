import 'package:flutter/material.dart';
import 'package:wonderful2/accounting/purchase_invoice_screen.dart';
import 'sales_invoice_screen.dart';

class GeneralLedgerScreen extends StatelessWidget {
  const GeneralLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأستاذ العام'),
          backgroundColor: const Color(0xFFE9B270),
          centerTitle: true,
        ),
        body: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(12),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildTile(
              icon: Icons.point_of_sale,
              title: 'فاتورة المبيعات',
              onTap: () => _open(context, 'sales_invoice'),
            ),
            _buildTile(
              icon: Icons.shopping_cart,
              title: 'فاتورة المشتريات',
              onTap: () => _open(context, 'purchase_invoice'),
            ),
            _buildTile(
              icon: Icons.reply,
              title: 'مردود مبيعات',
              onTap: () => _open(context, 'sales_return'),
            ),
            _buildTile(
              icon: Icons.reply_all,
              title: 'مردود مشتريات',
              onTap: () => _open(context, 'purchase_return'),
            ),
            _buildTile(
              icon: Icons.money_off,
              title: 'سندات الصرف',
              onTap: () => _open(context, 'payment_voucher'),
            ),
            _buildTile(
              icon: Icons.attach_money,
              title: 'سندات القبض',
              onTap: () => _open(context, 'receipt_voucher'),
            ),
            _buildTile(
              icon: Icons.library_books,
              title: 'القيود اليومية',
              onTap: () => _open(context, 'journal_entries'),
            ),
            _buildTile(
              icon: Icons.menu_book,
              title: 'دفتر الأستاذ',
              onTap: () => _open(context, 'ledger_book'),
            ),
            _buildTile(
              icon: Icons.assessment,
              title: 'ميزان المراجعة',
              onTap: () => _open(context, 'trial_balance'),
            ),
            _buildTile(
              icon: Icons.show_chart,
              title: 'قائمة الدخل',
              onTap: () => _open(context, 'income_statement'),
            ),
            _buildTile(
              icon: Icons.account_balance,
              title: 'الميزانية العمومية',
              onTap: () => _open(context, 'balance_sheet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
      {required IconData icon, required String title, Function()? onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: Color(0xFFDAA84A)),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String routeName) {
    switch (routeName) {
      case 'sales_invoice':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesInvoiceScreen()),
        );
      case 'purchase_invoice':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PurchaseInvoiceScreen()),
        );

        break;

      // باقي الحالات لاحقاً
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم يتم تفعيل هذه الصفحة بعد')),
        );
    }
  }
}
