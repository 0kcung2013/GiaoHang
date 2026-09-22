import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/utils/vnd_input_formatter.dart';

class OrderFinanceFormController extends ChangeNotifier {
  OrderFinanceFormController() {
    codCollectionController.addListener(notifyListeners);
  }

  final codCollectionController = TextEditingController();
  bool _collectCod = true;
  bool get collectCod => _collectCod;

  void setCollectCod(bool value) {
    if (_collectCod == value) return;
    _collectCod = value;
    notifyListeners();
  }

  int get codCollectionAmount =>
      _collectCod ? parseVndInput(codCollectionController.text) : 0;

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
