# DATN — Hệ thống Giao Hàng Thông Minh

## Phạm vi và nguồn tham chiếu

Tài liệu này quy định ngôn ngữ thị giác và nguyên tắc tương tác cho hai Flutter app:
`apps/delivery_app` (Customer, Driver) và `apps/operations_web` (Support, Admin).
`AGENTS.md` quy định kiến trúc và phạm vi thay đổi; luồng, route và trạng thái đang chạy
phải được kiểm tra trong code của màn hình tương ứng trước khi thiết kế lại.

Các token đã biên dịch trong `packages/giaohang_design/lib/src/app_theme.dart` là nguồn
giá trị triển khai. Nếu ví dụ trong tài liệu lệch với code, dùng token trong code và cập
nhật tài liệu. `NavColors` và `OrderColors` vẫn hỗ trợ UI hiện có; không cần di chuyển
hàng loạt để làm một màn hình mới.

## Nguồn kỹ thuật

Kiến trúc, phạm vi database và quy tắc thay đổi nằm trong `AGENTS.md`.
Lệnh chạy và dependencies xem `README.md` cùng `pubspec.yaml` của từng app.
Tiến độ tính năng xem `ROADMAP.md`. Route, auth flow và form đăng ký phải được
đọc từ code hiện tại trước khi thiết kế UI; không suy ra hành vi từ mockup.

## Nguyên tắc thiết kế

- Dùng skill `giaohang-flutter-ui` và đọc `docs/design/visual_first_ui.md` trước khi thay đổi UI.
- Ưu tiên một hành động chính rõ ràng, thứ bậc thông tin dễ quét và hình ảnh phục vụ tác vụ.
- Customer/Driver ưu tiên thao tác nhanh trên mobile; Support/Admin ưu tiên đọc dữ liệu và xử lý công việc trên web.
- Thiết kế đầy đủ trạng thái: mặc định, focus, loading, rỗng, lỗi, thành công, disabled và phản hồi sau thao tác.
- Giữ các hành vi, validation, điều hướng, phân quyền và hợp đồng dữ liệu của màn hình hiện có khi yêu cầu chỉ đổi phần nhìn.
- Dùng token trong `app_theme.dart`; native Flutter widgets phải được tạo kiểu phù hợp với hệ thống và có trạng thái tương tác rõ.
- Kiểm tra viewport ngắn, bàn phím, text scale, thiết bị đích, tương phản, focus, semantics và thao tác chạm.
- Motion diễn tả chuyển trạng thái và phản hồi. Giảm hoặc bỏ hiệu ứng không thiết yếu khi người dùng yêu cầu giảm chuyển động.

---

## Design System

> **Aesthetic Direction**: _Clean Utility Premium_ — rõ thứ bậc, nhiều khoảng thở, bề mặt có chiều sâu vừa đủ và một điểm nhấn hành động. Ưu tiên nội dung nghiệp vụ đọc được nhanh trong điều kiện sử dụng thực tế.

---

### Color Palette

Tất cả màu định nghĩa trong `packages/giaohang_design/lib/src/app_theme.dart`:

```dart
class AppColors {
  // === Brand ===
  static const primary     = Color(0xFF0F1B2D); // Deep Navy — trust, authority
  static const accent      = Color(0xFFFF6B35); // Vibrant Orange — action, energy
  static const accentLight = Color(0xFFFFEDE6); // Orange tint — backgrounds

  // === Semantic ===
  static const success     = Color(0xFF22C55E); // Green — completed
  static const warning     = Color(0xFFF59E0B); // Amber
  static const error       = Color(0xFFEF4444); // Rose
  static const info        = Color(0xFF3B82F6); // Blue — map, links

  // === Backgrounds ===
  static const bgLight     = Color(0xFFFAFAFA); // Screen background (light)
  static const bgCard      = Color(0xFFFFFFFF); // Card surface
  static const bgWarm      = Color(0xFFFFF7F1); // Chibi/visual header surface
  static const bgDark      = Color(0xFF1E293B); // Dark surface (driver night mode)
  static const bgDarkCard  = Color(0xFF243447); // Dark card

  // === Text ===
  static const textPrimary   = Color(0xFF111827); // Headings, body
  static const textSecondary = Color(0xFF6B7280); // Subtitles, labels
  static const textMuted     = Color(0xFF9CA3AF); // Placeholder, hint
  static const textOnDark    = Color(0xFFF1F5F9); // Text trên nền tối
  static const textOnAccent  = Color(0xFFFFFFFF); // Text trên nút orange

  // === Border ===
  static const border        = Color(0xFFE5E7EB); // Divider, input border
  static const borderFocus   = Color(0xFF0F1B2D); // Input focused

  // === Map Markers ===
  static const markerPickup  = Color(0xFF3B82F6); // Điểm lấy hàng — Blue
  static const markerDrop    = Color(0xFFFF6B35); // Điểm giao hàng — Orange
  static const markerDriver  = Color(0xFF10B981); // Vị trí tài xế — Green
  static const routeLine     = Color(0xFF3B82F6); // Route line trên bản đồ
}
```

