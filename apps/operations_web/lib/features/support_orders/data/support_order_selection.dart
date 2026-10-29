/// Cùng một hợp đồng thông tin đơn cho tra cứu, hội thoại và hồ sơ sự cố.
const supportOrderSelection = '''
  id, customer_id, driver_id, tracking_code, status,
  pickup_address, pickup_lat, pickup_lng,
  delivery_address, delivery_lat, delivery_lng,
  recipient_name, recipient_phone,
  item_name, item_category, item_description, item_image_url, item_weight_kg,
  note, status_note, service_type,
  total_price, delivery_fee, payment_method, payment_status, delivery_fee_payer,
  goods_value, cod_collection_amount, driver_advance_amount,
  receiver_collection_amount, driver_net_earning,
  created_at, updated_at, estimated_pickup_at, estimated_delivery_at,
  actual_picked_up_at, actual_delivered_at, cancelled_at, delivery_eta, driver_monitoring, business_policy,
  customer:users!orders_customer_id_fkey(full_name, phone, email, avatar_url),
  driver:users!orders_driver_id_fkey(full_name, phone, email, avatar_url)
''';
