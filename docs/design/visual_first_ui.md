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

- Header không có lời chào: giữ Hỗ trợ, thông báo và avatar/tài khoản.
- Hero gồm hình giao hàng, một tiêu đề ngắn và một điểm vào luồng tạo đơn.
- Ưu tiên thẻ “điểm lấy → điểm giao” hơn đoạn mô tả dịch vụ.
- Tối đa 3 quick actions bằng icon; không cần heading nếu nhãn đã rõ.
- Không hiển thị khối marketing/cam kết dịch vụ khi không hỗ trợ quyết định tức thời.
- Hero chibi luôn ở trên; nếu có đơn hoạt động, thẻ trạng thái đặt sau quick
  actions và thay hoàn toàn danh sách “Giao gần đây”.
- Lịch sử giao hàng chỉ hiển thị ở tab Đơn hàng, không lặp lại trên Trang chủ.

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

### Onboarding

- Full-screen gradient: `primary` → navy sáng hơn.
- Text màu `textOnDark`, illustration dùng Lottie hoặc asset có semantic rõ ràng.
- Page indicator dạng pill, màu `accent`.

### Login

- Customer dùng nền `bgLight`; đăng nhập/đăng ký Driver dùng nền trắng `bgCard`,
  chữ navy, ô nhập `bgLight` và nút cam theo theme chính của app.
  Form email/mật khẩu là luồng chính; nhãn luôn hiển thị, có hiện/ẩn mật khẩu.
  Driver dùng logo nhỏ và bố cục form đơn giản, không có banner minh họa.
- Google button là phương thức bổ sung, màu trắng với `border` và `shadow.subtle`.
- Giữ validation, trạng thái loading/lỗi và khả năng nhập bằng bàn phím.

### Register

- Giữ lựa chọn Customer/Driver, các trường và quy tắc validation hiện có.
- Với Driver, hành động tiếp tục mở wizard; với Customer, hành động đăng ký hoàn tất luồng hiện có.
- Đảm bảo form dùng được trên màn hình ngắn khi bàn phím mở, có autofill, focus và thông báo lỗi rõ ràng.
- Driver App có wizard riêng 5 bước: Tài khoản / Cá nhân / Phương tiện / Giấy tờ / Xác nhận.
  Giữ quy tắc prefill và validation; thanh tiến độ mảnh, lỗi cạnh mục cần sửa,
  ảnh giấy tờ dùng hàng gọn có thumbnail và đổi ảnh. Nút tiếp tục nằm dưới vùng nội dung cuộn.

### Driver Home

- Background `bgDark`; trạng thái online là control nổi bật nhất.
- Không dùng khối chào tên hoặc đoạn mô tả trạng thái; control nhận đơn phải tự
  giải thích bằng icon, màu và nhãn ngắn.
- Đơn chờ nhận dùng `bgDarkCard` và dấu nhấn `accent`.
- Bản đồ chiếm ưu tiên khi đang giao; controls đặt overlay và không che route.

### Driver Incoming Offer

- Lời mời nhận đơn phủ toàn màn hình trên mọi tab, drawer và màn hình phụ đang mở.
  Dùng nền `bgCard`, chữ navy và CTA cam theo hướng giao diện đã duyệt.
- Thứ tự đọc: Đơn mới + mã đơn → thu nhập dự kiến → COD/khoản giữ ví →
  khoảng cách hai chặng → điểm lấy và điểm giao. Lấy số tiền từ snapshot tài chính;
  chỉ hiện thời gian dự kiến khi đơn đã có dữ liệu. Giữ thông tin hàng hóa sau bước nhận đơn.
- Nội dung cuộn được; nút nhận kèm đồng hồ và nút Bỏ qua cố định trong SafeArea.
  Màn hình ngắn, chữ 160% và landscape vẫn phải chạm được cả hai thao tác.
- Bỏ qua dùng luồng chuyển đơn và xác nhận hạn mức từ chối hiện có. Nút back
  không tự đóng hoặc ngầm từ chối lời mời. Thời hạn lấy từ giờ server, không khởi động lại.
- Một lời mời chỉ có một màn hình và một lượt âm báo/rung; cập nhật snapshot
  không tạo lớp mới. Hết hạn hoặc bị rút thì đóng cả sheet của lời mời và trở lại
  màn hình trước đó. Nhận thành công mở đơn được backend xác nhận.
- Khi app ở nền/khóa màn hình, tiếp tục dùng cơ chế thông báo hiện có của hệ điều hành.

### Order Tracking

- Map full-screen với bottom sheet.
- Route `routeLine`, pickup `markerPickup`, drop `markerDrop`.
- Driver marker có icon hoặc pulse; không chỉ phân biệt bằng màu.
- Bottom sheet ưu tiên ETA, tài xế và trạng thái; chi tiết khác mở theo nhu cầu.

### Admin Dashboard

- Admin ưu tiên tổng quan hệ thống, phê duyệt tài xế và quản trị tài khoản.
- CSKH quyết định xử lý sự cố, không phân mức độ hoặc chuyển Admin theo mức độ.
- Menu chính gồm tổng quan, phê duyệt tài xế và người dùng. Đơn hàng, sự cố,
  hành trình và giao dịch nằm trong nhóm tra cứu phụ.
- CSKH có tab Người dùng, được vô hiệu hóa Customer/Driver kèm thời hạn và lý do.
  Admin xem cùng nhật ký, điều chỉnh thời hạn hoặc gỡ với lý do mới.
- Vô hiệu hóa tài khoản là quyết định độc lập với khóa nhận đơn tự động. Hiển thị
  trạng thái, thời hạn, lý do, người xử lý và lịch sử; không thêm nhãn mức độ.
- Trang tổng quan đặt KYC, hồ sơ thay đổi và tài khoản vô hiệu hóa trước số liệu.
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
