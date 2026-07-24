import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/driver_kyc_storage_service.dart';
import 'driver_register_data.dart';
import 'driver_register_prefill.dart';

/// Wizard đăng ký tài xế (Phase A + KYC).
/// Nếu [prefill] đã có email/mật khẩu → bỏ qua bước Tài khoản, không nhập lại.
class DriverRegisterWizard extends StatefulWidget {
  const DriverRegisterWizard({super.key, this.prefill});

  final DriverRegisterPrefill? prefill;

  @override
  State<DriverRegisterWizard> createState() => _DriverRegisterWizardState();
}

class _DriverRegisterWizardState extends State<DriverRegisterWizard> {
  late final PageController _pageController;
  final _data = DriverRegisterData();
  final _auth = AuthService();
  final _storage = DriverKycStorageService();
  final _picker = ImagePicker();

  late int _step;
  late final bool _skipAccount;
  bool _loading = false;
  String? _error;

  static const _stepTitles = [
    'Tài khoản',
    'Cá nhân',
    'Phương tiện',
    'Giấy tờ',
    'Xác nhận',
  ];

  int get _firstStep => _skipAccount ? 1 : 0;
  int get _totalVisibleSteps => _skipAccount ? 4 : 5;
  int get _displayStepIndex => _skipAccount ? _step : _step + 1;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _data.email = p.email.trim();
      _data.password = p.password;
      _data.fullName = p.fullName.trim();
      _data.phone = p.phone.trim();
    }
    _skipAccount = p?.hasAccount ?? false;
    _step = _firstStep;
    _pageController = PageController(initialPage: _step);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile file) assign) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file != null) setState(() => assign(file));
  }

  bool _validateCurrentStep() {
    setState(() => _error = null);
    switch (_step) {
      case 0:
        if (!_data.email.contains('@') || !_data.email.contains('.')) {
          setState(() => _error = 'Email không hợp lệ');
          return false;
        }
        if (_data.password.length < 6) {
          setState(() => _error = 'Mật khẩu tối thiểu 6 ký tự');
          return false;
        }
        return true;
      case 1:
        if (_data.fullName.trim().isEmpty) {
          setState(() => _error = 'Vui lòng nhập họ tên');
          return false;
        }
        if (_data.phone.trim().length < 10) {
          setState(() => _error = 'Số điện thoại không hợp lệ');
          return false;
        }
        if (_data.avatarFile == null) {
          setState(() => _error = 'Vui lòng chọn ảnh đại diện');
          return false;
        }
        return true;
      case 2:
        if (_data.vehicleBrandModel.trim().isEmpty) {
          setState(() => _error = 'Vui lòng nhập hãng / model xe');
          return false;
        }
        if (_data.vehicleColor.trim().isEmpty) {
          setState(() => _error = 'Vui lòng nhập màu xe');
          return false;
        }
        if (_data.licensePlate.trim().isEmpty) {
          setState(() => _error = 'Vui lòng nhập biển số');
          return false;
        }
        return true;
      case 3:
        if (_data.idCardNumber.trim().length < 9) {
          setState(() => _error = 'Số CCCD không hợp lệ');
          return false;
        }
        if (_data.idCardFrontFile == null || _data.idCardBackFile == null) {
          setState(() => _error = 'Cần ảnh CCCD mặt trước và mặt sau');
          return false;
        }
        if (_data.driverLicenseNumber.trim().isEmpty) {
          setState(() => _error = 'Vui lòng nhập số GPLX');
          return false;
        }
        if (_data.driverLicenseFile == null) {
          setState(() => _error = 'Cần ảnh giấy phép lái xe');
          return false;
        }
        if (_data.vehiclePhotoFile == null) {
          setState(() => _error = 'Cần ảnh xe (thấy rõ biển số)');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: AppDuration.normal,
        curve: Curves.easeOutCubic,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step <= _firstStep) return;
    setState(() {
      _step--;
      _error = null;
    });
    _pageController.animateToPage(
      _step,
      duration: AppDuration.normal,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Auth trước để có uid upload storage
      final user = await _auth.signUpDriverAuth(
        email: _data.email.trim(),
        password: _data.password,
        fullName: _data.fullName.trim(),
        phone: _data.phone.trim(),
      );

      if (user == null) {
        throw Exception('Đăng ký thất bại');
      }

      final uid = user.id;

      try {
        // 2) Upload ảnh KYC
        final avatarUrl = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.avatarFile!,
          kind: 'avatar',
        );
        final idFront = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.idCardFrontFile!,
          kind: 'id_front',
        );
        final idBack = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.idCardBackFile!,
          kind: 'id_back',
        );
        final licenseUrl = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.driverLicenseFile!,
          kind: 'license',
        );
        final vehicleUrl = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.vehiclePhotoFile!,
          kind: 'vehicle',
        );

        // 3) Một lần tạo profile + KYC đầy đủ
        await _auth.createDriverProfile(
          email: _data.email.trim(),
          fullName: _data.fullName.trim(),
          phone: _data.phone.trim(),
          vehicleType: _data.vehicleType,
          licensePlate: _data.licensePlate.trim(),
          vehicleBrandModel: _data.vehicleBrandModel.trim(),
          vehicleColor: _data.vehicleColor.trim(),
          avatarUrl: avatarUrl,
          idCardNumber: _data.idCardNumber.trim(),
          idCardFrontUrl: idFront,
          idCardBackUrl: idBack,
          driverLicenseNumber: _data.driverLicenseNumber.trim(),
          driverLicenseUrl: licenseUrl,
          vehiclePhotoUrl: vehicleUrl,
        );
      } catch (_) {
        await Supabase.instance.client.auth.signOut();
        rethrow;
      }

      if (!mounted) return;
      context.go('/driver-pending');
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already')) {
        setState(
          () => _error =
              'Email đã được đăng ký. Hãy chuyển sang tab Đăng nhập.',
        );
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = 'Đăng ký thất bại: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _displayStepIndex / _totalVisibleSteps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bước $_displayStepIndex/$_totalVisibleSteps · ${_stepTitles[_step]}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_skipAccount) ...[
            const SizedBox(height: 4),
            Text(
              'Đã dùng email đã nhập · ${_data.email}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: const Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _AccountStep(data: _data),
                _PersonalStep(
                  data: _data,
                  onPickAvatar: () => _pickImage((f) => _data.avatarFile = f),
                ),
                _VehicleStep(data: _data),
                _KycStep(
                  data: _data,
                  onPick: (kind) => _pickImage((f) {
                    switch (kind) {
                      case 'id_front':
                        _data.idCardFrontFile = f;
                      case 'id_back':
                        _data.idCardBackFile = f;
                      case 'license':
                        _data.driverLicenseFile = f;
                      case 'vehicle':
                        _data.vehiclePhotoFile = f;
                    }
                  }),
                ),
                _ConfirmStep(data: _data),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (_step > _firstStep)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _back,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Quay lại'),
                  ),
                ),
              if (_step > _firstStep) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _loading ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step == _stepTitles.length - 1
                              ? 'Gửi hồ sơ duyệt'
                              : 'Tiếp tục',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Steps (dark theme match driver-auth) ─────────────────────────────────────

