# ADR-0001: Tách Delivery App và Operations Web trong cùng monorepo

- Status: Accepted
- Date: 2026-08-01

## Context

Customer/Driver cần trải nghiệm mobile, bản đồ và GPS. Support/Admin cần bảng dữ liệu, KYC, ticket và dashboard trên màn hình lớn. Một Flutter app duy nhất làm vòng đời phát hành, dependency và router của hai nhóm vai trò dính vào nhau.

## Decision

Giữ một repository nhưng triển khai hai Flutter app:

- `apps/delivery_app`: Customer và Driver.
- `apps/operations_web`: Support và Admin.

Các Module có Leverage thực tế ở cả hai app được đặt trong `packages/`:

- `giaohang_design`: design tokens.
- `giaohang_domain`: domain models.
- `giaohang_config`: runtime configuration.

Supabase migrations và Edge Functions tiếp tục nằm ở repository root. Mỗi app có bootstrap/router riêng và role guard từ chối mặc định. RLS/RPC vẫn là lớp phân quyền quyết định.

## Consequences

- Mobile và Web có thể build/deploy độc lập.
- Admin/Support không còn nằm trong bundle và router của Delivery App.
- Shared Modules tạo locality cho model, theme và config dùng chung.
- Các lệnh Flutter phải chạy trong đúng app hoặc thông qua workspace tooling.
- OAuth redirect và deployment config phải được cấu hình riêng cho từng origin.
- Không tạo generic repository/interface cho đến khi có ít nhất hai Adapter thực sự.
