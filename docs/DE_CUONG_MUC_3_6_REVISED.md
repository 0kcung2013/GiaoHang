# 3. Mục tiêu nghiên cứu

## 3.1. Mục tiêu tổng quát

Xây dựng và đánh giá hệ thống quản lý giao hàng đa nền tảng, phục vụ khách hàng, tài xế, nhân viên chăm sóc khách hàng và quản trị viên.

Hệ thống hỗ trợ quy trình từ tạo đơn, tìm tài xế, giao nhận đến hoàn thành; đồng thời cung cấp bản đồ, theo dõi vị trí gần thời gian thực và ước tính thời gian giao hàng.

## 3.2. Mục tiêu cụ thể

- Xây dựng chức năng đăng ký, đăng nhập và phân quyền cho bốn nhóm người dùng: khách hàng, tài xế, nhân viên chăm sóc khách hàng và quản trị viên.

- Xây dựng quy trình quản lý đơn hàng từ khi tạo đơn đến khi hoàn thành hoặc hủy, bảo đảm các trạng thái được cập nhật đúng thứ tự và đúng quyền.

- Tích hợp bản đồ để chọn điểm lấy, điểm giao, hiển thị lộ trình và hỗ trợ tài xế quan sát các đơn phù hợp theo khu vực.

- Xây dựng cơ chế đề xuất đơn cho tài xế hợp lệ gần điểm lấy hàng trong bán kính mặc định 5 km và chuyển sang ứng viên tiếp theo khi tài xế từ chối.

- Bảo đảm một tài xế chỉ xử lý một đơn hàng đang hoạt động tại một thời điểm và ngăn nhiều tài xế cùng nhận thành công một đơn.

- Theo dõi vị trí tài xế gần thời gian thực và ước tính ETA dựa trên dữ liệu định tuyến, GPS, trạng thái đơn hàng và thời gian xử lý.

- Xây dựng chức năng tra cứu, tiếp nhận yêu cầu hỗ trợ và quản lý tài xế, tài khoản, đơn hàng cho nhân viên vận hành.

- Kiểm thử hệ thống theo các kịch bản giao hàng và đánh giá tính đúng đắn của phân công tài xế, tracking, phân quyền và ETA.

# 4. Nội dung và phạm vi nghiên cứu

## 4.1. Nội dung nghiên cứu

- Khảo sát quy trình giao hàng và nhu cầu của khách hàng, tài xế, nhân viên chăm sóc khách hàng và quản trị viên.

- Phân tích yêu cầu chức năng, mô hình dữ liệu, quyền truy cập và quy trình chuyển trạng thái đơn hàng.

- Thiết kế kiến trúc hệ thống, cơ sở dữ liệu, giao diện và cơ chế dùng chung thành phần giữa các ứng dụng.

- Xây dựng các mô-đun xác thực, quản lý đơn hàng, quản lý tài xế, hỗ trợ khách hàng và quản trị hệ thống.

- Tích hợp bản đồ, định vị GPS, dịch vụ định tuyến và cơ chế đồng bộ dữ liệu gần thời gian thực.

- Xây dựng và đánh giá cơ chế tìm tài xế, đề xuất hoặc chuyển đơn, nhận đơn từ bản đồ và ước tính ETA.

- Thực hiện kiểm thử đơn vị, kiểm thử tích hợp và kiểm thử luồng giao hàng hoàn chỉnh trên dữ liệu thử nghiệm.

## 4.2. Phạm vi nghiên cứu

Hệ thống gồm Delivery App dành cho khách hàng và tài xế trên Android/iOS, cùng Operations Web dành cho nhân viên chăm sóc khách hàng và quản trị viên.

Hai ứng dụng được tổ chức trong một monorepo, dùng chung Supabase, mô hình miền, cấu hình và design system, nhưng có thể được build và triển khai độc lập.

Mỗi tài xế chỉ được xử lý một đơn hàng đang hoạt động tại một thời điểm. Đề tài chưa nghiên cứu giao nhiều đơn đồng thời hoặc tối ưu VRP nhiều điểm giao.

Cơ chế đề xuất tự động chỉ xét tài xế đã được duyệt, đang sẵn sàng, không có đơn hoạt động và có vị trí GPS còn hiệu lực trong bán kính mặc định 5 km.

Ứng viên được sắp xếp theo khoảng cách; mã người dùng được dùng để phân xử khi khoảng cách bằng nhau. Dùng rating hoặc số đơn đã giao để thay đổi thứ tự.

