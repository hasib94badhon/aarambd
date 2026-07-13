import 'package:aaram_bd/services/contact_info_service.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _brand = Color(0xFF1A56DB);

/// Fetches and renders the structured contact info (`/get_contact_info`) as
/// a card of tappable rows — call, email, directions, website, Facebook.
/// Renders nothing (SizedBox.shrink) if the fetch fails or every field is
/// empty, so it never shows a broken/empty card.
class ContactInfoCard extends StatefulWidget {
  /// Compact mode drops the header and shows only the phone row, for use as
  /// a lightweight footer CTA (e.g. at the bottom of a legal document).
  final bool compact;

  const ContactInfoCard({Key? key, this.compact = false}) : super(key: key);

  @override
  State<ContactInfoCard> createState() => _ContactInfoCardState();
}

class _ContactInfoCardState extends State<ContactInfoCard> {
  ContactInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await ContactInfoService.fetch(context);
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showAppToast(context, 'Could not open this — please try again.',
          icon: Icons.error_outline_rounded);
    }
  }

  Uri _webUri(String value) {
    final hasScheme = value.startsWith('http://') || value.startsWith('https://');
    return Uri.parse(hasScheme ? value : 'https://$value');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.compact
          ? const SizedBox.shrink()
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: _brand),
                ),
              ),
            );
    }

    final info = _info;
    if (info == null || info.isEmpty) return const SizedBox.shrink();

    if (widget.compact) {
      if (info.phone.isEmpty) return const SizedBox.shrink();
      return _CompactContactBanner(
        phone: info.phone,
        onTap: () => _launch(Uri(scheme: 'tel', path: info.phone)),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic_rounded, size: 18, color: _brand),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Get in Touch',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (info.phone.isNotEmpty)
              _ContactRow(
                icon: Icons.call_rounded,
                label: info.phone,
                onTap: () => _launch(Uri(scheme: 'tel', path: info.phone)),
              ),
            if (info.email.isNotEmpty)
              _ContactRow(
                icon: Icons.mail_outline_rounded,
                label: info.email,
                onTap: () => _launch(Uri(scheme: 'mailto', path: info.email)),
              ),
            if (info.address.isNotEmpty)
              _ContactRow(
                icon: Icons.location_on_outlined,
                label: info.address,
                onTap: () => _launch(Uri.parse(
                    'https://www.google.com/maps/search/${Uri.encodeComponent(info.address)}')),
              ),
            if (info.website.isNotEmpty)
              _ContactRow(
                icon: Icons.language_rounded,
                label: info.website,
                onTap: () => _launch(_webUri(info.website)),
              ),
            if (info.facebook.isNotEmpty)
              _ContactRow(
                icon: Icons.facebook_rounded,
                label: info.facebook,
                onTap: () => _launch(_webUri(info.facebook)),
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _brand),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.black.withValues(alpha: 0.25)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactContactBanner extends StatelessWidget {
  final String phone;
  final VoidCallback onTap;

  const _CompactContactBanner({required this.phone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brand.withValues(alpha: 0.16)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                const Icon(Icons.headset_mic_rounded, size: 19, color: _brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Questions about these terms?',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Call AaramBD at $phone',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _brand,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.call_rounded, size: 18, color: _brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
