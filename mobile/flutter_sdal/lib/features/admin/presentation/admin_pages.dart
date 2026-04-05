import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/sdal_theme_tokens.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/surface_card.dart';

class AdminHubPage extends ConsumerWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final user = session?.user;

    if (session == null || user == null || !user.isAdmin) {
      return FeatureScaffold(
        title: 'Admin paneli',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Bu alan yalnizca admin hesaplari icin acik.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/feed'),
                    child: const Text('Akisa don'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final moduleEntries = session.siteAccess.modules.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return FeatureScaffold(
      title: 'Admin paneli',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yonetici ozeti',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AdminStatChip(
                      icon: Icons.admin_panel_settings_outlined,
                      label: user.role,
                    ),
                    _AdminStatChip(
                      icon: Icons.verified_user_outlined,
                      label: user.isVerified
                          ? 'Dogrulanmis'
                          : 'Dogrulama bekliyor',
                    ),
                    _AdminStatChip(
                      icon: Icons.home_outlined,
                      label: 'Varsayilan: ${session.defaultHomePath}',
                    ),
                    _AdminStatChip(
                      icon: Icons.settings_ethernet_outlined,
                      label: session.siteAccess.siteOpen
                          ? 'Site acik'
                          : 'Bakim modu',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Yonetim yuzeyleri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final section in _adminSections) ...[
            _AdminSectionCard(section: section),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modul durumu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in moduleEntries)
                      Chip(
                        avatar: Icon(
                          entry.value ? Icons.check_circle : Icons.pause_circle,
                          size: 18,
                          color: entry.value
                              ? Theme.of(context).sdal.success
                              : Theme.of(context).sdal.warning,
                        ),
                        label: Text(
                          '${entry.key} · ${entry.value ? 'acik' : 'kapali'}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionPage extends StatelessWidget {
  const AdminSectionPage({super.key, required this.sectionKey});

  final String sectionKey;

  @override
  Widget build(BuildContext context) {
    final section = _sectionByKey(sectionKey);
    if (section == null) {
      return FeatureScaffold(
        title: 'Admin paneli',
        child: const Center(child: Text('Bilinmeyen admin bolumu.')),
      );
    }

    return FeatureScaffold(
      title: section.title,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: section.tint.withValues(alpha: 0.18),
                      foregroundColor: section.tint,
                      child: Icon(section.icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(section.description),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu bolumde yer alan akislar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final capability in section.capabilities) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.chevron_right, color: section.tint),
                      const SizedBox(width: 4),
                      Expanded(child: Text(capability)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sunucu baglantisi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu ekran ${section.routeFile} ile eslesecek sekilde eklendi. '
                  'Mobil tarafta admin ulasim yolu artik var; islem bazli formlar ve tablolar bu temelin uzerine genisletilebilir.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionCard extends StatelessWidget {
  const _AdminSectionCard({required this.section});

  final _AdminSection section;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/admin/${section.key}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: section.tint.withValues(alpha: 0.16),
                foregroundColor: section.tint,
                child: Icon(section.icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).sdal.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStatChip extends StatelessWidget {
  const _AdminStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _AdminSection {
  const _AdminSection({
    required this.key,
    required this.title,
    required this.summary,
    required this.description,
    required this.icon,
    required this.tint,
    required this.routeFile,
    required this.capabilities,
  });

  final String key;
  final String title;
  final String summary;
  final String description;
  final IconData icon;
  final Color tint;
  final String routeFile;
  final List<String> capabilities;
}

const _adminSections = <_AdminSection>[
  _AdminSection(
    key: 'management',
    title: 'Roller ve yonetim',
    summary: 'Admin oturumu, root durumu, moderator rolleri ve izinleri.',
    description:
        'Kullanici rolleri, moderator kapsam atamalari ve temel admin oturum kontrolleri burada toplanir.',
    icon: Icons.manage_accounts_outlined,
    tint: Color(0xFF355C87),
    routeFile: 'server/routes/adminManagementRoutes.js',
    capabilities: [
      'Admin oturumu ve root bootstrap durumu',
      'Kullanici rol guncelleme',
      'Moderator kapsam ve yetki atamalari',
    ],
  ),
  _AdminSection(
    key: 'content',
    title: 'Icerik moderasyonu',
    summary: 'Gruplar, paylasimlar, yorumlar, hikayeler, sohbet ve filtreler.',
    description:
        'Topluluk icerigi uzerindeki denetim akislarini bir araya getirir.',
    icon: Icons.shield_outlined,
    tint: Color(0xFF9B6A1C),
    routeFile: 'server/routes/adminContentModerationRoutes.js',
    capabilities: [
      'Dogrulama talepleri',
      'Gruplar, postlar, yorumlar ve hikayeler',
      'Canli sohbet ve mesaj denetimi',
      'Icerik filtre kurallari',
    ],
  ),
  _AdminSection(
    key: 'requests',
    title: 'Talep moderasyonu',
    summary: 'Uyelik talepleri ve ogretmen agi baglanti onaylari.',
    description:
        'Uyelik dogrulama, talep bildirimleri ve ogretmen baglantisi incelemeleri bu bolumdedir.',
    icon: Icons.assignment_turned_in_outlined,
    tint: Color(0xFF2C6B4B),
    routeFile: 'server/routes/adminRequestModerationRoutes.js',
    capabilities: [
      'Uyelik ve mezuniyet talepleri',
      'Ogretmen agi baglanti review akislari',
      'Admin dogrulama islemleri',
    ],
  ),
  _AdminSection(
    key: 'operations',
    title: 'Operasyonlar ve guvenlik',
    summary: 'Operasyonel kontroller, guvenlik ve denetim yuzeyleri.',
    description:
        'Bakim, operasyon ve guvenlik odakli admin akislarini tek yerde toplar.',
    icon: Icons.security_outlined,
    tint: Color(0xFFAA4834),
    routeFile:
        'server/routes/adminOperationsRoutes.js + adminSecurityRoutes.js',
    capabilities: [
      'Operasyonel durum kontrolleri',
      'Guvenlik odakli admin akislarina erisim',
      'Denetim ve koruma yuzeyleri',
    ],
  ),
  _AdminSection(
    key: 'experiments',
    title: 'Deneyler ve dashboard',
    summary: 'A/B testleri, engagement skorlari ve yonetici ozetleri.',
    description:
        'Deney varyantlari ile yonetici panelindeki ozet ve aktivite akislarini kapsar.',
    icon: Icons.science_outlined,
    tint: Color(0xFF6A4FB4),
    routeFile: 'server/routes/adminExperimentRoutes.js',
    capabilities: [
      'Engagement A/B yonetimi',
      'Network suggestion deneyleri',
      'Dashboard summary ve live activity',
      'Engagement score yeniden hesaplama',
    ],
  ),
  _AdminSection(
    key: 'database',
    title: 'Veritabani',
    summary: 'Backup, restore ve aktif surucu gecisi.',
    description:
        'Veritabani surucu durumu, yedekleme ve veri tasima akislarini kapsar.',
    icon: Icons.storage_outlined,
    tint: Color(0xFF355C87),
    routeFile: 'server/routes/adminDbRoutes.js',
    capabilities: [
      'Backup listesi ve indirme',
      'Restore yukleme',
      'Driver status ve switch islemleri',
      'Veri kopyalama akisleri',
    ],
  ),
  _AdminSection(
    key: 'languages',
    title: 'Diller',
    summary: 'Dil listesi, anahtarlar ve ceviri metinleri.',
    description:
        'Dil konfigrasyonu ve metin yonetimi icin gerekli admin endpointlerini kapsar.',
    icon: Icons.translate_outlined,
    tint: Color(0xFFC8633C),
    routeFile: 'server/routes/adminLanguageRoutes.js',
    capabilities: [
      'Dil ekleme, guncelleme ve silme',
      'Dil string anahtarlari ve toplu guncelleme',
      'Eksik cevirileri doldurma',
      'Dil ayarlari yonetimi',
    ],
  ),
];

_AdminSection? _sectionByKey(String key) {
  for (final section in _adminSections) {
    if (section.key == key) return section;
  }
  return null;
}