Tài xế có thể thay đổi vùng bản đồ để khảo sát đơn, nhưng thao tác zoom không làm thay đổi bán kính 5 km của cơ chế đề xuất tự động.

ETA được ước tính từ dữ liệu OSRM, vị trí GPS, trạng thái đơn và thời gian xử lý. Đề tài chưa sử dụng học máy hoặc dữ liệu giao thông trực tiếp để dự đoán ETA.

Chức năng chăm sóc khách hàng giới hạn ở tra cứu đơn, tiếp nhận yêu cầu và theo dõi kết quả xử lý.

Đề tài chưa bao gồm hoàn tiền, khiếu nại tài chính hoàn chỉnh, giao nhiều đơn hoặc triển khai thương mại quy mô lớn.

# 5. Phương pháp nghiên cứu và công nghệ dự kiến sử dụng

## 5.1. Phương pháp nghiên cứu

- Khảo sát và phân tích quy trình giao hàng để xác định tác nhân, yêu cầu nghiệp vụ, dữ liệu và các tình huống sử dụng chính.

- Áp dụng phương pháp phân tích, thiết kế hệ thống để xây dựng kiến trúc, mô hình dữ liệu, ma trận phân quyền và state machine của đơn hàng.

- Phát triển theo từng mô-đun, kiểm thử độc lập trước khi tích hợp thành luồng giao hàng hoàn chỉnh.

- Sử dụng quy tắc khoảng cách và điều kiện hợp lệ để xây dựng cơ chế tìm tài xế; dùng transaction và constraint để xử lý yêu cầu đồng thời.

- Thực hiện kiểm thử đơn vị, tích hợp và end-to-end đối với luồng tạo đơn, nhận đơn, chuyển trạng thái, tracking và hoàn thành giao hàng.

- Đánh giá ETA bằng cách so sánh thời gian dự kiến với thời gian thực tế trên dữ liệu thử nghiệm; ghi nhận sai số và các trường hợp dịch vụ định tuyến gặp lỗi.

## 5.2. Công nghệ dự kiến sử dụng

- Flutter và Dart: xây dựng Delivery App và Operations Web trong một monorepo.

- Riverpod và GoRouter: quản lý trạng thái, điều hướng và kiểm soát truy cập giao diện theo vai trò.

- Supabase Auth: xác thực người dùng và quản lý phiên đăng nhập.

- PostgreSQL và PostGIS: lưu dữ liệu nghiệp vụ, thực hiện transaction, ràng buộc dữ liệu và truy vấn khoảng cách địa lý.

- Supabase Realtime: đồng bộ trạng thái đơn hàng và vị trí tài xế giữa các ứng dụng.

- Supabase Storage và Edge Functions: lưu hình ảnh và xử lý các nghiệp vụ cần thực hiện an toàn ở phía máy chủ.

- Row Level Security và RPC: kiểm soát quyền truy cập, bảo vệ dữ liệu và thực hiện các thao tác nghiệp vụ nguyên tử.

- Upstash Redis: lưu tạm vị trí GPS mới nhất và hỗ trợ hàng đợi dữ liệu tracking; PostgreSQL vẫn là nơi lưu dữ liệu lâu dài.

- flutter_map và OpenStreetMap: hiển thị bản đồ, vị trí và lộ trình giao hàng.

- Geolocator và OSRM: thu thập vị trí thiết bị, tính tuyến đường, khoảng cách và thời lượng di chuyển.

# 6. Sản phẩm dự kiến

- Delivery App cho Android/iOS, cung cấp chức năng tạo và theo dõi đơn cho khách hàng, cùng chức năng nhận và thực hiện giao hàng cho tài xế.

- Operations Web phục vụ nhân viên chăm sóc khách hàng và quản trị viên trong việc tra cứu, hỗ trợ và quản lý hoạt động giao hàng.

- Hệ thống backend dùng chung gồm cơ sở dữ liệu, phân quyền, dịch vụ thời gian thực, lưu trữ và các hàm xử lý nghiệp vụ.

- Các package dùng chung về mô hình miền, cấu hình và design system cho hai ứng dụng.

- Kết quả kiểm thử chức năng, phân quyền, xử lý đồng thời, tracking và sai số ETA.

- Mã nguồn và tài liệu mô tả kiến trúc, cơ sở dữ liệu, cài đặt, vận hành, kiểm thử và đánh giá hệ thống.
