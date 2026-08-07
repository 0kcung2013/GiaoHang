# Bài thuyết trình đề cương — 6 phút

Kính thưa thầy cô,

Đề tài em đăng ký là: “Xây dựng ứng dụng quản lý giao hàng thông minh hỗ trợ theo dõi vị trí thời gian thực và dự đoán thời gian giao hàng”.

Về mục tiêu nghiên cứu, đề tài hướng đến xây dựng và đánh giá một hệ thống quản lý giao hàng đa nền tảng.

Hệ thống hỗ trợ quy trình từ tạo đơn, tìm tài xế, giao nhận đến hoàn thành; đồng thời cung cấp bản đồ, theo dõi vị trí gần thời gian thực và ước tính thời gian giao hàng.

Hệ thống phục vụ bốn nhóm người dùng.

Khách hàng tạo và theo dõi đơn. Tài xế tiếp nhận đề xuất, nhận hoặc chuyển đơn, xem lộ trình, cập nhật trạng thái và chia sẻ GPS.

Nhân viên chăm sóc khách hàng tiếp nhận yêu cầu hỗ trợ. Quản trị viên quản lý tài khoản, tài xế và đơn hàng.

Về nội dung nghiên cứu, khi khách hàng tạo đơn, hệ thống lấy tọa độ điểm lấy hàng làm tâm tìm kiếm.

Hệ thống chỉ xét tài xế đã được duyệt, đang sẵn sàng, chưa có đơn hoạt động, có GPS còn hiệu lực và nằm trong bán kính mặc định 5 km.

Các ứng viên được sắp xếp theo khoảng cách địa lý đến điểm lấy hàng. Tài xế gần nhất được ưu tiên nhận đề xuất trước.

Trong phiên bản MVP, rating và số đơn đã giao chưa được dùng để thay đổi thứ tự. Nếu khoảng cách bằng nhau, hệ thống dùng mã người dùng làm tiêu chí cuối.

Nếu tài xế chuyển đơn, hệ thống ghi nhận người đó đã từ chối, loại khỏi danh sách ứng viên của đơn hiện tại và chuyển đề xuất đến tài xế phù hợp tiếp theo.

Nếu không còn ứng viên, đơn tiếp tục chờ để được tìm lại khi có tài xế phù hợp.

Mỗi tài xế chỉ được xử lý một đơn đang hoạt động tại một thời điểm.

Việc nhận đơn được xác nhận ở phía máy chủ bằng transaction và ràng buộc cơ sở dữ liệu. Vì vậy, nếu nhiều yêu cầu cùng nhận một đơn thì chỉ một yêu cầu thành công.

Sau khi tài xế nhận đơn, hệ thống hiển thị lộ trình đến điểm lấy hàng và điểm giao hàng.

Vị trí GPS của tài xế được cập nhật định kỳ và truyền đến khách hàng gần thời gian thực. Giao diện cũng hiển thị thời điểm cập nhật gần nhất để người dùng biết dữ liệu còn mới hay đã cũ.

ETA, tức thời gian giao hàng dự kiến, được tính từ thời lượng tuyến đường, vị trí GPS, trạng thái đơn và thời gian xử lý lấy, giao hàng.

ETA được cập nhật khi vị trí hoặc trạng thái đơn thay đổi. Việc tìm tài xế và tính ETA dựa trên quy tắc nghiệp vụ, dữ liệu định tuyến và GPS, không sử dụng trí tuệ nhân tạo.

Ngoài cơ chế đề xuất tự động, đề tài định hướng bổ sung bản đồ để tài xế quan sát các đơn đang chờ theo khu vực và chủ động lựa chọn đơn phù hợp.

Việc nhận đơn từ bản đồ vẫn phải được máy chủ kiểm tra quyền, trạng thái đơn và điều kiện một tài xế chỉ có một đơn hoạt động.

