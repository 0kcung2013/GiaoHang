import 'package:flutter/material.dart';

import '../wizard/driver_register_prefill.dart';
import '../wizard/driver_register_wizard.dart';

/// Entry đăng ký TX — wizard (bỏ qua bước tài khoản nếu đã prefill).
class DriverRegisterForm extends StatelessWidget {
  const DriverRegisterForm({super.key, this.prefill});

  final DriverRegisterPrefill? prefill;

  @override
  Widget build(BuildContext context) {
    return DriverRegisterWizard(prefill: prefill);
  }
}
