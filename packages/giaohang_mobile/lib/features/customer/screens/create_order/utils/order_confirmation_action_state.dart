bool isOrderConfirmationActionBusy({
  required bool isSubmitting,
  required bool isBackgroundPaymentCheck,
  bool isUserPaymentAction = false,
}) {
  return isSubmitting || isUserPaymentAction;
}