InputDecoration _darkInput(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.07),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

const _fieldStyle = TextStyle(color: Colors.white, fontSize: 14);

class _AccountStep extends StatefulWidget {
  const _AccountStep({required this.data});
  final DriverRegisterData data;

  @override
  State<_AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<_AccountStep> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.data.email);
    _password = TextEditingController(text: widget.data.password);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _StepHint('Tạo tài khoản đăng nhập tài xế'),
        TextField(
          controller: _email,
          style: _fieldStyle,
          keyboardType: TextInputType.emailAddress,
          decoration: _darkInput('Email'),
          onChanged: (v) => widget.data.email = v,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          style: _fieldStyle,
          obscureText: true,
          decoration: _darkInput('Mật khẩu (tối thiểu 6 ký tự)'),
          onChanged: (v) => widget.data.password = v,
        ),
      ],
    );
  }
}

class _PersonalStep extends StatefulWidget {
  const _PersonalStep({required this.data, required this.onPickAvatar});
  final DriverRegisterData data;
  final VoidCallback onPickAvatar;

  @override
  State<_PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends State<_PersonalStep> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.data.fullName);
    _phone = TextEditingController(text: widget.data.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _StepHint('Thông tin cá nhân & ảnh chân dung'),
        Center(
          child: GestureDetector(
            onTap: () async {
              widget.onPickAvatar();
              // rebuild after parent setState from picker
              await Future<void>.delayed(const Duration(milliseconds: 300));
              if (mounted) setState(() {});
            },
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white12,
              backgroundImage: null,
              child: widget.data.avatarFile == null
                  ? const Icon(Icons.add_a_photo_rounded, color: Colors.white70)
                  : ClipOval(
                      child: FutureBuilder<Uint8List>(
                        future: widget.data.avatarFile!.readAsBytes(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const CircularProgressIndicator(
                              strokeWidth: 2,
                            );
                          }
                          return Image.memory(
                            snap.data!,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.data.avatarFile == null
              ? 'Chạm để chọn ảnh đại diện *'
              : 'Đã chọn ảnh đại diện',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          style: _fieldStyle,
          textCapitalization: TextCapitalization.words,
          decoration: _darkInput('Họ và tên (theo CCCD) *'),
          onChanged: (v) => widget.data.fullName = v,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          style: _fieldStyle,
          keyboardType: TextInputType.phone,
          decoration: _darkInput('Số điện thoại *'),
          onChanged: (v) => widget.data.phone = v,
        ),
      ],
    );
  }
}

class _VehicleStep extends StatefulWidget {
  const _VehicleStep({required this.data});
  final DriverRegisterData data;

  @override
  State<_VehicleStep> createState() => _VehicleStepState();
}

class _VehicleStepState extends State<_VehicleStep> {
  late final TextEditingController _model;
  late final TextEditingController _color;
  late final TextEditingController _plate;

  @override
  void initState() {
    super.initState();
    _model = TextEditingController(text: widget.data.vehicleBrandModel);
    _color = TextEditingController(text: widget.data.vehicleColor);
    _plate = TextEditingController(text: widget.data.licensePlate);
  }

  @override
  void dispose() {
    _model.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _StepHint('Thông tin xe giao hàng (khách sẽ thấy)'),
        DropdownButtonFormField<String>(
          initialValue: widget.data.vehicleType,
          dropdownColor: const Color(0xFF1E1645),
          style: _fieldStyle,
          decoration: _darkInput('Loại xe'),
          items: DriverRegisterData.vehicleTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => widget.data.vehicleType = v);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          style: _fieldStyle,
          decoration: _darkInput('Hãng / model (vd Honda Wave) *'),
          onChanged: (v) => widget.data.vehicleBrandModel = v,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _color,
          style: _fieldStyle,
          decoration: _darkInput('Màu xe *'),
          onChanged: (v) => widget.data.vehicleColor = v,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _plate,
          style: _fieldStyle,
          textCapitalization: TextCapitalization.characters,
          decoration: _darkInput('Biển số xe *'),
          onChanged: (v) => widget.data.licensePlate = v,
        ),
      ],
    );
  }
}

