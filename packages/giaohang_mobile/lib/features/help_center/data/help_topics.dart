import '../../../core/mobile_app_role.dart';
import '../models/help_topic.dart';

List<HelpTopic> helpTopicsFor(MobileAppRole role) =>
    role == MobileAppRole.driver ? driverHelpTopics : customerHelpTopics;

const customerHelpTopics = [
  HelpTopic(
    id: 'customer-create',
    group: 'Đặt & theo dõi đơn',
    question: 'Tạo đơn giao hàng như thế nào?',
    answer:
        'Tại Trang chủ, chọn Tạo đơn hoặc nhập điểm lấy và điểm giao. '
        'Điền thông tin người nhận, hàng hóa và thanh toán. Kiểm tra thông tin, '
        'phí hiển thị rồi xác nhận đặt đơn.',
  ),
  HelpTopic(
    id: 'customer-track',
    group: 'Đặt & theo dõi đơn',
    question: 'Xem vị trí tài xế và trạng thái đơn ở đâu?',
    answer:
        'Mở Theo dõi hoặc chọn đơn trong Đơn hàng để xem trạng thái và bản đồ. '
        'Vị trí chỉ cập nhật khi ứng dụng nhận được dữ liệu GPS của tài xế. '
        'Nếu vị trí lâu chưa cập nhật, hãy liên hệ tài xế hoặc CSKH.',
  ),
  HelpTopic(
    id: 'customer-no-driver',
    group: 'Đặt & theo dõi đơn',
    question: 'Chưa tìm được tài xế thì làm gì?',
    answer:
        'Kiểm tra trạng thái tìm tài xế trong chi tiết đơn. Khi hết thời gian tìm, '
        'thực hiện lựa chọn mà ứng dụng hiển thị. Nếu cần kiểm tra thêm, '
        'chat với CSKH và chọn đúng đơn hàng.',
  ),
  HelpTopic(
    id: 'customer-contact',
    group: 'Giao nhận & sự cố',
    question: 'Liên hệ tài xế bằng cách nào?',
    answer:
        'Khi đơn đã có tài xế, mở chi tiết hoặc Theo dõi đơn và dùng nút '
        'gọi hoặc nhắn tin đang hiển thị. Nếu không liên lạc được, '
        'chọn Hỗ trợ trong đơn hoặc chat với CSKH.',
  ),
  HelpTopic(
    id: 'customer-cancel',
    group: 'Giao nhận & sự cố',
    question: 'Tôi muốn hủy đơn hàng thì làm sao?',
    answer:
        'Mở chi tiết đơn trong Đơn hàng. Nếu đơn còn được phép hủy, '
        'chọn Hủy đơn, nhập lý do và xác nhận. Nếu không có nút hủy hoặc '
        'đơn đang được xử lý sự cố, hãy liên hệ CSKH để được kiểm tra.',
  ),
  HelpTopic(
    id: 'customer-cargo',
    group: 'Giao nhận & sự cố',
    question: 'Hàng thiếu, hư hỏng hoặc giao không thành công?',
    answer:
        'Giữ lại ảnh hàng hóa và thông tin liên quan. Mở Hỗ trợ trong đơn '
        'để gửi đúng vấn đề, hoặc chat với CSKH và mô tả tình trạng. '
        'Theo dõi phản hồi trong hội thoại; việc xử lý cần được xác minh.',
  ),
  HelpTopic(
    id: 'customer-payment',
    group: 'Phí & thanh toán',
    question: 'Kiểm tra phí giao hàng và tiền COD ở đâu?',
    answer:
        'Xem phần thanh toán trong xác nhận đặt đơn và chi tiết đơn. '
        'Phí giao hàng, giá trị hàng và khoản người nhận cần trả được thể hiện '
        'theo phương thức thanh toán đã chọn. Nếu khoản thu chưa đúng, '
        'gửi mã đơn và thông tin thanh toán cho CSKH.',
  ),
  HelpTopic(
    id: 'customer-chat',
    group: 'Trao đổi với CSKH',
    question: 'Tiếp tục cuộc trò chuyện với CSKH ở đâu?',
    answer:
        'Chọn Chat với CSKH trong mục Hỗ trợ để tiếp tục hội thoại chung. '
        'Với yêu cầu gắn đơn, chọn Hỗ trợ về đơn hàng rồi mở hội thoại của đơn. '
        'Hội thoại đã kết thúc sẽ hiển thị lựa chọn hỗ trợ tiếp khi được phép.',
  ),
];