Về phạm vi nghiên cứu, hệ thống được xây dựng ở mức nguyên mẫu để nghiên cứu, kiểm thử và trình diễn, chưa hướng đến vận hành thương mại quy mô lớn.

Hệ thống gồm Delivery App dành cho khách hàng và tài xế trên Android, iOS; cùng Operations Web dành cho nhân viên chăm sóc khách hàng và quản trị viên.

Hai ứng dụng được tổ chức trong một monorepo, tức cùng một kho mã nguồn, dùng chung cơ sở dữ liệu và dịch vụ phía máy chủ nhưng vẫn có thể triển khai độc lập.

Đề tài giới hạn mỗi tài xế xử lý một đơn tại một thời điểm, chưa nghiên cứu giao nhiều đơn đồng thời hoặc tối ưu VRP nhiều điểm giao.

ETA chưa sử dụng học máy hoặc dữ liệu giao thông trực tiếp. Chức năng chăm sóc khách hàng giới hạn ở tra cứu đơn, tiếp nhận yêu cầu và theo dõi kết quả xử lý.

Đề tài chưa bao gồm thanh toán trực tuyến, hoàn tiền, khiếu nại tài chính hoàn chỉnh, chat và các chức năng thương mại nâng cao.

Về phương pháp nghiên cứu, trước tiên đề tài khảo sát quy trình giao hàng và phân tích nhu cầu của bốn nhóm người dùng.

Tiếp theo, đề tài thiết kế kiến trúc, cơ sở dữ liệu, phân quyền và quy trình chuyển trạng thái đơn; sau đó phát triển từng mô-đun và tích hợp thành luồng giao hàng hoàn chỉnh.

Hệ thống được đánh giá bằng kiểm thử đơn vị, kiểm thử tích hợp và kiểm thử toàn bộ quy trình.

Các kịch bản chính gồm tạo đơn, đề xuất tài xế gần nhất, chuyển đơn tuần tự, nhiều yêu cầu cùng nhận một đơn, theo dõi vị trí, cập nhật ETA và hoàn thành giao hàng.

ETA sẽ được đối chiếu với thời gian thực tế trên dữ liệu thử nghiệm. Sai số được ghi nhận để đánh giá kết quả và đề xuất cải thiện.

Về công nghệ dự kiến sử dụng, Flutter và Dart được dùng để xây dựng hai ứng dụng. Riverpod quản lý trạng thái, còn GoRouter hỗ trợ điều hướng và kiểm soát giao diện theo vai trò.

Supabase cung cấp xác thực, cơ sở dữ liệu, đồng bộ gần thời gian thực, lưu trữ và xử lý nghiệp vụ phía máy chủ.

PostgreSQL lưu dữ liệu nghiệp vụ lâu dài; PostGIS hỗ trợ truy vấn khoảng cách giữa tài xế và điểm lấy hàng.

Redis lưu tạm vị trí GPS mới nhất và hỗ trợ tìm nhanh tài xế theo tọa độ. Việc xác nhận phân công cuối cùng vẫn được thực hiện với PostgreSQL.

OpenStreetMap và flutter_map hiển thị bản đồ. Geolocator thu thập GPS, còn OSRM tính tuyến đường, quãng đường và thời lượng để hỗ trợ lộ trình và ETA.

Về sản phẩm dự kiến, đề tài tạo ra Delivery App, Operations Web và hệ thống backend dùng chung cho bốn nhóm người dùng.

Sản phẩm hỗ trợ tạo đơn, đề xuất tài xế, nhận hoặc chuyển đơn, theo dõi vị trí, cập nhật ETA và hoàn thành giao hàng.

Đề tài đồng thời cung cấp mã nguồn, tài liệu kiến trúc, mô tả cơ sở dữ liệu, kịch bản demo và kết quả kiểm thử hệ thống.

Em xin hết phần trình bày. Em cảm ơn thầy cô đã lắng nghe.
