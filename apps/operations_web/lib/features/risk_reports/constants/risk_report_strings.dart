class RiskReportStrings {
  const RiskReportStrings._();

  static const title = 'Sự cố & vi phạm';
  static const supportTitle = 'Báo cáo người dùng';
  static const supportOperation = 'Xử lý đơn';
  static const cargoCancellationRequest = 'Yêu cầu hủy trước nhận hàng';
  static const cargoAcceptedResponsibility =
      'Tài xế đã nhận hàng. Không duyệt hủy vì hàng sai thông tin.';
  static const cargoVerificationHint =
      'Đối chiếu ảnh với loại hàng, kích thước và trọng lượng đã khai báo.';
  static const callVerification = 'Gọi xác thực';
  static const callDemo = 'Gọi demo';
  static const callAgain = 'Gọi lại demo';
  static const stopCall = 'Dừng gọi';
  static const demo = 'Demo';
  static const callDemoHint = 'Mô phỏng cuộc gọi, không gọi thật.';
  static const demoScenario = 'Kịch bản demo';
  static const noAnswer = 'Không nghe máy';
  static const lineBusy = 'Máy bận';
  static const answered = 'Có trả lời';
  static const ringing = 'Đang đổ chuông…';
  static const callStopped = 'Đã dừng cuộc gọi';
  static const contactCustomer = 'Chọn người cần gọi';
  static const verifyBeforeDecision = 'Xác minh báo cáo trước khi quyết định.';
  static const releaseDriver = 'Gỡ tài xế, giữ đơn';
  static const releaseDriverTitle = 'Gỡ tài xế khỏi đơn?';
  static const releaseDriverConfirm = 'Gỡ tài xế';
  static const releaseDriverExplanation =
      'Giữ đơn của khách. Sau khi xử lý nguyên nhân, cho phép phân công tài xế khác.';
  static const releaseDriverConfirmation =
      'Chỉ xác nhận khi đã kiểm tra báo cáo và bằng chứng. Đơn của khách được giữ lại, tài xế hiện tại được gỡ. CSKH cho phép phân công lại sau khi nguyên nhân đã được xử lý.';
  static const handoffDriver = 'Hủy đơn cho Tài xế';
  static const cancelDriverTitle = 'Hủy đơn cho Tài xế?';
  static const cancelDriverConfirmation =
      'Tài xế chưa nhận hàng sẽ được gỡ khỏi đơn ngay và nhận thông báo hủy. Đơn của khách tự động tìm tài xế mới.';
  // Retained for running debug sessions that were loaded before this workflow.
  static const cancelDriverInstruction =
      'CSKH yêu cầu hủy đơn cho tài xế hiện tại. Dừng giao hàng và liên hệ CSKH để bàn giao hàng. Tài xế được giải phóng sau khi xác nhận bàn giao hoàn tất.';
  static const orderAndContacts = 'Thông tin đơn và liên hệ';
  static const handlingHistory = 'Lịch sử xử lý';
  static const reportTab = 'Báo cáo';
  static const conversationTab = 'Trao đổi';
  static const reportClosed = 'Hồ sơ đã kết thúc.';
  static const acceptBeforeReply = 'Nhận xử lý để phản hồi người báo cáo.';
  static const subtitle = 'Tiếp nhận, xác minh và xử lý sự cố';
  static const create = 'Báo cáo sự cố';
  static const searchHint = 'Tìm mã đơn hoặc tiêu đề';
  static const relatedParties = 'Các bên liên quan';
  static const orderingCustomer = 'Khách đặt đơn';
  static const assignedDriver = 'Tài xế phụ trách';
  static const recipient = 'Người nhận hàng';
  static const missingProfile = 'Chưa có thông tin hồ sơ';
  static const missingPhone = 'Chưa có số điện thoại';
  static const noDriver = 'Chưa phân công tài xế';
  static const reporterMarker = 'Người gửi báo cáo';
  static const restrictedProfile =
      'Không có dữ liệu hồ sơ hoặc tài khoản chưa có quyền xem.';
  static const caseOverview = 'Thông tin xử lý';
  static const orderOverview = 'Đơn hàng liên quan';
  static const submittedAt = 'Gửi lúc';
  static const updatedAt = 'Cập nhật';
  static const owner = 'Phụ trách';
  static const responseDeadline = 'Hạn phản hồi';
  static const submittedContent = 'Nội dung báo cáo';
  static const all = 'Tất cả';
  static const noReports = 'Chưa có báo cáo sự cố';
  static const noResults = 'Không có báo cáo phù hợp';
  static const loadError = 'Không thể tải báo cáo sự cố.';
  static const retry = 'Thử lại';
  static const takeOwnership = 'Nhận xử lý';
  static const assignedToYou = 'Bạn đang phụ trách';
  static const unassigned = 'Chưa phân công';
  static const assignedToOther = 'Đang do nhân viên khác phụ trách';
  static const returnStatusLocked =
      'Chưa thể kết thúc: còn hoàn hoặc bàn giao hàng';
  static const evidenceTitle = 'Ảnh và vị trí';
  static const noAttachments = 'Không có ảnh hoặc vị trí đính kèm.';
  static const openMap = 'Mở bản đồ';
  static const resolvingAddress = 'Đang xác định địa chỉ...';
  static const addressUnavailable = 'Chưa thể xác định địa chỉ cụ thể';
  static const adminOverview = 'Tổng quan kiểm soát';
  static const adminOverviewHint = 'Tối đa 200 báo cáo cập nhật gần nhất';
  static const triageSla = 'SLA phân loại';
  static const activeCritical = 'Nghiêm trọng đang mở';
  static const awaitingDecision = 'Chờ quyết định vận hành';
  static const closedRate = 'Tỷ lệ kết thúc';
  static const categoryDistribution = 'Phân bố nhóm sự cố';
  static const noCategoryData = 'Chưa có dữ liệu phân loại.';
}
