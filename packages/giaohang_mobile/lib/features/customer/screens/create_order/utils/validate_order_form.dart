import 'package:flutter/material.dart';

bool validateOrderForm(GlobalKey<FormState> key) {
  final form = key.currentState;
  if (form == null) return false;
  final invalidFields = form.validateGranularly();
  if (invalidFields.isEmpty) return true;
  Scrollable.ensureVisible(invalidFields.first.context, alignment: 0.15);
  return false;
}
