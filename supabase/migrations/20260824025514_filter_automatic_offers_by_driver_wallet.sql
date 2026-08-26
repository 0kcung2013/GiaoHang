-- Automatic offers are sent only to drivers whose completed wallet ledger
-- can cover the order advance. accept_order keeps the authoritative recheck.
CREATE OR REPLACE FUNCTION private.dispatch_next_order_offer_unbounded(
  p_order_id uuid,
  p_radius_meters double precision DEFAULT 3000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  offer_order public.orders%ROWTYPE;
  candidate record;
  v_now timestamptz := clock_timestamp();
  excluded_drivers jsonb;
  offer_deadline timestamptz;
BEGIN
  SELECT *
  INTO offer_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN RETURN NULL; END IF;

  IF COALESCE(offer_order.note, '') = 'FREEPICK_DEMO_PERSISTENT' THEN
    UPDATE public.orders
    SET offered_driver_id = NULL,
        offer_expires_at = NULL,
        status_note = NULL
    WHERE id = p_order_id;
    RETURN NULL;
  END IF;

  IF offer_order.driver_id IS NOT NULL
     OR offer_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR offer_order.assignment_timed_out_at IS NOT NULL THEN
    RETURN NULL;
  END IF;

  excluded_drivers := COALESCE(offer_order.rejected_by, '[]'::jsonb);

  IF offer_order.assignment_expires_at <= v_now THEN
    IF offer_order.offered_driver_id IS NOT NULL
       AND NOT (excluded_drivers ? offer_order.offered_driver_id::text) THEN
      excluded_drivers := excluded_drivers
        || pg_catalog.jsonb_build_array(offer_order.offered_driver_id::text);
    END IF;
    UPDATE public.orders
    SET assignment_timed_out_at = v_now,
        offered_driver_id = NULL,
        offer_expires_at = NULL,
        rejected_by = excluded_drivers,
        status_note = 'Không có tài xế nhận đơn trong vòng 15 phút.'
    WHERE id = p_order_id AND assignment_timed_out_at IS NULL;
    IF FOUND THEN
      INSERT INTO public.order_status_logs(
        order_id, status, title, description, logged_by
      ) VALUES (
        p_order_id, offer_order.status, 'Chưa tìm thấy tài xế',
        'Không có tài xế nhận đơn trong vòng 15 phút.', NULL
      );
    END IF;
    RETURN NULL;
  END IF;

  IF offer_order.offered_driver_id IS NOT NULL
     AND offer_order.offer_expires_at > v_now THEN
    RETURN offer_order.offered_driver_id;
  END IF;

  IF offer_order.offered_driver_id IS NOT NULL THEN
    IF NOT (excluded_drivers ? offer_order.offered_driver_id::text) THEN
      excluded_drivers := excluded_drivers
        || pg_catalog.jsonb_build_array(offer_order.offered_driver_id::text);
    END IF;
    INSERT INTO public.order_status_logs(
      order_id, status, title, description, logged_by
    ) VALUES (
      p_order_id, offer_order.status, 'Lời mời tài xế hết hạn',
      'Tài xế không phản hồi lời mời trong vòng 45 giây.', NULL
    );
    UPDATE public.orders
    SET rejected_by = excluded_drivers,
        offered_driver_id = NULL,
        offer_expires_at = NULL
    WHERE id = p_order_id;
  END IF;

  FOR candidate IN
    WITH candidate_distances AS (
      SELECT
        driver_profile.user_id,
        public.ST_Distance(
          public.ST_SetSRID(
            public.ST_MakePoint(
              driver_profile.current_lng,
              driver_profile.current_lat
            ),
            4326
          )::public.geography,
          public.ST_SetSRID(
            public.ST_MakePoint(
              offer_order.pickup_lng,
              offer_order.pickup_lat
            ),
            4326
          )::public.geography
        ) AS distance_meters
      FROM public.drivers AS driver_profile
      WHERE driver_profile.is_available = true
        AND driver_profile.approval_status =
          'approved'::public.approval_status
        AND driver_profile.current_lat IS NOT NULL
        AND driver_profile.current_lng IS NOT NULL
        AND driver_profile.location_updated_at >=
          clock_timestamp() - interval '3 minutes'
        AND NOT (excluded_drivers ? driver_profile.user_id::text)
        AND COALESCE(
          (
            SELECT sum(wallet_tx.available_delta)
            FROM public.driver_wallet_transactions AS wallet_tx
            WHERE wallet_tx.driver_id = driver_profile.user_id
              AND wallet_tx.status = 'completed'
          ),
          0
        ) >= offer_order.driver_advance_amount
        AND NOT EXISTS (
          SELECT 1 FROM public.orders AS active_order
          WHERE active_order.driver_id = driver_profile.user_id
            AND active_order.status IN (
              'assigned'::public.order_status,
              'picking_up'::public.order_status,
              'delivering'::public.order_status
            )
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.orders AS active_offer
          WHERE active_offer.id <> p_order_id
            AND active_offer.offered_driver_id = driver_profile.user_id
            AND active_offer.driver_id IS NULL
            AND active_offer.assignment_timed_out_at IS NULL
            AND active_offer.status IN (
              'pending'::public.order_status,
              'confirmed'::public.order_status
            )
            AND active_offer.offer_expires_at > clock_timestamp()
        )
        AND public.ST_DWithin(
          public.ST_SetSRID(
            public.ST_MakePoint(
              driver_profile.current_lng,
              driver_profile.current_lat
            ),
            4326
          )::public.geography,
          public.ST_SetSRID(
            public.ST_MakePoint(
              offer_order.pickup_lng,
              offer_order.pickup_lat
            ),
            4326
          )::public.geography,
          LEAST(GREATEST(p_radius_meters, 1), 50000)
        )
    )
    SELECT ranked.user_id, ranked.distance_meters
    FROM candidate_distances AS ranked
    ORDER BY ranked.distance_meters ASC, ranked.user_id ASC
  LOOP
    BEGIN
      offer_deadline := LEAST(
        clock_timestamp() + interval '45 seconds',
        offer_order.assignment_expires_at
      );
      UPDATE public.orders
      SET offered_driver_id = candidate.user_id,
          offer_expires_at = offer_deadline,
          rejected_by = excluded_drivers,
          status_note = NULL
      WHERE id = p_order_id
        AND driver_id IS NULL
        AND offered_driver_id IS NULL
        AND assignment_timed_out_at IS NULL
        AND assignment_expires_at > clock_timestamp()
        AND status IN (
          'pending'::public.order_status,
          'confirmed'::public.order_status
        );
      IF FOUND THEN
        INSERT INTO public.notifications(
          user_id, title, body, type, is_read, order_id
        ) VALUES (
          candidate.user_id,
          'Đơn giao hàng mới',
          pg_catalog.format(
            'Đơn %s đang chờ bạn nhận. Điểm lấy: %s',
            offer_order.tracking_code,
            offer_order.pickup_address
          ),
          'order_update', false, p_order_id
        );
        INSERT INTO public.order_status_logs(
          order_id, status, title, description, logged_by
        ) VALUES (
          p_order_id,
          offer_order.status,
          'Đã gửi lời mời tài xế',
          pg_catalog.format(
            'Hệ thống đã gửi lời mời trong 45 giây cho tài xế gần nhất (%s m).',
            pg_catalog.round(COALESCE(candidate.distance_meters, 0))::text
          ),
          NULL
        );
        RETURN candidate.user_id;
      END IF;
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;
    END;
  END LOOP;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.dispatch_next_order_offer_unbounded(
  uuid,
  double precision
) FROM PUBLIC, anon, authenticated;
