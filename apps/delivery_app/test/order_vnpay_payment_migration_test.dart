import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      '../../supabase/migrations/20260815131339_customer_order_vnpay_payment.sql',
    ).readAsStringSync();
  });

  test('payment sessions are private and customer-readable only', () {
    expect(
      sql,
      contains(
        'ALTER TABLE public.order_payment_sessions ENABLE ROW LEVEL SECURITY',
      ),
    );
    expect(sql, contains('order_payment_sessions_select_own'));
    expect(
      sql,
      contains(
        'REVOKE INSERT, UPDATE, DELETE ON public.order_payment_sessions',
      ),
    );
  });

  test('sender-paid orders are activated only by the IPN completion RPC', () {
    expect(sql, contains('complete_customer_order_payment'));
    expect(
      sql,
      contains("v_fee_payer = 'sender' AND p_payment_status <> 'paid'"),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.complete_customer_order_payment',
      ),
    );
    expect(sql, contains('TO service_role'));
  });

  test('direct clients cannot forge a paid sender order', () {
    final hardening = File(
      '../../supabase/migrations/20260815135115_harden_order_payment_activation.sql',
    ).readAsStringSync();

    expect(hardening, contains('orders_enforce_payment_activation'));
    expect(hardening, contains('ORDER_PAYMENT_ACTIVATION_FORBIDDEN'));
    expect(hardening, contains('ORDER_PAYMENT_FIELDS_SERVER_MANAGED'));
  });

  test('only the Edge Function service role can create payment sessions', () {
    final restriction = File(
      '../../supabase/migrations/20260815135451_restrict_order_payment_session_creation.sql',
    ).readAsStringSync();

    expect(restriction, contains('p_customer_id uuid'));
    expect(restriction, contains('FROM PUBLIC, anon, authenticated'));
    expect(restriction, contains('TO service_role'));
  });

  test('orders accept VNPAY as an explicit payment method', () {
    final compatibility = File(
      '../../supabase/migrations/20260815135837_allow_vnpay_order_payment_method.sql',
    ).readAsStringSync();

    expect(compatibility, contains("'vnpay'"));
    expect(compatibility, contains('orders_payment_method_check'));
  });

  test('declared value, COD and delivery fee payer are separate fields', () {
    expect(sql, contains('delivery_fee_payer'));
    expect(sql, contains('cod_collection_amount'));
    expect(sql, contains('goods_value'));
    expect(sql, contains('v_receiver_amount := v_cod_amount'));
  });
}
