ALTER TABLE public.orders
  DROP CONSTRAINT orders_payment_method_check,
  ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IN ('cash', 'card', 'wallet', 'vnpay'));
ALTER TABLE public.orders
  DROP CONSTRAINT orders_payment_method_check,
  ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IN ('cash', 'card', 'wallet', 'vnpay'));