**Quy tắc dùng màu theo Role:**

| Role | Background | Accent | Tone |
|------|-----------|--------|------|
| Customer | `bgLight` | `accent` (orange) | Sáng, thân thiện |
| Driver | `bgDark` | `info` (blue) + `accent` | Tối, high-contrast |
| Admin | `bgLight` | `primary` (navy) | Professional, data-dense |

---

### Typography

Font giao diện chính: **Plus Jakarta Sans**. Mã đơn và dữ liệu đơn cách dùng kiểu
mono trong `AppTextStyles.mono`. Dùng style từ package chung để đồng bộ hai app;
phiên bản package được quản lý trong `pubspec.yaml`, không cố định tại đây.

Các style hiện có:

```dart
class AppTextStyles {
  static final _base = GoogleFonts.plusJakartaSans;

  // Display — màn hình onboarding, hero sections
  static final displayLarge  = _base(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2);
  static final displayMedium = _base(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25);

  // Heading — section titles, screen titles
  static final headingLarge  = _base(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static final headingMedium = _base(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);
  static final headingSmall  = _base(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);

  // Body — nội dung chính
  static final bodyLarge     = _base(fontSize: 15, fontWeight: FontWeight.w400, height: 1.6);
  static final bodyMedium    = _base(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);
  static final bodySmall     = _base(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);

  // Label — button, badge, chip
  static final labelLarge    = _base(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static final labelMedium   = _base(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static final labelSmall    = _base(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  // Mono — order ID, mã đơn, số liệu
  static final mono = GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500);
}
```

---

### Spacing & Layout

Base unit: **4px**. Dùng bội số của 4.

```dart
class AppSpacing {
  static const xs   =  4.0;
  static const sm   =  8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 20.0;
  static const xl2  = 24.0;
  static const xl3  = 32.0;
  static const xl4  = 40.0;
  static const xl5  = 48.0;

  // Screen padding horizontal
  static const screenH = 20.0;

  // Bottom nav safe area
  static const bottomNavHeight = 72.0;
}
```

**Border Radius:**
```dart
class AppRadius {
  static const xs   = BorderRadius.all(Radius.circular(6));
  static const sm   = BorderRadius.all(Radius.circular(8));
  static const md   = BorderRadius.all(Radius.circular(12));
  static const lg   = BorderRadius.all(Radius.circular(16));
  static const xl   = BorderRadius.all(Radius.circular(20));
  static const xl2  = BorderRadius.all(Radius.circular(24));
  static const full = BorderRadius.all(Radius.circular(999));
}
```

**Shadows:**
```dart
class AppShadow {
  static const subtle = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const elevated = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const accentGlow = [
    BoxShadow(color: Color(0x40FF6B35), blurRadius: 20, offset: Offset(0, 6)),
  ];
}
```

---

### Component Patterns

#### Button — Primary (CTA)

- Dùng `accent` và `textOnAccent`, chiều cao tối thiểu 52dp, bo góc theo `AppRadius`.
- Dùng button có `onPressed`, semantics, focus, phản hồi nhấn và trạng thái disabled/loading.
- Nhãn CTA nói rõ hành động; không dùng `Container` đơn thuần để giả làm nút.

#### Button — Secondary

- Dùng nền `bgLight`, viền `border`, độ bo cùng họ với CTA và độ nhấn thấp hơn.
- Có nhãn, vùng chạm, focus, trạng thái disabled và phản hồi nhấn tương đương CTA.

#### Card
```dart
Container(
  padding: const EdgeInsets.all(AppSpacing.lg),
  decoration: BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: AppRadius.lg,
    boxShadow: AppShadow.card,
  ),
)
```

#### Status Badge — Order Status
```dart
// Màu theo trạng thái đơn hàng
Color badgeColor(OrderStatus status) => switch (status) {
  OrderStatus.pending     => AppColors.warning,
  OrderStatus.confirmed   => AppColors.info,
  OrderStatus.assigned    => AppColors.info,
  OrderStatus.pickingUp   => AppColors.accent,
  OrderStatus.delivering  => AppColors.accent,
  OrderStatus.delivered   => AppColors.success,
  OrderStatus.cancelled   => AppColors.error,
};
```

