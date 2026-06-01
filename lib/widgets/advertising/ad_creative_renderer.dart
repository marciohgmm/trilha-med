import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/advertising/advertising_enums.dart';
import '../../domain/platform/models/ad_campaign.dart';

/// Renderiza criativo conforme [AdFormat] (usado quando placements estão habilitados).
class AdCreativeRenderer extends StatelessWidget {
  const AdCreativeRenderer({
    super.key,
    required this.campaign,
    this.onTap,
  });

  final AdCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return switch (campaign.format) {
      AdFormat.banner => _BannerCreative(campaign: campaign, onTap: onTap),
      AdFormat.nativeCard => _NativeCardCreative(campaign: campaign, onTap: onTap),
      AdFormat.popup => _PopupCreative(campaign: campaign, onTap: onTap),
      AdFormat.fullscreen => _FullscreenCreative(campaign: campaign, onTap: onTap),
      AdFormat.institutional => _InstitutionalCreative(campaign: campaign, onTap: onTap),
    };
  }
}

class _BannerCreative extends StatelessWidget {
  const _BannerCreative({required this.campaign, this.onTap});
  final AdCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: campaign.imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: campaign.imageUrl,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          : _TextFallback(campaign: campaign),
    );
  }
}

class _NativeCardCreative extends StatelessWidget {
  const _NativeCardCreative({required this.campaign, this.onTap});
  final AdCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (campaign.partnerLogoUrl?.isNotEmpty == true)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: campaign.partnerLogoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                )
              else if (campaign.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: campaign.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campaign.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (campaign.bodyText?.isNotEmpty == true)
                      Text(campaign.bodyText!, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupCreative extends StatelessWidget {
  const _PopupCreative({required this.campaign, this.onTap});
  final AdCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(campaign.title),
      content: campaign.bodyText != null ? Text(campaign.bodyText!) : null,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        if (onTap != null)
          FilledButton(onPressed: onTap, child: const Text('Saiba mais')),
      ],
    );
  }
}

class _FullscreenCreative extends StatelessWidget {
  const _FullscreenCreative({required this.campaign, this.onTap});
  final AdCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (campaign.imageUrl.isNotEmpty)
            CachedNetworkImage(imageUrl: campaign.imageUrl, fit: BoxFit.contain),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: FilledButton(onPressed: onTap, child: Text(campaign.title)),
          ),
        ],
      ),
    );
  }
}

class _InstitutionalCreative extends StatelessWidget {
  const _InstitutionalCreative({required this.campaign, this.onTap});
  final AdCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text('${campaign.title}${campaign.bodyText != null ? ' — ${campaign.bodyText}' : ''}'),
      leading: const Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
      actions: [
        if (onTap != null)
          TextButton(onPressed: onTap, child: const Text('Detalhes')),
      ],
    );
  }
}

class _TextFallback extends StatelessWidget {
  const _TextFallback({required this.campaign});
  final AdCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade200,
      child: Text(campaign.title),
    );
  }
}
