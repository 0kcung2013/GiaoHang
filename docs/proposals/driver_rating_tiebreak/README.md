# Bản sửa ưu tiên rating khi bằng khoảng cách

Người dùng đã duyệt riêng và backend đã được áp dụng lên DATN ngày 2026-11-03.
Xem nghiệp vụ, cách triển khai, kiểm chứng và khôi phục tại
[tài liệu bàn giao](../../handoff/driver_assignment_rating.md).

- `backend.sql`: bản SQL đã duyệt, trùng nội dung migration
  `supabase/migrations/20261103072351_driver_rating_distance_tiebreak.sql`.
- `edge.patch`: bản patch đã áp dụng và triển khai cho hai Edge Functions.
- `rollback.sql`: định nghĩa RPC ngay trước thay đổi để đối chiếu khi khôi phục.

Regression hiện hành nằm ở `supabase/tests/driver_rating_tiebreak_regression.sql`.
Không áp dụng lại patch hoặc SQL ở thư mục này lên server đã cập nhật.

Tham khảo [PostgreSQL ORDER BY](https://www.postgresql.org/docs/17/queries-order.html)
và [kiểm thử Edge Functions](https://supabase.com/docs/guides/functions/unit-test).
