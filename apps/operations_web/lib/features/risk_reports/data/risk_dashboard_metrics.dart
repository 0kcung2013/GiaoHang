class RiskDashboardMetrics {
  const RiskDashboardMetrics({
    required this.active,
    required this.slaOverdue,
    required this.criticalActive,
    required this.waitingAdmin,
    required this.systemActive,
    required this.averageFirstResponseMinutes,
  });

  final int active;
  final int slaOverdue;
  final int criticalActive;
  final int waitingAdmin;
  final int systemActive;
  final double? averageFirstResponseMinutes;

  factory RiskDashboardMetrics.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return RiskDashboardMetrics(
      active: number('active'),
      slaOverdue: number('sla_overdue'),
      criticalActive: number('critical_active'),
      waitingAdmin: number('waiting_admin'),
      systemActive: number('system_active'),
      averageFirstResponseMinutes: (json['avg_first_response_minutes'] as num?)
          ?.toDouble(),
    );
  }
}
