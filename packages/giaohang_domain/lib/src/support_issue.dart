/// Stable subjects reuse the existing ticket subject; no persisted UI checklist.
enum SupportIssue {
  recipientUnavailable('Không liên hệ được người nhận'),
  contact('Không thể liên lạc'),
  delay('Giao hàng chậm'),
  cargo('Hàng hóa có vấn đề'),
  payment('Thanh toán hoặc phí'),
  safety('An toàn hoặc đáng ngờ'),
  other('Vấn đề khác');

  const SupportIssue(this.subject);
  final String subject;

  static SupportIssue fromSubject(String subject) => values.firstWhere(
    (issue) => issue.subject == subject.trim(),
    orElse: () => other,
  );

  String get participantHint => switch (this) {
    recipientUnavailable =>
      'Kiểm tra số điện thoại và địa chỉ giao. Cho CSKH biết bạn đã liên hệ lúc nào, bằng cách nào và hàng đang ở đâu. Không tự để hàng lại khi chưa thống nhất phương án.',
    contact =>
      'Cho biết bên cần liên hệ, thời điểm và cách bạn đã thử liên hệ.',
    delay => 'Cho biết mốc thời gian bạn đang chờ và tình hình hiện tại.',
    cargo =>
      'Mô tả hàng bị thiếu hoặc hư hỏng và thời điểm phát hiện. Có thể bổ sung ảnh trong luồng báo cáo sự cố khi cần.',
    payment =>
      'Nêu khoản thu cần kiểm tra và số tiền thực tế. Không gửi mã OTP hoặc thông tin thẻ.',
    safety =>
      'Ưu tiên an toàn của bạn. Mô tả tình trạng hiện tại và vị trí cần hỗ trợ.',
    other =>
      'Mô tả vấn đề và điều bạn cần CSKH hỗ trợ. Mã đơn đã được đính kèm.',
  };

  List<String> get verification => switch (this) {
    recipientUnavailable => const [
      'Đối chiếu số người nhận, địa chỉ giao và các lần liên hệ.',
      'Xác minh hàng đã lấy chưa, ai đang giữ hàng và vị trí hiện tại.',
      'Liên hệ riêng khách hàng và tài xế để thống nhất tiếp tục giao, hoàn hoặc bàn giao theo luồng hiện có.',
    ],
    contact => const [
      'Xác minh bên cần liên hệ và các lần liên hệ.',
      'Trao đổi riêng với từng bên; không sao chép nội dung kênh khác.',
    ],
    delay => const [
      'Đối chiếu trạng thái đơn, mốc thời gian và vị trí mới nhất.',
      'Hỏi nguyên nhân từ tài xế và thông báo tình hình cho khách.',
    ],
    cargo => const [
      'Đối chiếu ảnh nhận/giao, mô tả và thời điểm phát hiện.',
      'Thu thập bằng chứng hai bên; chuyển sự cố nếu cần can thiệp.',
    ],
    payment => const [
      'Đối chiếu phương thức thanh toán, phí đơn và giao dịch.',
      'Chuyển người có quyền nếu cần điều chỉnh; chỉ xác nhận hoàn tiền khi có giao dịch xác nhận.',
    ],
    safety => const [
      'Xác minh tình trạng hiện tại và nhu cầu hỗ trợ khẩn cấp.',
      'Chuyển sự cố và Admin theo quyền hiện có; không tự kết luận lỗi tài xế.',
    ],
    other => const ['Xác định vấn đề, thông tin còn thiếu và bên cần liên hệ.'],
  };

  String get completionHint => switch (this) {
    recipientUnavailable =>
      'Ghi phương án đã thống nhất và kết quả giao/hoàn/bàn giao liên quan. Chỉ kết thúc khi công việc này hoàn tất.',
    cargo => 'Ghi kết luận dựa trên bằng chứng và bên đã được thông báo.',
    payment =>
      'Ghi kết quả đối soát và cách xử lý khoản thu; không suy đoán giao dịch.',
    safety =>
      'Hoàn tất quy trình sự cố nghiêm trọng trong phạm vi quyền được cấp.',
    _ =>
      'Ghi việc đã làm, kết quả và bên đã được thông báo. Không bắt buộc chờ giao xong nếu vấn đề đã được giải quyết.',
  };

  String replyTemplate({required bool forDriver}) => switch (this) {
    recipientUnavailable =>
      forDriver
          ? 'Bạn cho CSKH biết các lần đã liên hệ người nhận, hàng đang ở đâu và bạn đã đến đúng địa chỉ giao chưa nhé.'
          : 'Bạn vui lòng xác nhận số liên hệ, địa chỉ và thời gian người nhận có thể nhận hàng để CSKH phối hợp với tài xế.',
    delay =>
      forDriver
          ? 'Bạn cho CSKH biết vị trí hiện tại và nguyên nhân chậm để hỗ trợ phương án tiếp theo nhé.'
          : 'CSKH đang xác minh tình hình giao hàng. Bạn cho biết mốc thời gian đang chờ và nhu cầu hỗ trợ thêm nhé.',
    cargo =>
      'Bạn mô tả phần hàng bị thiếu hoặc hư hỏng và thời điểm phát hiện để CSKH đối chiếu bằng chứng nhé.',
    payment =>
      'Bạn cho biết khoản thu cần kiểm tra và số tiền thực tế để CSKH đối soát nhé.',
    safety =>
      'Bạn cho CSKH biết tình trạng hiện tại, vị trí và nhu cầu hỗ trợ khẩn cấp nhé.',
    _ => 'Bạn cho CSKH biết thêm tình hình hiện tại và điều cần hỗ trợ nhé.',
  };
}
