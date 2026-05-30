import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _noteController = TextEditingController();
  
  String _serviceType = 'standard';
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }
  
  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    
    if (!_formKey.currentState!.validate()) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Vui lòng đăng nhập để tạo đơn hàng', isError: true);
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final order = OrderModel(
        id: '',
        customerId: user.id,
        driverId: null,
        status: 'pending',
        pickupAddress: _pickupAddressController.text.trim(),
        pickupLat: 0,
        pickupLng: 0,
        deliveryAddress: _deliveryAddressController.text.trim(),
        deliveryLat: 0,
        deliveryLng: 0,
        totalPrice: null,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: DateTime.now(),
        trackingCode: '',
        estimatedPickupAt: null,
        estimatedDeliveryAt: null,
        actualPickedUpAt: null,
        actualDeliveredAt: null,
        cancelledAt: null,
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        deliveryFee: 30000,
        serviceType: _serviceType,
        paymentMethod: 'cash',
        statusNote: null,
        updatedAt: DateTime.now(),
      );
      
      final service = ref.read(customerOrderServiceProvider);
      await service.createOrder(order);
      
      ref.invalidate(customerOrdersProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(activeOrderProvider);
      
      if (mounted) {
        _showSnackBar('Đơn hàng đã được tạo thành công!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textOnAccent),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          'Tạo đơn hàng mới',
          style: AppTextStyles.headingMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // Header section
              Text(
                'Thông tin giao hàng',
                style: AppTextStyles.headingSmall.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Vui lòng điền đầy đủ thông tin để tạo đơn hàng',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl2),
              
              // Pickup address card
              _buildSectionCard(
                icon: Icons.add_location_alt_rounded,
                iconColor: AppColors.info,
                title: 'Địa chỉ lấy hàng',
                child: TextFormField(
                  controller: _pickupAddressController,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    hintText: 'Nhập địa chỉ lấy hàng',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập địa chỉ lấy hàng';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              // Delivery address card
              _buildSectionCard(
                icon: Icons.local_shipping_rounded,
                iconColor: AppColors.accent,
                title: 'Địa chỉ giao hàng',
                child: TextFormField(
                  controller: _deliveryAddressController,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    hintText: 'Nhập địa chỉ giao hàng',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập địa chỉ giao hàng';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl2),
              
              // Recipient info section
              Text(
                'Thông tin người nhận',
                style: AppTextStyles.headingSmall.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              _buildSectionCard(
                icon: Icons.person_rounded,
                iconColor: AppColors.success,
                title: 'Tên người nhận',
                child: TextFormField(
                  controller: _recipientNameController,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    hintText: 'Nhập tên người nhận',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên người nhận';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              _buildSectionCard(
                icon: Icons.phone_rounded,
                iconColor: AppColors.success,
                title: 'Số điện thoại',
                child: TextFormField(
                  controller: _recipientPhoneController,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    hintText: 'Nhập số điện thoại',
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl2),
              
              // Service type section
              Text(
                'Loại dịch vụ',
                style: AppTextStyles.headingSmall.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              _buildServiceTypeSelector(),
              const SizedBox(height: AppSpacing.xl2),
              
               // Note section
               Text(
                 'Ghi chú (tùy chọn)',
                 style: AppTextStyles.headingSmall.copyWith(color: AppColors.textPrimary),
               ),
               const SizedBox(height: AppSpacing.lg),
               
               _buildSectionCard(
                 icon: Icons.description_rounded,
                 iconColor: AppColors.info,
                 title: 'Ghi chú (tùy chọn)',
                 child: TextFormField(
                   controller: _noteController,
                   style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                   decoration: _buildInputDecoration(
                     hintText: 'Thêm ghi chú cho đơn hàng',
                   ),
                   maxLines: 3,
                   textInputAction: TextInputAction.done,
                 ),
               ),
               const SizedBox(height: AppSpacing.xl3),
              
              // Submit button
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _isSubmitting ? AppColors.accent.withValues(alpha: 0.6 * 255) : AppColors.accent,
                  borderRadius: AppRadius.full,
                  boxShadow: _isSubmitting ? [] : AppShadow.accentGlow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSubmitting ? null : _submitOrder,
                    borderRadius: AppRadius.full,
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnAccent,
                              ),
                            )
                          : Text(
                              'Tạo đơn hàng',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textOnAccent,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadow.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1 * 255),
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
  
  Widget _buildServiceTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadow.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _buildServiceTypeOption(
            value: 'standard',
            title: 'Tiêu chuẩn',
            subtitle: 'Giao hàng trong 2-3 ngày',
            icon: Icons.local_shipping_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildServiceTypeOption(
            value: 'express',
            title: 'Hỏa tốc',
            subtitle: 'Giao hàng trong 24 giờ',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildServiceTypeOption(
            value: 'bulky',
            title: 'Cồng kềnh',
            subtitle: 'Hàng hóa lớn, nặng',
            icon: Icons.inventory_2_rounded,
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceTypeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _serviceType == value;
    
    return InkWell(
      onTap: () => setState(() => _serviceType = value),
      borderRadius: AppRadius.md,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentLight : AppColors.bgLight,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.textMuted.withValues(alpha: 0.1 * 255),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.textOnAccent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  InputDecoration _buildInputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.bgLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
    );
  }
}