#### Input Field

- Có label luôn nhận biết được, keyboard type, autofill và thứ tự focus phù hợp dữ liệu.
- Dùng `bgLight`, `border`, `borderFocus`, `AppRadius.md` và khoảng đệm từ `AppSpacing`.
- Lỗi validation xuất hiện cạnh field, dễ đọc và được thông báo cho công nghệ hỗ trợ.
- `textMuted` chỉ dùng cho gợi ý; thông tin bắt buộc dùng màu chữ đủ tương phản.

---

### Animation & Motion

Chọn `AppDuration` và `AppCurve` từ package chung theo mục đích của chuyển động:

- Tập trung vào phản hồi thao tác, thay đổi trạng thái và chuyển màn hình. Không tự động thêm hiệu ứng xuất hiện cho mọi card hoặc thành phần bản đồ.
- Loading phải cho thấy tác vụ còn đang chạy và chặn thao tác lặp phù hợp. Có thể dùng indicator, skeleton hoặc asset được tạo kiểu; không bắt buộc dùng Lottie.
- Tôn trọng cài đặt giảm chuyển động. Giữ chuyển động ngắn và tránh blur, shader hoặc ảnh động lớn nếu chưa kiểm tra hiệu năng.
- Chỉ rebuild vùng đang chuyển động; danh sách, bản đồ và provider không liên quan phải đứng ngoài vùng animation.

---

### Visual hierarchy, icons và screen rules

Xem tài liệu bắt buộc:
[`docs/design/visual_first_ui.md`](docs/design/visual_first_ui.md).

### Customer Orders — Đang xử lý và Lịch sử

- Header gọn gồm tìm kiếm, nút tạo đơn 48×48dp và hai tab có chữ: **Đang xử lý / Lịch sử**.
  Không lặp tiêu đề hoặc dùng hình trang trí chiếm chiều cao. Bố cục tự tăng chiều cao khi phóng chữ.
- Search và tab nằm trong `bgCard`, `AppRadius.xl`, viền `border`, shadow `subtle`;
  input dùng `bgLight`. Trạng thái chọn dùng `accentLight` và viền `accent`.
- Tab Đang xử lý là mặc định; giữ đơn hết thời gian tìm tài xế, đang hoàn hoặc đang xử lý sự cố
  để khách vẫn truy cập được hành động hiện có. Đơn đã giao, đã hủy, đã hoàn hàng nằm trong Lịch sử.
- Lịch sử mặc định tất cả thời gian, mới nhất trước. Lọc theo **ngày tạo đơn**:
  Tất cả / Hôm nay / 7 ngày qua / Tháng này / một ngày / khoảng ngày, tính cả ngày cuối.
  Bộ lọc ngày kết hợp tìm kiếm và trạng thái, hiển thị khoảng ngày đã chọn và cho phép bỏ lọc.
- Bộ lọc lịch sử cuộn cùng danh sách; nhóm theo ngày cho khoảng ngắn (tối đa 31 ngày),
  theo tháng cho tất cả lịch sử hoặc khoảng dài.
- Đơn đang xử lý giữ card chi tiết, đơn đầu có nhấn mạnh. Thẻ lịch sử phẳng, viền nhẹ,
  không ảnh lớn, không panel lồng nhau, không badge giá hoặc status rail.
- Thẻ lịch sử giữ mã đơn, icon + nhãn trạng thái, địa chỉ lấy/giao tối đa hai dòng,
  người nhận, ngày tạo, giá bằng chữ đậm. Ảnh và mô tả hàng xem trong chi tiết.
- Dùng `markerPickup`/`markerDrop` cho địa chỉ; không chỉ dùng màu để phân biệt trạng thái.
  Toàn card có phản hồi nhấn, semantics và mở luồng chi tiết hiện có.
- Dùng token chung; kiểm tra mobile 320/390dp, chữ 160%, trạng thái rỗng, lịch ngày và khoảng ngày.

## Tiêu chí xem lại UI

- So sánh với luồng đang chạy trước khi sửa: thao tác chính, validation, lỗi, loading, back navigation và kết quả sau submit.
- Xem màn hình đã render trên viewport đích và một viewport ngắn; với form, kiểm tra bàn phím mở và text scale lớn. Với web, kiểm tra thêm viewport rộng và thao tác bằng bàn phím.
- Kiểm tra tương phản, focus, semantics, vùng chạm và thông tin quan trọng không phụ thuộc duy nhất vào màu hoặc animation.
- Ghi lại điểm nào chưa kiểm tra được bằng thiết bị hoặc trình duyệt thực tế.
