enum RiskQueueScope {
  active,
  newReports,
  mine,
  waitingAdmin,
  closed,
  all;

  static const adminScopes = [newReports, mine, waitingAdmin, closed, all];
  static const supportScopes = [active, mine, closed];
}
