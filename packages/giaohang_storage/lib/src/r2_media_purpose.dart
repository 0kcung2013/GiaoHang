enum R2MediaPurpose {
  orderCargo('order_cargo'),
  deliveryProof('delivery_proof'),
  riskEvidence('risk_evidence'),
  driverKyc('driver_kyc'),
  driverProfileChange('driver_profile_change'),
  avatar('avatar');

  const R2MediaPurpose(this.apiValue);

  final String apiValue;
}
