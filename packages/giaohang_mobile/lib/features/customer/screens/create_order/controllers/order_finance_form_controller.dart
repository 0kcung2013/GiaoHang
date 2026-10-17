import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/utils/vnd_input_formatter.dart';
import '../../../../../core/models/order_finance.dart';

class OrderFinanceFormController extends ChangeNotifier {
  OrderFinanceFormController() {
    codCollectionController.addListener(notifyListeners);
    goodsValueController.addListener(notifyListeners);
  }

  final codCollectionController = TextEditingController();
  final goodsValueController = TextEditingController();
  bool _collectCod = true;
  bool get collectCod => _collectCod;

  void setCollectCod(bool value) {
    if (_collectCod == value) return;
    _collectCod = value;
    notifyListeners();
  }

  int get codCollectionAmount =>
      _collectCod ? parseVndInput(codCollectionController.text) : 0;

  int get goodsValue =>
      _collectCod ? 0 : parseVndInput(goodsValueController.text);

  DeliveryFeePayer get deliveryFeePayer =>
      _collectCod ? DeliveryFeePayer.recipient : DeliveryFeePayer.sender;

  OrderFinance financeFor(int deliveryFee) => OrderFinance.calculate(
    deliveryFeePayer: deliveryFeePayer,
    goodsValue: goodsValue,
    codCollectionAmount: codCollectionAmount,
    deliveryFee: deliveryFee,
  );

  void setCodCollectionAmount(int amount) {
    final formatted = formatVndDigits(amount);
    codCollectionController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void setGoodsValue(int amount) {
    final formatted = formatVndDigits(amount);
    goodsValueController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  void dispose() {
    codCollectionController.dispose();
    goodsValueController.dispose();
    super.dispose();
  }
}
