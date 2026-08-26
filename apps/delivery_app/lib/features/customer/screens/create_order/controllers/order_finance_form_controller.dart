import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/utils/vnd_input_formatter.dart';

class OrderFinanceFormController extends ChangeNotifier {
  final codCollectionController = TextEditingController();

  int get codCollectionAmount => parseVndInput(codCollectionController.text);

  void setCodCollectionAmount(int amount) {
    final formatted = formatVndDigits(amount);
    codCollectionController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  void dispose() {
    codCollectionController.dispose();
    super.dispose();
  }
}
