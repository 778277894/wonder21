import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../server_config.dart'; // فيها const kServerIp = "http://192.168.0.16";

class AdminCurrenciesScreen extends StatefulWidget {
  const AdminCurrenciesScreen({super.key});

  @override
  State<AdminCurrenciesScreen> createState() => _AdminCurrenciesScreenState();
}

class _AdminCurrenciesScreenState extends State<AdminCurrenciesScreen> {
  bool _loading = true;
  String? _error;
  List<_CurrencyRow> _list = [];
  final _searchC = TextEditingController();
  bool _activeOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchC.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$kServerIp/get_currencies.php').replace(
        queryParameters: {
          if (_activeOnly) 'active_only': '1',
        },
      );

      final res = await http.get(uri, headers: const {
        'Accept': 'application/json',
      });

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
        throw Exception(j['message'] ?? 'فشل جلب العملات');
      }

      final List list = j['currencies'] ?? [];
      _list = list
          .map((e) => _CurrencyRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _list = [];
      });
    }
  }

  Future<void> _toggleActive(_CurrencyRow c, bool active) async {
    try {
      final res = await http.post(
        Uri.parse('$kServerIp/toggle_currency_active.php'),
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'currency_id': c.id.toString(),
          'active': active ? '1' : '0',
        },
      );

      Map<String, dynamic> j;
      try {
        j = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        j = {};
      }
      final ok = j['success'] == true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            j['message'] ??
                (ok ? 'تم تحديث حالة العملة' : 'فشل تحديث حالة العملة'),
          ),
        ),
      );

      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _saveCurrency({_CurrencyRow? existing}) async {
    final isEdit = existing != null;

    final codeC = TextEditingController(text: existing?.code ?? '');
    final nameArC = TextEditingController(text: existing?.nameAr ?? '');
    final nameEnC = TextEditingController(text: existing?.nameEn ?? '');
    final symbolC = TextEditingController(text: existing?.symbol ?? '');
    final rateC =
        TextEditingController(text: existing?.rateToSar.toString() ?? '1.0');
    bool active = existing?.active ?? true;

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? 'تعديل عملة' : 'إضافة عملة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeC,
                      decoration: const InputDecoration(
                        labelText: 'رمز العملة (مثال: SAR)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameArC,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالعربية',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameEnC,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالإنجليزية (اختياري)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: symbolC,
                      decoration: const InputDecoration(
                        labelText: 'رمز العملة (ر.س /S/ ﷼ ...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: rateC,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'سعر الصرف مقابل الريال السعودي',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: active,
                      onChanged: (v) => setStateDialog(() => active = v),
                      title: const Text('مفعّلة'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final code = codeC.text.trim();
                    final nameAr = nameArC.text.trim();
                    final nameEn = nameEnC.text.trim();
                    final symbol = symbolC.text.trim();
                    final rateStr = rateC.text.trim();

                    if (code.isEmpty || nameAr.isEmpty || symbol.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الرمز والاسم العربي والرمز مطلوبون'),
                        ),
                      );
                      return;
                    }

                    final rate = double.tryParse(rateStr) ?? 1.0;

                    try {
                      final endpoint = isEdit
                          ? '$kServerIp/update_currency.php'
                          : '$kServerIp/add_currency.php';

                      final body = <String, String>{
                        'code': code,
                        'name_ar': nameAr,
                        'name_en': nameEn,
                        'symbol': symbol,
                        'rate_to_sar': rate.toString(),
                        'active': active ? '1' : '0',
                      };
                      if (isEdit) {
                        body['currency_id'] = existing!.id.toString();
                      }

                      final res = await http.post(
                        Uri.parse(endpoint),
                        headers: const {
                          'Content-Type': 'application/x-www-form-urlencoded',
                        },
                        body: body,
                      );

                      Map<String, dynamic> j;
                      try {
                        j = jsonDecode(res.body) as Map<String, dynamic>;
                      } catch (_) {
                        j = {};
                      }

                      final ok = j['success'] == true;

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            j['message'] ??
                                (ok ? 'تم الحفظ بنجاح' : 'فشل حفظ العملة'),
                          ),
                        ),
                      );

                      if (ok) {
                        Navigator.pop(context);
                        _load();
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ: $e')),
                      );
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchC.text.trim().toLowerCase();

    final filtered = _list.where((c) {
      if (q.isEmpty) return true;
      return c.code.toLowerCase().contains(q) ||
          c.nameAr.toLowerCase().contains(q) ||
          c.nameEn.toLowerCase().contains(q) ||
          c.symbol.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة العملات'),
          backgroundColor: const Color(0xFFE9B270),
          actions: [
            Row(
              children: [
                const Text('المفعّلة فقط'),
                Switch(
                  value: _activeOnly,
                  onChanged: (v) {
                    setState(() => _activeOnly = v);
                    _load();
                  },
                ),
              ],
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _saveCurrency(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة عملة'),
          backgroundColor: const Color(0xFFE9B270),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _searchC,
                decoration: InputDecoration(
                  hintText: 'ابحث بالرمز/الاسم/الرمز المختصر...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _load)
              else if (filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text('لا توجد عملات'),
                  ),
                )
              else
                ...filtered.map((c) => Card(
                      child: ListTile(
                        onTap: () => _saveCurrency(existing: c),
                        leading: CircleAvatar(
                          child: Text(
                            c.code,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        title: Text('${c.nameAr} (${c.symbol})'),
                        subtitle: Text(
                            'الكود: ${c.code} • السعر مقابل ر.س: ${c.rateToSar}'),
                        trailing: Switch(
                          value: c.active,
                          onChanged: (v) => _toggleActive(c, v),
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

// ===== Model =====

class _CurrencyRow {
  final int id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String symbol;
  final double rateToSar;
  final bool active;

  _CurrencyRow({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.symbol,
    required this.rateToSar,
    required this.active,
  });

  factory _CurrencyRow.fromJson(Map<String, dynamic> j) => _CurrencyRow(
        id: int.tryParse('${j['currency_id'] ?? j['id'] ?? 0}') ?? 0,
        code: '${j['code'] ?? ''}',
        nameAr: '${j['name_ar'] ?? ''}',
        nameEn: '${j['name_en'] ?? ''}',
        symbol: '${j['symbol'] ?? ''}',
        rateToSar: double.tryParse('${j['rate_to_sar'] ?? 1}') ?? 1.0,
        active: (j['active'] ?? 1).toString() == '1',
      );
}

// ===== Error Card =====

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
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
