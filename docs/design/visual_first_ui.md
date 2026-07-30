# Visual-first UI Rules

Tài liệu này là phần bắt buộc của design system trong `DESIGN.md`. Mọi UI mới
hoặc UI được thiết kế lại phải đọc cả hai tài liệu.

## Hướng thiết kế

**Visual-first minimal utility**: ưu tiên hình ảnh, icon và khoảng trắng để người
dùng hiểu thao tác chính trong một giây. Không biến màn hình chức năng thành
trang marketing có nhiều đoạn mô tả.

## Ngân sách nội dung

- Mỗi màn hình chỉ có một hành động chính nổi bật.
- Không dùng lời chào theo thời gian hoặc câu “Xin chào” trong header.
- Hero dùng tiêu đề tối đa 5 từ, tối đa 2 dòng.
- Dòng mô tả phụ là tùy chọn; nếu có, tối đa 12 từ và một dòng.
- Tối đa 3 hành động nhanh trong vùng nhìn đầu tiên.
- Không thêm tiêu đề section nếu icon và nội dung đã tự giải thích.
- Không lặp lại cùng một ý ở hero, CTA và phần mô tả.
- Thông tin chi tiết, hướng dẫn và tùy chọn nâng cao dùng progressive disclosure:
  mở bottom sheet, màn hình chi tiết hoặc trạng thái mở rộng khi người dùng cần.
- Nội dung nghiệp vụ bắt buộc như địa chỉ, trạng thái, giá và lỗi không được ẩn
  chỉ để đạt mục tiêu ít chữ.

## Hình minh họa và icon

- Dùng hình minh họa cho hero, onboarding và empty state khi hình giúp nhận diện
  tác vụ nhanh hơn chữ.
- Hình hero không chứa text, logo hoặc CTA raster; Flutter phải render chữ và
  nút để đảm bảo sắc nét, localization và Dynamic Type.
- Hình có subject ở một phía phải chừa negative space cho nội dung ở phía còn lại.
- Mọi hình có ý nghĩa cần `semanticLabel`; hình trang trí phải được loại khỏi
  semantics.
- Khai báo kích thước/aspect ratio để tránh layout shift; ảnh lớn cần `cacheWidth`
  phù hợp với kích thước hiển thị.
- Dùng `Icons.*` Material theo cùng một phong cách rounded. Không dùng emoji làm
  icon cấu trúc.
- Icon là tín hiệu bổ trợ, không thay thế nhãn cho hành động khó đoán.

## Bố cục và tương tác

- Mobile-first ở chiều rộng 375px; kiểm tra thêm text scale 1.6 và landscape.
- Touch target tối thiểu 48×48dp, khoảng cách giữa target tối thiểu 8dp.
- Dùng `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`; không tạo token
  màu và spacing cục bộ nếu token hiện có đáp ứng.
- Chỉ dùng một CTA primary trên màn hình; action phụ dùng icon card hoặc button
  ít nhấn mạnh hơn.
- Mỗi tap phải có ripple/highlight hoặc phản hồi trạng thái trong 150–300ms.
- Không dùng màu làm tín hiệu duy nhất; kết hợp icon, hình dạng hoặc text ngắn.
- Hỗ trợ `SafeArea`, Dynamic Type, reduced motion và thứ tự focus hợp lý.

## Quy tắc theo màn hình

### Customer Home

- Header không có lời chào: chỉ giữ thông báo và avatar/tài khoản.
- Hero gồm hình giao hàng, một tiêu đề ngắn và một điểm vào luồng tạo đơn.
- Ưu tiên thẻ “điểm lấy → điểm giao” hơn đoạn mô tả dịch vụ.
- Tối đa 3 quick actions bằng icon; không cần heading nếu nhãn đã rõ.
- Không hiển thị khối marketing/cam kết dịch vụ khi không hỗ trợ quyết định tức thời.
- Hero chibi luôn ở trên; nếu có đơn hoạt động, thẻ trạng thái đặt sau quick
  actions và thay hoàn toàn danh sách “Giao gần đây”.
- Lịch sử giao hàng chỉ hiển thị ở tab Đơn hàng, không lặp lại trên Trang chủ.

### Customer Orders

