enum RiskQueueScope {
  active,
  newReports,
  overdue,
  mine,
  waitingAdmin,
  closed,
  all;

  static const adminScopes = [
    newReports,
    overdue,
    mine,
    waitingAdmin,
    closed,
    all,
  ];
  static const supportScopes = [active, mine, closed];
}
