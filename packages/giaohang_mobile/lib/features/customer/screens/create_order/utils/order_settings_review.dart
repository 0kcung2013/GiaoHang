/// An issued payment session or an uncertain wallet attempt must keep its
/// snapshot until the server definitively resolves it.
bool requiresOrderSettingsReview({
  required int? quotedRevision,
  required int latestRevision,
  bool paymentProtected = false,
  bool rejectedByServer = false,
}) =>
    !paymentProtected &&
    (rejectedByServer ||
        quotedRevision == null ||
        latestRevision > quotedRevision);

enum OrderConfirmationResult { reviewSettings }
