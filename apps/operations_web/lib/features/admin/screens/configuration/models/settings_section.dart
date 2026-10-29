import 'package:flutter/material.dart';

import '../settings_strings.dart';
import 'settings_fields.dart';

enum SettingsSection {
  pricing,
  goods,
  wallet,
  dispatch,
  contact,
  platformFee,
  review;

  SettingsGroup? get group => this == review ? null : settingsGroups[index];
  String get label => group?.label ?? SettingsStrings.reviewTitle;
  IconData get icon => switch (this) {
    pricing => Icons.payments_outlined,
    goods => Icons.inventory_2_outlined,
    wallet => Icons.account_balance_wallet_outlined,
    dispatch => Icons.route_outlined,
    contact => Icons.business_outlined,
    platformFee => Icons.percent_rounded,
    review => Icons.fact_check_outlined,
  };
}
