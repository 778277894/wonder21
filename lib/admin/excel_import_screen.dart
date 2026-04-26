import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib; // تجنب تضارب الأسماء
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:wonderful2/admin/server_config.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  bool _isLoading = false;

  // دالة تحميل النموذج التجريبي
  Future<void> _downloadTemplate() async {
    try {
      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheet = excel['Sheet1'];

      // العناوين
      List<excel_lib.CellValue> headers = [
        excel_lib.TextCellValue("رقم الصنف (A)"),
        excel_lib.TextCellValue("الاسم (B)"),
        excel_lib.TextCellValue("الوصف (C)"),
        excel_lib.TextCellValue("السعر (D)"),
        excel_lib.TextCellValue("رابط الصورة (E)"),
        excel_lib.TextCellValue("المخزون (F)"),
        excel_lib.TextCellValue("الطول (G)"),
        excel_lib.TextCellValue("العرض (H)"),
        excel_lib.TextCellValue("الارتفاع (I)"),
        excel_lib.TextCellValue("العمق (J)"),
        excel_lib.TextCellValue("السمك (K)"),
        excel_lib.TextCellValue("المرونة (L)"),
        excel_lib.TextCellValue("سعر جملة (M)"),
        excel_lib.TextCellValue("سعر تجزئة (N)"),
        excel_lib.TextCellValue("جملة الجملة (O)"),
        excel_lib.TextCellValue("سعر الشراء (P)"),
        excel_lib.TextCellValue("الباركود (Q)"),
        excel_lib.TextCellValue("رقم الفئة (R)"),
      ];
      sheet.appendRow(headers);

      // صنف تجريبي واحد للتوضيح
      sheet.appendRow([
        excel_lib.IntCellValue(1001),
        excel_lib.TextCellValue("صنف تجريبي ألمنيوم"),
        excel_lib.TextCellValue("وصف المنتج هنا"),
        excel_lib.DoubleCellValue(150.0),
        excel_lib.TextCellValue("img.jpg"),
        excel_lib.IntCellValue(100),
        excel_lib.DoubleCellValue(6.0),
        excel_lib.DoubleCellValue(0.05),
        excel_lib.DoubleCellValue(0.05),
        excel_lib.DoubleCellValue(0.02),
        excel_lib.DoubleCellValue(1.2),
        excel_lib.IntCellValue(1),
        excel_lib.DoubleCellValue(140.0),
        excel_lib.DoubleCellValue(160.0),
        excel_lib.DoubleCellValue(130.0),
        excel_lib.DoubleCellValue(120.0),
        excel_lib.TextCellValue("6291001"),
        excel_lib.IntCellValue(1),
      ]);

      var fileBytes = excel.save();
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تجهيز النموذج.. جاري الفتح")),
      );

      await OpenFilex.open(filePath);
    } catch (e) {
      _showDialog("خطأ", "فشل إنشاء الملف: $e", Colors.red);
    }
  }

  // دالة الرفع
  Future<void> _importExcelData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        setState(() => _isLoading = true);

        var request = http.MultipartRequest(
            'POST', Uri.parse("$kServerIp/import_products.php"));
        request.files
            .add(await http.MultipartFile.fromPath('excel_file', file.path));

        var response = await request.send();
        var responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          try {
            final Map<String, dynamic> responseData = json.decode(responseBody);
            if (responseData['status'] == 'success') {
              _showDialog("نجاح", responseData['message'], Colors.green);
            } else {
              _showDialog(
                  "خطأ في البيانات", responseData['message'], Colors.orange);
            }
          } catch (e) {
            _showDialog(
                "خطأ سيرفر",
                "رد السيرفر غير مفهوم. تأكد من وجود مجلد vendor\nالرد: $responseBody",
                Colors.red);
          }
        }
      }
    } catch (e) {
      _showDialog("خطأ تقني", "فشل الاتصال: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDialog(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            textAlign: TextAlign.right, style: TextStyle(color: color)),
        content: Text(message, textAlign: TextAlign.right),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("حسناً"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("استيراد الأصناف"),
          centerTitle: true,
          backgroundColor: const Color.fromARGB(255, 236, 155, 5)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.file_download_outlined,
                  size: 80, color: Color.fromARGB(255, 185, 95, 125)),
              ElevatedButton(
                  onPressed: _downloadTemplate,
                  child: const Text("تحميل النموذج التجريبي")),
              const SizedBox(height: 40),
              const Icon(Icons.upload_file,
                  size: 80, color: Color.fromARGB(255, 32, 154, 36)),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _importExcelData,
                      child: const Text("اختيار ملف ورفعه")),
            ],
          ),
        ),
      ),
    );
  }
}
