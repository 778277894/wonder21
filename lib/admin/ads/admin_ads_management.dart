// lib/admin/admin_ads_management.dart
// شاشة إدارة الإعلانات + إظهار أخطاء السيرفر بشكل واضح
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// استيراد الملف الموحد
import '../server_config.dart';

class AdminAdsManagement extends StatefulWidget {
  const AdminAdsManagement({super.key});

  @override
  State<AdminAdsManagement> createState() => _AdminAdsManagementState();
}

class _AdminAdsManagementState extends State<AdminAdsManagement> {
  // تم الاستغناء عن serverIp و baseUrl واستبدالهما بـ ServerConfig.baseUrl

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 25),
    receiveTimeout: const Duration(seconds: 25),
    sendTimeout: const Duration(seconds: 25),
    // لإظهار نص الاستجابة كما هو لسهولة معالجة أخطاء الاستضافات المجانية
    responseType: ResponseType.plain,
  ));

  bool loading = true;
  String? loadError;
  List<Map<String, dynamic>> ads = [];

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  // ===== أدوات رسائل الأخطاء =====
  void _showSnack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  /// يعيد رسالة مفهومة من أي DioException (JSON أو نص خام)
  String _humanizeDioError(DioException e) {
    final res = e.response;
    if (res != null) {
      final status = res.statusCode;
      final data = res.data;

      final body = data is String ? data : data?.toString() ?? '';

      try {
        final parsed = jsonDecode(body);
        if (parsed is Map) {
          final msg = parsed['message'] ??
              parsed['error'] ??
              parsed['detail'] ??
              parsed['status'] ??
              parsed['errors']?.toString();
          if (msg != null && msg.toString().trim().isNotEmpty) {
            return "HTTP $status: ${msg.toString()}";
          }
        }
      } catch (_) {}

      if (body.isNotEmpty) {
        final short = body.length > 400 ? body.substring(0, 400) + "..." : body;
        return "HTTP $status\n$short";
      }

      return "HTTP $status: ${res.statusMessage ?? e.message ?? 'Unknown error'}";
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "انتهت المهلة أثناء الاتصال بالخادم.";
    }
    if (e.type == DioExceptionType.connectionError) {
      return "تعذّر الاتصال بالخادم (${e.message}).";
    }
    return e.message ?? "خطأ غير معروف";
  }

  // ===== API =====
  Future<void> _fetchAds() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      // استخدام ServerConfig.baseUrl من الملف الموحد
      final r = await dio.get("${kServerIp}/get_ads.php");
      final j = jsonDecode(r.data);
      if (j['success'] == true) {
        final List list = j['ads'] ?? [];
        ads = list.cast<Map<String, dynamic>>();
      } else {
        loadError = j['message']?.toString() ?? "فشل جلب الإعلانات";
      }
    } on DioException catch (e) {
      loadError = _humanizeDioError(e);
    } catch (e) {
      loadError = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteAd(int adId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تأكيد الحذف"),
          content: const Text("هل تريد حذف الإعلان؟"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("حذف"),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final r =
          await dio.post("$kServerIp/delete_ad.php", data: {"ad_id": "$adId"});
      final j = jsonDecode(r.data);
      _showSnack(j['message']?.toString() ?? "تم الحذف");
      if (j['success'] == true) _fetchAds();
    } on DioException catch (e) {
      _showSnack(_humanizeDioError(e), color: Colors.red);
    } catch (e) {
      _showSnack(e.toString(), color: Colors.red);
    }
  }

  // ===== نافذة إضافة/تعديل إعلان =====
  void _openAdForm({Map<String, dynamic>? ad}) {
    final isEdit = ad != null;
    final titleC = TextEditingController(text: ad?['title'] ?? '');
    final bodyC = TextEditingController(text: ad?['body'] ?? '');
    final targetC = TextEditingController(text: ad?['target_url'] ?? '');
    final productC = TextEditingController(text: "${ad?['product_id'] ?? ''}");
    final startsC = TextEditingController(text: ad?['starts_at'] ?? '');
    final endsC = TextEditingController(text: ad?['ends_at'] ?? '');
    final sortC = TextEditingController(text: "${ad?['sort_order'] ?? 0}");

    String linkType = (ad?['link_type'] ?? 'url').toString();
    String position = (ad?['position'] ?? 'home_top').toString();
    bool active = (ad?['active'] ?? 1).toString() == '1';

    XFile? mainImage;
    List<XFile> extraImages = [];

    Future<void> pickMain() async {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x != null) {
        setState(() => mainImage = x);
      }
    }

    Future<void> pickExtra() async {
      final xs = await ImagePicker().pickMultiImage();
      if (xs.isNotEmpty) {
        setState(() => extraImages = [...extraImages, ...xs]);
      }
    }

    Future<void> pickDate(TextEditingController c) async {
      final now = DateTime.now();
      final d = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 5),
        initialDate: now,
        locale: const Locale('ar'),
      );
      if (d == null) return;
      final t =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      final dt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);

      c.text =
          "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00";
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEdit ? "تعديل إعلان" : "إضافة إعلان"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                      controller: titleC,
                      decoration:
                          const InputDecoration(labelText: "العنوان *")),
                  const SizedBox(height: 8),
                  TextField(
                      controller: bodyC,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: "النص (اختياري)")),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: linkType,
                    items: const [
                      DropdownMenuItem(value: 'url', child: Text('رابط')),
                      DropdownMenuItem(value: 'product', child: Text('منتج')),
                    ],
                    onChanged: (v) =>
                        setStateDialog(() => linkType = v ?? 'url'),
                    decoration: const InputDecoration(labelText: 'نوع الرابط'),
                  ),
                  const SizedBox(height: 8),

                  if (linkType == 'url')
                    TextField(
                        controller: targetC,
                        decoration:
                            const InputDecoration(labelText: "الرابط (URL)")),
                  if (linkType == 'product')
                    TextField(
                      controller: productC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "رقم المنتج (product_id)"),
                    ),

                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: position,
                    items: const [
                      DropdownMenuItem(
                          value: 'home_top', child: Text('الرئيسية - أعلى')),
                      DropdownMenuItem(
                          value: 'home_middle', child: Text('الرئيسية - وسط')),
                      DropdownMenuItem(
                          value: 'home_bottom', child: Text('الرئيسية - أسفل')),
                    ],
                    onChanged: (v) =>
                        setStateDialog(() => position = v ?? 'home_top'),
                    decoration: const InputDecoration(labelText: 'الموضع'),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startsC,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "يبدأ (اختياري)",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.date_range),
                              onPressed: () => pickDate(startsC),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: endsC,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "ينتهي (اختياري)",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.date_range),
                              onPressed: () => pickDate(endsC),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sortC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: "الترتيب (اختياري)"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          onChanged: (v) => setStateDialog(() => active = v),
                          title: const Text("مفعل"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // صورة رئيسية
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickMain();
                          setStateDialog(
                              () {}); // تحديث النافذة لعرض الصورة المختارة
                        },
                        icon: const Icon(Icons.image),
                        label: const Text("صورة رئيسية"),
                      ),
                      const SizedBox(width: 12),
                      if (mainImage != null)
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: kIsWeb
                              ? FutureBuilder<Uint8List>(
                                  future: mainImage!.readAsBytes(),
                                  builder: (_, s) => s.hasData
                                      ? Image.memory(s.data!, fit: BoxFit.cover)
                                      : const Center(
                                          child: CircularProgressIndicator()),
                                )
                              : Image.file(File(mainImage!.path),
                                  fit: BoxFit.cover),
                        )
                      else if (isEdit &&
                          (ad?['image_url']?.toString().isNotEmpty ?? false))
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: Image.network(ad!['image_url'].toString(),
                              fit: BoxFit.cover),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // صور إضافية
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickExtra();
                          setStateDialog(() {});
                        },
                        icon: const Icon(Icons.collections),
                        label: const Text("إضافة صور متعددة"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (extraImages.isNotEmpty)
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: extraImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final x = extraImages[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? FutureBuilder<Uint8List>(
                                        future: x.readAsBytes(),
                                        builder: (_, s) => s.hasData
                                            ? Image.memory(s.data!,
                                                width: 86,
                                                height: 86,
                                                fit: BoxFit.cover)
                                            : const SizedBox(
                                                width: 86,
                                                height: 86,
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator())),
                                      )
                                    : Image.file(File(x.path),
                                        width: 86,
                                        height: 86,
                                        fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  onTap: () => setStateDialog(
                                      () => extraImages.removeAt(i)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              )
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء")),
              ElevatedButton(
                child: const Text("حفظ"),
                onPressed: () async {
                  if (titleC.text.trim().isEmpty) {
                    _showSnack("العنوان مطلوب", color: Colors.red);
                    return;
                  }
                  if (linkType == 'product' &&
                      (int.tryParse(productC.text.trim()) ?? 0) <= 0) {
                    _showSnack("رقم المنتج مطلوب", color: Colors.red);
                    return;
                  }

                  try {
                    final form = FormData.fromMap({
                      "title": titleC.text.trim(),
                      "body": bodyC.text.trim(),
                      "link_type": linkType,
                      "product_id":
                          linkType == 'product' ? productC.text.trim() : "",
                      "target_url":
                          linkType == 'url' ? targetC.text.trim() : "",
                      "position": position,
                      "starts_at": startsC.text.trim(),
                      "ends_at": endsC.text.trim(),
                      "active": active ? "1" : "0",
                      "sort_order":
                          sortC.text.trim().isEmpty ? "0" : sortC.text.trim(),
                    });

                    if (mainImage != null) {
                      if (kIsWeb) {
                        final bytes = await mainImage!.readAsBytes();
                        form.files.add(MapEntry(
                            "image",
                            MultipartFile.fromBytes(bytes,
                                filename: mainImage!.name)));
                      } else {
                        form.files.add(MapEntry(
                            "image",
                            await MultipartFile.fromFile(mainImage!.path,
                                filename: mainImage!.name)));
                      }
                    }

                    for (final x in extraImages) {
                      if (kIsWeb) {
                        final bytes = await x.readAsBytes();
                        form.files.add(MapEntry("images[]",
                            MultipartFile.fromBytes(bytes, filename: x.name)));
                      } else {
                        form.files.add(MapEntry(
                            "images[]",
                            await MultipartFile.fromFile(x.path,
                                filename: x.name)));
                      }
                    }

                    final endpoint = isEdit ? "/update_ad.php" : "/add_ad.php";
                    if (isEdit)
                      form.fields.add(
                          MapEntry("ad_id", "${ad?['ad_id'] ?? ad?['id']}"));

                    final r =
                        await dio.post("${kServerIp}$endpoint", data: form);
                    final j = jsonDecode(r.data);
                    _showSnack(j['message']?.toString() ?? "تمت العملية");
                    if (j['success'] == true) {
                      if (mounted) Navigator.pop(context);
                      _fetchAds();
                    }
                  } on DioException catch (e) {
                    _showSnack(_humanizeDioError(e), color: Colors.red);
                  } catch (e) {
                    _showSnack(e.toString(), color: Colors.red);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("إدارة الإعلانات"),
          backgroundColor: Colors.teal,
          actions: [
            IconButton(onPressed: _fetchAds, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAdForm(),
          icon: const Icon(Icons.add),
          label: const Text("إضافة إعلان"),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(loadError!,
                        style: const TextStyle(color: Colors.red)),
                  )
                : ads.isEmpty
                    ? const Center(child: Text("لا توجد إعلانات"))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: ads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final a = ads[i];
                          final id = a['ad_id'] ?? a['id'] ?? "";
                          final img = a['image_url']?.toString() ?? "";
                          final title = a['title']?.toString() ?? "";
                          final activeStatus =
                              (a['active'] ?? 1).toString() == '1';

                          return Card(
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: img.isNotEmpty
                                    ? Image.network(img,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image,
                                                size: 40))
                                    : const Icon(Icons.image, size: 40),
                              ),
                              title: Text(title),
                              subtitle: Text(
                                  "مفعل: ${activeStatus ? 'نعم' : 'لا'} • رقم: $id"),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _openAdForm(ad: a),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _deleteAd(int.tryParse("$id") ?? 0),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
