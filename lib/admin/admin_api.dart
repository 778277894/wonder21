import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';
import 'analytics_models.dart';

class AdminApi {
  final http.Client _client;
  AdminApi({http.Client? client}) : _client = client ?? http.Client();

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Env.baseUrl}/$path').replace(queryParameters: q);

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<DashboardStats> fetchDashboardStats() async {
    final res = await _client.get(
      _u('get_dashboard_stats.php'),
      headers: _headers(),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return DashboardStats.fromJson(json['data'] as Map<String, dynamic>);
      } else {
        throw Exception(json['message'] ?? 'فشل في جلب الإحصائيات');
      }
    }
    throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
  }

  Future<List<SeriesPoint>> fetchDailySeries(String range) async {
    final res = await _client.get(
      _u('get_activity_series.php', {'range': range}),
      headers: _headers(),
    );

    if (res.statusCode == 200) {
      return parseSeriesJson(res.body);
    }
    throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
  }
}
