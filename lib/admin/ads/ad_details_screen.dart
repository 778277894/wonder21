// lib/admin/ad_details_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ad;
  final String baseUrl;
  final String uploadsBase;
  final Future<void> Function()? onChanged;
  final bool openEdit;

  const AdDetailsScreen({
    super.key,
    required this.ad,
    required this.baseUrl,
    required this.uploadsBase,
    this.onChanged,
    this.openEdit = false,
  });

  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  late Map<String, dynamic> ad;

  @override
  void initState() {
    super.initState();
    ad = Map<String, dynamic>.from(widget.ad);
    if (widget.openEdit) Future.microtask(_openEditDialog);
  }

  int adIdOf(Map<String, dynamic> a) {
    final v = a['ad_id'] ?? a['id'];
    return int.tryParse('$v') ?? 0;
  }

  String fixImageUrl(dynamic raw) {
    String v = (raw ?? '').toString().trim().replaceAll('\\', '/');
    if (v.isEmpty) return '';
    if (v.startsWith('http://') || v.startsWith('https://'))
      return Uri.encodeFull(v);
    if (v.startsWith('/')) return Uri.encodeFull("${widget.baseUrl}$v");
    if (v.startsWith('uploads/'))
      return Uri.encodeFull("${widget.uploadsBase}/${v.substring(8)}");
    return Uri.encodeFull("${widget.uploadsBase}/$v");
  }

  Future<void> _deleteMe() async {
    final id = adIdOf(ad);
    if (id <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('معرّف غير صالح')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('حذف الإعلان: ${ad['title'] ?? ''} ؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final r = await http.post(Uri.parse('${widget.baseUrl}/delete_ad.php'),
          body: {'ad_id': '$id'});
      final j = jsonDecode(r.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(j['message']?.toString() ?? 'تم')));
      if (j['success'] == true) {
        await widget.onChanged?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _openEditDialog() async {
    final titleC = TextEditingController(text: ad['title']?.toString() ?? '');
    final productIdC =
        TextEditingController(text: (ad['product_id'] ?? '').toString());
    bool active = (ad['active'] ?? 1).toString() == '1';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل إعلان (سريع)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleC,
                  decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 8),
              TextField(
                controller: productIdC,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'رقم المنتج (اختياري)'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: active,
                onChanged: (v) => active = v,
                title: const Text('مفعّل'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final id = adIdOf(ad);
      try {
        final r = await http
            .post(Uri.parse('${widget.baseUrl}/update_ad.php'), body: {
          'ad_id': '$id',
          'title': titleC.text.trim(),
          'product_id': productIdC.text.trim(),
          'active': active ? '1' : '0',
        });
        final j = jsonDecode(r.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(j['message']?.toString() ?? 'تم')));
        if (j['success'] == true) {
          // حدّث البيانات المعروضة محليًا
          setState(() {
            ad['title'] = titleC.text.trim();
            ad['product_id'] = productIdC.text.trim();
            ad['active'] = active ? 1 : 0;
          });
          await widget.onChanged?.call();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final idTxt = (ad['ad_id'] ?? ad['id'] ?? '').toString();
    final img = fixImageUrl(ad['image_url']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الإعلان'),
          actions: [
            IconButton(
                icon: const Icon(Icons.edit), onPressed: _openEditDialog),
            IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteMe),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  img,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 80),
                ),
              )
            else
              const SizedBox(
                height: 160,
                child: Center(child: Icon(Icons.image, size: 48)),
              ),
            const SizedBox(height: 16),
            Text('المعرّف: $idTxt',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('العنوان: ${ad['title'] ?? ''}'),
            const SizedBox(height: 8),
            Text(
                'الحالة: ${(ad['active'] ?? 1).toString() == '1' ? 'مفعّل' : 'موقوف'}'),
            if ((ad['product_id'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('رقم المنتج: ${ad['product_id']}'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // افتح المنتج المرتبط - عدّل الراوت حسب تطبيقك
                  Navigator.pushNamed(context, '/product_details',
                      arguments: {'product_id': ad['product_id']});
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح المنتج المرتبط'),
              ),
            ],
            if ((ad['start_at'] ?? '').toString().isNotEmpty ||
                (ad['end_at'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                  'الفترة: ${(ad['start_at'] ?? "-")} → ${(ad['end_at'] ?? "-")}'),
            ],
          ],
        ),
      ),
    );
  }
}
