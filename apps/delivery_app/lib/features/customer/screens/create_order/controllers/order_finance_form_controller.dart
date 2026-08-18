import 'package:flutter/material.dart';

import '../../../../../core/utils/vnd_input_formatter.dart';

class OrderFinanceFormController extends ChangeNotifier {
  final codCollectionController = TextEditingController();

  int get codCollectionAmount => parseVndInput(codCollectionController.text);

  @override
  void dispose() {
    codCollectionController.dispose();
    super.dispose();
  }
}
