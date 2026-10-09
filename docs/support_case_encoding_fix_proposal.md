# Sửa tiêu đề báo cáo CSKH tại nguồn — chờ duyệt Supabase

## Kết quả kiểm tra ngày 2026-10-08

Database có 14 báo cáo: 1 mới, 13 đã kết thúc. GH-10179 chỉ có một báo cáo
`fafacaa2-293d-4cc6-a16e-4e042d4c0b65`, không có yêu cầu hỗ trợ bị tạo trùng.
Phân trang Flutter đang dùng `id > cursor` cùng thứ tự giảm dần mặc định:
14 + 13 + ... + 1 = 105 mục, trong đó báo cáo mới bị đọc 14 lần.
Frontend đã sửa thứ tự ID tăng dần ở cả hai repository.

RPC `public.create_participant_risk_report` đang chứa bảy tiêu đề hệ thống bị
sai mã hóa UTF-8/Windows-1258. Hiện có một bản ghi chứa tiêu đề hỏng.
Model chung khôi phục chính xác các tiêu đề cũ đã biết để giao diện đọc được;
không chuyển mã nội dung tự do hoặc sửa dữ liệu lưu trên server.

## Thay đổi backend đề nghị duyệt riêng

1. Trong đúng RPC hiện có, thay duy nhất phần `report_title := CASE p_category`
   bằng các literal Unicode dưới đây; giữ nguyên signature, quyền, kiểm tra,
   khóa transaction, bằng chứng và luồng tạo báo cáo.
2. Sửa duy nhất tiêu đề hỏng của báo cáo GH-10179 bằng ID, với điều kiện tiêu đề
   cũ vẫn khớp. Không xóa báo cáo, tin nhắn, bằng chứng hoặc nhật ký.
3. Sau khi được duyệt, tạo migration theo CLI của repository, áp dụng và đọc
   lại định nghĩa RPC/bản ghi để xác minh. Chưa tạo hay chạy migration ở bước này.

```sql
report_title := CASE p_category
  WHEN 'delivery_delay' THEN U&'Giao h\00e0ng ch\1eadm'
  WHEN 'suspicious_address' THEN U&'\0110\1ecba ch\1ec9 b\1ea5t th\01b0\1eddng'
  WHEN 'contact_issue' THEN U&'Kh\00f4ng li\00ean l\1ea1c \0111\01b0\1ee3c'
  WHEN 'cargo_issue' THEN U&'H\00e0ng h\00f3a b\1ea5t th\01b0\1eddng'
  WHEN 'payment' THEN U&'V\1ea5n \0111\1ec1 thanh to\00e1n'
  WHEN 'safety' THEN U&'V\1ea5n \0111\1ec1 an to\00e0n'
  ELSE U&'S\1ef1 c\1ed1 kh\00e1c'
END;
```

Các literal SQL trên chỉ dùng ASCII để tránh lặp lại lỗi khi truyền văn bản
qua shell Windows. Phạm vi duyệt không bao gồm schema mới, RLS, GPS/R2 hoặc
thay đổi nghiệp vụ. Yêu cầu duyệt riêng xuất phát từ `AGENTS.md`, mục Supabase MCP.