- Không lặp title/subtitle của tab trong content. Dùng visual header chibi không chữ,
  có semantic label và một icon action tạo đơn.
- Trên mobile, visual và control surface nằm chung một hàng trong toolbar cao 128dp;
  visual rộng 80–96dp, phần còn lại dành cho search + filter. Không stack hai khối
  full-width làm giảm vùng nhìn danh sách.
- Search + filter nằm trong control surface trắng có border và shadow rõ trên `bgLight`;
  input dùng nền `bgLight`, không để field hoà vào screen.
- Compact filter dùng bốn icon-only item 48dp; mọi item có tooltip và semantic label.
- Card đơn dùng ba lớp `bgLight` screen → `bgCard` card → `bgLight` detail panels.
  Card bắt buộc có border; featured card có accent border/status rail.
- Route dùng icon + `markerPickup`/`markerDrop`; địa chỉ, trạng thái, mã đơn, giá và
  người nhận là text nghiệp vụ bắt buộc, không được ẩn để đạt mục tiêu ít chữ.
- Toàn card tappable để mở chi tiết. Dùng chevron làm affordance; không lặp nhãn
  “Chi tiết” nếu semantics đã mô tả hành động.

### Onboarding

- Full-screen gradient: `primary` → navy sáng hơn.
- Text màu `textOnDark`, illustration dùng Lottie hoặc asset có semantic rõ ràng.
- Page indicator dạng pill, màu `accent`.

### Login

- Nền `bgLight`, nhiều khoảng trắng.
- Google button trắng, border `border`, shadow `subtle`.
- Logo/brand ở giữa, không thêm lợi ích dài dòng.

### Driver Home

- Background `bgDark`; trạng thái online là control nổi bật nhất.
- Không dùng khối chào tên hoặc đoạn mô tả trạng thái; control nhận đơn phải tự
  giải thích bằng icon, màu và nhãn ngắn.
- Đơn chờ nhận dùng `bgDarkCard` và dấu nhấn `accent`.
- Bản đồ chiếm ưu tiên khi đang giao; controls đặt overlay và không che route.

### Order Tracking

- Map full-screen với bottom sheet.
- Route `routeLine`, pickup `markerPickup`, drop `markerDrop`.
- Driver marker có icon hoặc pulse; không chỉ phân biệt bằng màu.
- Bottom sheet ưu tiên ETA, tài xế và trạng thái; chi tiết khác mở theo nhu cầu.

### Admin Dashboard

- Ưu tiên dữ liệu, cho phép mật độ cao hơn UI khách hàng.
- Grid metric 2 cột trên mobile và responsive trên web.
- Chart dùng khi trực quan hóa tốt hơn số đơn lẻ; table có trạng thái rõ ràng.

## Icon mapping

```dart
// Navigation
Icons.home_rounded
Icons.list_alt_rounded
Icons.map_rounded
Icons.history_rounded
Icons.person_rounded

// Order
Icons.add_location_alt_rounded
Icons.local_shipping_rounded
Icons.check_circle_rounded
Icons.cancel_rounded
Icons.access_time_rounded

// Driver / Admin
Icons.directions_car_rounded
Icons.navigation_rounded
Icons.radio_button_on_rounded
Icons.dashboard_rounded
Icons.people_alt_rounded
Icons.inventory_2_rounded
```

Kích thước chuẩn: 20px inline, 24px standalone, 28px header action.

## Anti-patterns

| Tránh | Dùng |
|---|---|
| Nhiều đoạn mô tả ở Trang chủ | Một headline ngắn + CTA |
| Lặp tiêu đề section không cần thiết | Icon và nhãn trực tiếp |
| Text hoặc logo nằm trong ảnh | Flutter text + asset không chữ |
| `Colors.*` hoặc hex rải rác | `AppColors.*` |
| Font/spacing hardcode | `AppTextStyles.*`, `AppSpacing.*` |
| Emoji làm icon | Material `Icons.*` |
| `CircularProgressIndicator` mặc định | Skeleton hoặc Lottie |
| `AlertDialog` mặc định | Custom dialog hoặc bottom sheet |
| UI không xử lý text scale | Layout co giãn, wrap hoặc progressive disclosure |
