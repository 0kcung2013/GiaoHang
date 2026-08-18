import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/risk_report_strings.dart';
import '../data/risk_report_repository.dart';
import '../services/risk_location_address_service.dart';

typedef RiskLocationAddressResolver =
    Future<String> Function(double latitude, double longitude);

class RiskAttachmentSection extends StatelessWidget {
  const RiskAttachmentSection({
    required this.items,
    this.addressResolver,
    super.key,
  });

  final List<RiskReportAttachmentView>? items;
  final RiskLocationAddressResolver? addressResolver;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(RiskReportStrings.evidenceTitle, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        if (items == null)
          const _AttachmentLoading()
        else if (items!.isEmpty)
          Text(
            RiskReportStrings.noAttachments,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: items!
                .map(
                  (item) =>
                      _AttachmentCard(item, addressResolver: addressResolver),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard(this.item, {this.addressResolver});

  final RiskReportAttachmentView item;
  final RiskLocationAddressResolver? addressResolver;

  @override
  Widget build(BuildContext context) {
    final attachment = item.attachment;
    if (attachment.evidenceType == RiskEvidenceType.location) {
      return _LocationEvidence(
        attachment: attachment,
        addressResolver: addressResolver,
      );
    }
    return Container(
      width: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: item.signedUrl == null
            ? const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textMuted,
                ),
              )
            : Image.network(
                item.signedUrl!,
                fit: BoxFit.cover,
                semanticLabel: 'Ảnh bằng chứng báo cáo sự cố',
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
      ),
    );
  }
}

class _LocationEvidence extends StatefulWidget {
  const _LocationEvidence({required this.attachment, this.addressResolver});

  final RiskReportAttachment attachment;
  final RiskLocationAddressResolver? addressResolver;

  @override
  State<_LocationEvidence> createState() => _LocationEvidenceState();
}

class _LocationEvidenceState extends State<_LocationEvidence> {
  late final Future<String> _address;

  @override
  void initState() {
    super.initState();
    final latitude = widget.attachment.latitude!;
    final longitude = widget.attachment.longitude!;
    _address =
        (widget.addressResolver ?? const RiskLocationAddressService().resolve)(
          latitude,
          longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    final latitude = widget.attachment.latitude!;
    final longitude = widget.attachment.longitude!;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: _address,
                  builder: (context, snapshot) => Text(
                    snapshot.hasData
                        ? snapshot.data!
                        : snapshot.hasError
                        ? RiskReportStrings.addressUnavailable
                        : RiskReportStrings.resolvingAddress,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: snapshot.hasError
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: () => _openMap(latitude, longitude),
                  borderRadius: AppRadius.sm,
                  child: SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        RiskReportStrings.openMap,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(double latitude, double longitude) {
    return launchUrl(
      Uri.parse(
        'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude'
        '#map=17/$latitude/$longitude',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _AttachmentLoading extends StatelessWidget {
  const _AttachmentLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 120,
      decoration: const BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadius.md,
      ),
    );
  }
}
