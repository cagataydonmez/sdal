import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../application/jobs_action_controller.dart';
import '../data/opportunities_repository.dart';

const _turkishProvinces = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
  'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir',
  'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis',
  'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum',
  'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elâzığ', 'Erzincan',
  'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkâri',
  'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir', 'Kahramanmaraş',
  'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale',
  'Kırklareli', 'Kırşehir', 'Kilis', 'Kocaeli', 'Konya', 'Kütahya',
  'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
  'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya',
  'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak',
  'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van',
  'Yalova', 'Yozgat', 'Zonguldak',
];

const _contactChannels = ['E-posta', 'Telefon', 'SMS', 'WhatsApp', 'LinkedIn'];

const _noteTemplates = [
  'Belirtilen pozisyon için başvurumu saygıyla iletiyorum. Deneyim ve becerilerimin bu role uygun olduğuna inanıyorum.',
  'Ekibinizin bir parçası olarak katkı sağlamaktan onur duyarım. Başvurumu değerlendirmenizi rica ederim.',
  'İlanınızı inceledim ve kariyer hedeflerimle tam olarak örtüştüğünü gördüm. Görüşme fırsatı yaratmanızı ümit ediyorum.',
  'Şirketinizin değerlerini ve çalışma anlayışını takdirle karşılıyorum; bu pozisyonda değer katmaktan mutluluk duyarım.',
  'Tecrübem ve motivasyonumun bu pozisyon için uygun olduğunu düşünüyor, başvurumu saygıyla sunuyorum.',
];

class JobApplyPage extends ConsumerStatefulWidget {
  const JobApplyPage({super.key, required this.jobId, required this.jobTitle});

  final int jobId;
  final String jobTitle;

  @override
  ConsumerState<JobApplyPage> createState() => _JobApplyPageState();
}

class _JobApplyPageState extends ConsumerState<JobApplyPage> {
  final _cvLinkController = TextEditingController();
  final _contactValueController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedChannel;
  String? _selectedCity;
  int? _selectedTemplateIndex;

  @override
  void dispose() {
    _cvLinkController.dispose();
    _contactValueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  TextInputType _keyboardTypeForChannel(String? channel) {
    switch (channel) {
      case 'E-posta':
        return TextInputType.emailAddress;
      case 'Telefon':
      case 'SMS':
      case 'WhatsApp':
        return TextInputType.phone;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter> _formattersForChannel(String? channel) {
    if (channel == 'Telefon' || channel == 'SMS' || channel == 'WhatsApp') {
      return [_PhoneInputFormatter()];
    }
    return [];
  }

  String _contactValueLabel(String? channel) {
    switch (channel) {
      case 'E-posta':
        return 'E-posta adresi';
      case 'Telefon':
      case 'SMS':
        return 'Telefon numarası';
      case 'WhatsApp':
        return 'WhatsApp numarası';
      case 'LinkedIn':
        return 'LinkedIn profil linki';
      default:
        return 'İletişim bilgisi';
    }
  }

  void _applyTemplate(int index) {
    setState(() {
      if (_selectedTemplateIndex == index) {
        _selectedTemplateIndex = null;
        _noteController.clear();
      } else {
        _selectedTemplateIndex = index;
        _noteController.text = _noteTemplates[index];
      }
    });
  }

  Future<void> _submit() async {
    final ok = await ref.read(jobsActionControllerProvider.notifier).apply(
      jobId: widget.jobId,
      coverLetter: _noteController.text.trim(),
      cvLink: _cvLinkController.text.trim(),
      contactChannel: _selectedChannel ?? '',
      contactValue: _contactValueController.text.trim(),
      city: _selectedCity ?? '',
    );
    if (!mounted) return;
    final state = ref.read(jobsActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.message ?? (ok ? 'Başvurunuz iletildi.' : 'Başvuru gönderilemedi.'),
        ),
      ),
    );
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(jobsActionControllerProvider);
    final isSending = actionState.isLoading &&
        actionState.scope == 'jobs:apply:${widget.jobId}';

    return FeatureScaffold(
      title: 'Başvur',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.jobTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tüm alanlar isteğe bağlıdır.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // CV Link
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _cvLinkController,
                  keyboardType: TextInputType.url,
                  enabled: !isSending,
                  decoration: const InputDecoration(
                    labelText: 'CV linki',
                    hintText: 'drive.google.com/... veya dropbox.com/...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'CV dosyası saklamıyoruz.\nCV\'nizi Google Drive, Dropbox gibi\nbir servise yükleyip linkini paylaşabilirsiniz.',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 5),
                child: const Icon(Icons.info_outline, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact channel
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'İletişim kanalı',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedChannel,
                isDense: true,
                hint: const Text('Seçin (isteğe bağlı)'),
                items: _contactChannels
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: isSending
                    ? null
                    : (v) => setState(() {
                          _selectedChannel = v;
                          _contactValueController.clear();
                        }),
              ),
            ),
          ),
          if (_selectedChannel != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _contactValueController,
              keyboardType: _keyboardTypeForChannel(_selectedChannel),
              inputFormatters: _formattersForChannel(_selectedChannel),
              enabled: !isSending,
              decoration: InputDecoration(
                labelText: _contactValueLabel(_selectedChannel),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // City
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Yaşadığınız il',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCity,
                isDense: true,
                hint: const Text('İl seçin (isteğe bağlı)'),
                isExpanded: true,
                items: _turkishProvinces
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged:
                    isSending ? null : (v) => setState(() => _selectedCity = v),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Note templates
          Text(
            'Başvuru notu',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Şablon seçin veya kendiniz yazın.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_noteTemplates.length, (i) {
              final selected = _selectedTemplateIndex == i;
              return ChoiceChip(
                label: Text('Şablon ${i + 1}'),
                selected: selected,
                onSelected: isSending ? null : (_) => _applyTemplate(i),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 4,
            maxLines: 8,
            enabled: !isSending,
            decoration: const InputDecoration(
              labelText: 'Başvuru notu (isteğe bağlı)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_selectedTemplateIndex != null) {
                setState(() => _selectedTemplateIndex = null);
              }
            },
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: isSending ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(isSending ? 'Gönderiliyor...' : 'Başvuruyu gönder'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isSending ? null : () => context.pop(),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buf.write('0');
      if (i == 1) buf.write(' (');
      if (i == 4) buf.write(') ');
      if (i == 7) buf.write(' ');
      if (i == 9) buf.write(' ');
      if (i > 0) buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