const driverHelpTopics = [
  HelpTopic(
    id: 'driver-available',
    group: 'Nhận & giao đơn',
    question: 'Bật nhận đơn mới như thế nào?',
    answer:
        'Mở menu và bật Trạng thái hoạt động để nhận đơn mới. '
        'Kiểm tra quyền vị trí và kết nối mạng. Nếu hệ thống đang tạm khóa '
        'nhận đơn, xem lý do và thời gian hiển thị trong ứng dụng.',
  ),
  HelpTopic(
    id: 'driver-offer',
    group: 'Nhận & giao đơn',
    question: 'Nhận hoặc bỏ qua lời mời giao hàng?',
    answer:
        'Xem điểm lấy, điểm giao, thu nhập và khoản giữ ví trên lời mời. '
        'Chọn Nhận đơn trong thời gian còn lại hoặc Bỏ qua theo hướng dẫn. '
        'Bỏ qua hoặc để hết thời gian nhận có thể tính vào giới hạn từ chối; '
        'hãy đọc thông báo xác nhận trước khi thao tác.',
  ),
  HelpTopic(
    id: 'driver-delivery',
    group: 'Nhận & giao đơn',
    question: 'Các bước lấy và giao hàng?',
    answer:
        'Mở đơn đã nhận và thực hiện lần lượt các bước ứng dụng hiển thị: '
        'đến điểm lấy, xác nhận nhận hàng, di chuyển đến điểm giao và hoàn tất giao. '
        'Kiểm tra hàng, khoản thu và bổ sung bằng chứng khi ứng dụng yêu cầu.',
  ),
  HelpTopic(
    id: 'driver-contact',
    group: 'Xử lý tình huống',
    question: 'Không liên lạc được người nhận thì làm gì?',
    answer:
        'Đánh dấu đến điểm giao, thử gọi và nhắn tin cho người nhận. '
        'Thực hiện thời gian chờ và yêu cầu bằng chứng hiển thị trong đơn. '
        'Nếu vẫn không giao được, gửi yêu cầu hỗ trợ và chờ hướng dẫn của CSKH.',
  ),
  HelpTopic(
    id: 'driver-return',
    group: 'Xử lý tình huống',
    question: 'Khi nào được hoàn hàng?',
    answer:
        'Gửi tình trạng không thể giao qua luồng hỗ trợ của đơn. '
        'Chờ CSKH xác nhận phương án và điểm trả, sau đó thực hiện các bước '
        'hoàn hàng trong ứng dụng. Nếu người nhận đồng ý nhận lại, dùng '
        'lựa chọn giao lại khi ứng dụng cho phép.',
  ),
  HelpTopic(
    id: 'driver-gps',
    group: 'Xử lý tình huống',
    question: 'GPS không cập nhật hoặc mất kết nối?',
    answer:
        'Bật định vị, kiểm tra quyền vị trí của ứng dụng và kết nối mạng. '
        'Trong khi giao hàng, giữ ứng dụng được phép hoạt động nền. '
        'Nếu chưa khắc phục được, chat với CSKH và nêu rõ đơn, vị trí '
        'hiện tại, tình trạng đang giữ hàng.',
  ),
  HelpTopic(
    id: 'driver-wallet',
    group: 'Ví & tài khoản',
    question: 'Tiền làm tin, COD và thu nhập được xem ở đâu?',
    answer:
        'Mở Ví & Thu nhập để xem số dư và giao dịch. Trước khi nhận đơn, '
        'kiểm tra tiền làm tin và khoản phải thu trên lời mời. Khi giao, '
        'thu đúng số tiền hiển thị trong đơn. Nếu có chênh lệch, '
        'gửi mã đơn và giao dịch liên quan cho CSKH.',
  ),
  HelpTopic(
    id: 'driver-lock',
    group: 'Ví & tài khoản',
    question: 'Vì sao tôi tạm thời không nhận được đơn mới?',
    answer:
        'Kiểm tra trạng thái hoạt động và thông báo trong ứng dụng. '
        'Hệ thống có thể tạm khóa nhận đơn mới theo quy định về từ chối '
        'lời mời hoặc giao muộn. Thời gian còn lại được hiển thị trong ứng dụng. '
        'Bạn vẫn tiếp tục xử lý đơn đang giao; liên hệ CSKH nếu cần kiểm tra.',
  ),
];
