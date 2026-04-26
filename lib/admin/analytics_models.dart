import 'dart:convert';

class DashboardStats {
  final int totalUsers;
  final int totalOrders;
  final double revenue;
  final double growth;

  DashboardStats({
    required this.totalUsers,
    required this.totalOrders,
    required this.revenue,
    required this.growth,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    return DashboardStats(
      totalUsers: (j['total_users'] ?? 0) as int,
      totalOrders: (j['total_orders'] ?? 0) as int,
      revenue: double.tryParse('${j['revenue'] ?? 0}') ?? 0,
      growth: double.tryParse('${j['growth'] ?? 0}') ?? 0,
    );
  }
}

class SeriesPoint {
  final DateTime date;
  final double value;

  SeriesPoint({required this.date, required this.value});

  factory SeriesPoint.fromJson(Map<String, dynamic> j) {
    return SeriesPoint(
      date: DateTime.parse(j['date'] as String),
      value: double.tryParse('${j['value'] ?? 0}') ?? 0,
    );
  }
}

List<SeriesPoint> parseSeriesJson(String body) {
  final data = jsonDecode(body);
  final list = (data['series'] as List?) ?? const [];
  return list.map((e) => SeriesPoint.fromJson(e as Map<String, dynamic>)).toList();
}