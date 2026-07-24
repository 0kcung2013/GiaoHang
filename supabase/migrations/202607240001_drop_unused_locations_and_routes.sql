-- =============================================================================
-- Cleanup bảng GPS/route không còn dùng bởi app Flutter
-- Ngày: 2026-07-24
--
-- Context:
--   - `routes`: Phase 3 VRP, app không đọc/ghi (đã drop ở 202607220001; chạy lại IF EXISTS).
--   - `locations`: log GPS cũ trong docs; code hiện dùng `driver_locations` + Redis queue.
--
-- An toàn:
--   - Chỉ DROP IF EXISTS.
--   - Không đụng PostGIS system catalogs.
--   - Không xóa `driver_locations` (history GPS đang dùng).
--
-- Trước khi apply (Dashboard SQL hoặc CLI):
--   1) Table Editor: xem `locations` / `routes` còn data cần giữ không.
--   2) Backup nếu môi trường production/demo quan trọng.
-- =============================================================================

-- 1) routes (VRP — unused)
DROP TABLE IF EXISTS public.routes CASCADE;

-- 2) locations (legacy GPS log — replaced by driver_locations)
--    Nếu có policy/trigger gắn bảng này, CASCADE gỡ kèm.
DROP TABLE IF EXISTS public.locations CASCADE;

-- 3) (Tuỳ chọn) comment ghi nhận trong schema — không bắt buộc
COMMENT ON TABLE public.driver_locations IS
  'GPS history log (bulk insert / Redis flush). Replaces legacy public.locations.';