class _KycStep extends StatefulWidget {
  const _KycStep({required this.data, required this.onPick});
  final DriverRegisterData data;
  final void Function(String kind) onPick;

  @override
  State<_KycStep> createState() => _KycStepState();
}

class _KycStepState extends State<_KycStep> {
  late final TextEditingController _idNo;
  late final TextEditingController _licenseNo;

  @override
  void initState() {
    super.initState();
    _idNo = TextEditingController(text: widget.data.idCardNumber);
    _licenseNo = TextEditingController(text: widget.data.driverLicenseNumber);
  }

  @override
  void dispose() {
    _idNo.dispose();
    _licenseNo.dispose();
    super.dispose();
  }

  Future<void> _pick(String kind) async {
    widget.onPick(kind);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _StepHint('Giấy tờ KYC — chỉ admin xem, khách không thấy'),
        TextField(
          controller: _idNo,
          style: _fieldStyle,
          decoration: _darkInput('Số CCCD *'),
          onChanged: (v) => widget.data.idCardNumber = v,
        ),
        const SizedBox(height: 12),
        _ImagePickTile(
          label: 'CCCD mặt trước *',
          hasFile: widget.data.idCardFrontFile != null,
          onTap: () => _pick('id_front'),
        ),
        _ImagePickTile(
          label: 'CCCD mặt sau *',
          hasFile: widget.data.idCardBackFile != null,
          onTap: () => _pick('id_back'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _licenseNo,
          style: _fieldStyle,
          decoration: _darkInput('Số GPLX *'),
          onChanged: (v) => widget.data.driverLicenseNumber = v,
        ),
        const SizedBox(height: 12),
        _ImagePickTile(
          label: 'Ảnh GPLX *',
          hasFile: widget.data.driverLicenseFile != null,
          onTap: () => _pick('license'),
        ),
        _ImagePickTile(
          label: 'Ảnh xe + biển số *',
          hasFile: widget.data.vehiclePhotoFile != null,
          onTap: () => _pick('vehicle'),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.data});
  final DriverRegisterData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _StepHint('Kiểm tra lại trước khi gửi duyệt'),
        _ConfirmRow('Email', data.email),
        _ConfirmRow('Họ tên', data.fullName),
        _ConfirmRow('SĐT', data.phone),
        _ConfirmRow(
          'Xe',
          '${data.vehicleType} · ${data.vehicleBrandModel} · ${data.vehicleColor}',
        ),
        _ConfirmRow('Biển số', data.licensePlate),
        _ConfirmRow('CCCD', data.idCardNumber),
        _ConfirmRow('GPLX', data.driverLicenseNumber),
        _ConfirmRow(
          'Ảnh',
          [
            if (data.avatarFile != null) 'Avatar',
            if (data.idCardFrontFile != null) 'CCCD trước',
            if (data.idCardBackFile != null) 'CCCD sau',
            if (data.driverLicenseFile != null) 'GPLX',
            if (data.vehiclePhotoFile != null) 'Xe',
          ].join(', '),
        ),
        const SizedBox(height: 12),
        Text(
          'Sau khi gửi, hồ sơ ở trạng thái chờ admin duyệt. '
          'Bạn chỉ nhận đơn khi được duyệt.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StepHint extends StatelessWidget {
  const _StepHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ImagePickTile extends StatelessWidget {
  const _ImagePickTile({
    required this.label,
    required this.hasFile,
    required this.onTap,
  });

  final String label;
  final bool hasFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  hasFile
                      ? Icons.check_circle_rounded
                      : Icons.add_photo_alternate_outlined,
                  color: hasFile
                      ? const Color(0xFF22C55E)
                      : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                Text(
                  hasFile ? 'Đã chọn' : 'Chọn ảnh',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
