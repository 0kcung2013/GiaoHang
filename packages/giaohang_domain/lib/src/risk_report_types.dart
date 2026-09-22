enum RiskSeverity {
  low,
  medium,
  high,
  critical;

  static RiskSeverity fromDatabase(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => RiskSeverity.medium,
  );
}

enum RiskCategory {
  deliveryDelay('delivery_delay'),
  suspiciousAddress('suspicious_address'),
  contactIssue('contact_issue'),
  cargoIssue('cargo_issue'),
  repeatedCancellation('repeated_cancellation'),
  payment('payment'),
  safety('safety'),
  system('system'),
  other('other');

  const RiskCategory(this.databaseValue);

  final String databaseValue;

  static RiskCategory fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskCategory.other,
  );
}

enum RiskScope {
  order('order'),
  system('system');

  const RiskScope(this.databaseValue);

  final String databaseValue;

  static RiskScope fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskScope.order,
  );
}

enum RiskStatus {
  open('open'),
  investigating('investigating'),
  actionRequired('action_required'),
  waitingCustomer('waiting_customer'),
  waitingAdmin('waiting_admin'),
  resolved('resolved'),
  dismissed('dismissed');

  const RiskStatus(this.databaseValue);

  final String databaseValue;

  bool get isClosed => this == resolved || this == dismissed;

  static RiskStatus fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskStatus.open,
  );
}

enum RiskReporterRole {
  customer,
  driver,
  support,
  admin,
  unknown;

  static RiskReporterRole fromDatabase(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => RiskReporterRole.unknown,
  );
}

enum RiskInterventionState {
  awaitingTriage('awaiting_triage'),
  heldBeforePickup('held_before_pickup'),
  continueDelivery('continue_delivery'),
  returnRequired('return_required'),
  handoffRequired('handoff_required'),
  released('released');

  const RiskInterventionState(this.databaseValue);

  final String databaseValue;

  static RiskInterventionState fromDatabase(String? value) => values.firstWhere(
    (item) => item.databaseValue == value,
    orElse: () => RiskInterventionState.awaitingTriage,
  );
}

enum RiskEvidenceType {
  photo,
  location;

  static RiskEvidenceType fromDatabase(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => RiskEvidenceType.photo,
  );
}
