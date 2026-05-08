import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../theme/sdal_theme_tokens.dart';

enum CropAspectPreset {
  square(1),
  album43(4 / 3),
  portrait45(4 / 5),
  story916(9 / 16),
  wide169(16 / 9);

  const CropAspectPreset(this.ratio);
  final double ratio;
}

enum _EditorPanel { crop, text, draw, hide, filter }

enum _StickerBackgroundStyle { none, soft, dark, light }

enum _StickerFontKind { sans, serif, mono }

enum _BrushMode { pen, highlighter }

enum _HideRegionStyle { blur, mosaic }

enum _ResizeHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

class _AspectChoice {
  const _AspectChoice(this.label, this.ratio);

  final String label;
  final double? ratio;
}

class _StickerColorChoice {
  const _StickerColorChoice(this.color, this.label);

  final Color color;
  final String label;
}

class _StickerFontChoice {
  const _StickerFontChoice(this.kind, this.label, this.family);

  final _StickerFontKind kind;
  final String label;
  final String? family;
}

class _OverlaySticker {
  const _OverlaySticker({
    required this.id,
    required this.text,
    required this.anchor,
    required this.scale,
    required this.textColor,
    required this.backgroundStyle,
    required this.fontKind,
    required this.textAlign,
    required this.bold,
  });

  final int id;
  final String text;
  final Offset anchor;
  final double scale;
  final Color textColor;
  final _StickerBackgroundStyle backgroundStyle;
  final _StickerFontKind fontKind;
  final TextAlign textAlign;
  final bool bold;

  _OverlaySticker copyWith({
    String? text,
    Offset? anchor,
    double? scale,
    Color? textColor,
    _StickerBackgroundStyle? backgroundStyle,
    _StickerFontKind? fontKind,
    TextAlign? textAlign,
    bool? bold,
  }) {
    return _OverlaySticker(
      id: id,
      text: text ?? this.text,
      anchor: anchor ?? this.anchor,
      scale: scale ?? this.scale,
      textColor: textColor ?? this.textColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      fontKind: fontKind ?? this.fontKind,
      textAlign: textAlign ?? this.textAlign,
      bold: bold ?? this.bold,
    );
  }
}

class _DrawStroke {
  const _DrawStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.mode,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final _BrushMode mode;

  _DrawStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    _BrushMode? mode,
  }) {
    return _DrawStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      mode: mode ?? this.mode,
    );
  }
}

class _HideRegion {
  const _HideRegion({
    required this.id,
    required this.center,
    required this.size,
    required this.style,
    this.aspectLocked = true,
  });

  final int id;
  final Offset center;
  final Size size;
  final _HideRegionStyle style;
  final bool aspectLocked;

  _HideRegion copyWith({
    Offset? center,
    Size? size,
    _HideRegionStyle? style,
    bool? aspectLocked,
  }) {
    return _HideRegion(
      id: id,
      center: center ?? this.center,
      size: size ?? this.size,
      style: style ?? this.style,
      aspectLocked: aspectLocked ?? this.aspectLocked,
    );
  }
}

class EditedMediaResult {
  const EditedMediaResult({
    required this.file,
    required this.sourceFile,
    required this.metadata,
  });

  final File file;
  final File sourceFile;
  final Map<String, dynamic> metadata;
}

Future<ImageSource?> _chooseImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Galeri',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                  ),
                  const Divider(height: 1, color: Color(0xFF3A3A3C)),
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Kamera',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Vazgeç',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<File?> pickAndCropImage(
  BuildContext context, {
  ImageSource? source,
  CropAspectPreset? aspectPreset = CropAspectPreset.album43,
  String title = 'Fotoğrafı düzenle',
}) async {
  final result = await pickAndEditImage(
    context,
    source: source,
    aspectPreset: aspectPreset,
    title: title,
  );
  return result?.file;
}

Future<EditedMediaResult?> pickAndEditImage(
  BuildContext context, {
  ImageSource? source,
  CropAspectPreset? aspectPreset = CropAspectPreset.album43,
  String title = 'Fotoğrafı düzenle',
}) async {
  final resolvedSource = source ?? await _chooseImageSource(context);
  if (resolvedSource == null || !context.mounted) return null;
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: resolvedSource);
  if (picked == null || !context.mounted) return null;
  return editImageFile(
    context,
    sourceFile: File(picked.path),
    aspectPreset: aspectPreset,
    title: title,
  );
}

Future<List<EditedMediaResult>> pickAndEditImages(
  BuildContext context, {
  CropAspectPreset? aspectPreset = CropAspectPreset.album43,
  String title = 'Fotoğrafı düzenle',
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickMultiImage();
  if (picked.isEmpty || !context.mounted) return const <EditedMediaResult>[];
  final results = <EditedMediaResult>[];
  for (var index = 0; index < picked.length; index += 1) {
    if (!context.mounted) break;
    final edited = await editImageFile(
      context,
      sourceFile: File(picked[index].path),
      aspectPreset: aspectPreset,
      title: picked.length == 1
          ? title
          : '$title ${index + 1}/${picked.length}',
    );
    if (edited != null) results.add(edited);
  }
  return results;
}

Future<EditedMediaResult?> editImageFile(
  BuildContext context, {
  required File sourceFile,
  CropAspectPreset? aspectPreset,
  String title = 'Fotoğrafı düzenle',
  Map<String, dynamic> initialMetadata = const <String, dynamic>{},
}) {
  return Navigator.of(context).push<EditedMediaResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CropImagePage(
        sourceFile: sourceFile,
        title: title,
        initialAspectRatio: aspectPreset?.ratio,
        initialMetadata: initialMetadata,
      ),
    ),
  );
}

class _CropImagePage extends StatefulWidget {
  const _CropImagePage({
    required this.sourceFile,
    required this.title,
    required this.initialAspectRatio,
    required this.initialMetadata,
  });

  final File sourceFile;
  final String title;
  final double? initialAspectRatio;
  final Map<String, dynamic> initialMetadata;

  @override
  State<_CropImagePage> createState() => _CropImagePageState();
}

class _CropImagePageState extends State<_CropImagePage> {
  static const double _maxDecodedDimension = 2048;
  static const double _maxExportDimension = 1600;
  static const List<_AspectChoice> _aspectChoices = [
    _AspectChoice('Serbest', null),
    _AspectChoice('1:1', 1),
    _AspectChoice('4:5', 4 / 5),
    _AspectChoice('9:16', 9 / 16),
    _AspectChoice('16:9', 16 / 9),
  ];
  static const List<_StickerColorChoice> _stickerColors = [
    _StickerColorChoice(Colors.white, 'Beyaz'),
    _StickerColorChoice(Color(0xFFFACC15), 'Sarı'),
    _StickerColorChoice(Color(0xFF93C5FD), 'Mavi'),
    _StickerColorChoice(Color(0xFFF9A8D4), 'Pembe'),
    _StickerColorChoice(Color(0xFF86EFAC), 'Yeşil'),
    _StickerColorChoice(Color(0xFFFCA5A5), 'Kırmızı'),
  ];
  static const List<_StickerFontChoice> _stickerFonts = [
    _StickerFontChoice(_StickerFontKind.sans, 'Sans', null),
    _StickerFontChoice(_StickerFontKind.serif, 'Serif', 'serif'),
    _StickerFontChoice(_StickerFontKind.mono, 'Mono', 'monospace'),
  ];
  static const List<_FilterPreset> _filterPresets = [
    _FilterPreset('Doğal', 0, 1, 0, 1),
    _FilterPreset('Canlı', 0.03, 1.1, 0.02, 1.1),
    _FilterPreset('Sıcak', 0.02, 1.04, 0.2, 1),
    _FilterPreset('Soğuk', 0.01, 1.04, -0.18, 1),
    _FilterPreset('Mono', 0, 1.02, 0, 0),
  ];

  final TransformationController _controller = TransformationController();
  final GlobalKey _captureRegionKey = GlobalKey();

  ui.Image? _decodedImage;
  Size _viewportSize = Size.zero;
  Size _stageSize = Size.zero;
  Size _displayImageSize = Size.zero;
  double _baseScale = 1;
  bool _isSaving = false;
  bool _isCapturing = false;
  bool _showOriginalPreview = false;
  double _freeformWidthFactor = 1;
  double _freeformHeightFactor = 1;
  double? _selectedAspectRatio;
  int _quarterTurns = 0;
  _EditorPanel _activePanel = _EditorPanel.crop;

  int _nextStickerId = 1;
  int? _selectedStickerId;
  List<_OverlaySticker> _stickers = const [];
  double? _stickerBaseScale;

  List<_DrawStroke> _strokes = const [];
  List<Offset> _currentStrokePoints = const [];
  Color _drawColor = Colors.white;
  double _drawWidth = 8;
  _BrushMode _brushMode = _BrushMode.pen;

  int _nextHideRegionId = 1;
  int? _selectedHideRegionId;
  List<_HideRegion> _hideRegions = const [];
  Size? _hideRegionBaseSize;

  double _brightness = 0;
  double _contrast = 1;
  double _warmth = 0;
  double _saturation = 1;

  @override
  void initState() {
    super.initState();
    _selectedAspectRatio = widget.initialAspectRatio;
    _restoreInitialMetadata();
    _loadImage();
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio =
        _selectedAspectRatio ??
        _rotatedImageRatio ??
        MediaQuery.sizeOf(context).aspectRatio;
    final canTransformImage =
        _activePanel == _EditorPanel.crop && !_showOriginalPreview;
    final selectedSticker = _selectedSticker;
    final selectedHideRegion = _selectedHideRegion;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = constraints.biggest;
          final stage = _computeStageSize(screen);
          final viewport = _computeCropFrameSize(stage, ratio);
          final cropFrame = Rect.fromCenter(
            center: Offset(stage.width / 2, stage.height / 2),
            width: viewport.width,
            height: viewport.height,
          );
          _updateViewport(viewport, stage);

          return Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.black)),

              // Image stage — the crop frame is a window inside this stage.
              Align(
                child: GestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  onLongPressStart: _decodedImage == null || _isSaving
                      ? null
                      : (_) => _setOriginalPreview(true),
                  onLongPressEnd: _decodedImage == null || _isSaving
                      ? null
                      : (_) => _setOriginalPreview(false),
                  onLongPressCancel: () => _setOriginalPreview(false),
                  child: RepaintBoundary(
                    child: ClipRect(
                      key: _captureRegionKey,
                      child: SizedBox(
                        width: stage.width,
                        height: stage.height,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: ColoredBox(color: Colors.black),
                            ),
                            InteractiveViewer(
                              transformationController: _controller,
                              constrained: false,
                              minScale: _baseScale,
                              maxScale: math.max(_baseScale * 6, 6),
                              boundaryMargin: const EdgeInsets.all(320),
                              clipBehavior: Clip.none,
                              panEnabled: canTransformImage,
                              scaleEnabled: canTransformImage,
                              child: SizedBox(
                                width: _displayImageSize.width,
                                height: _displayImageSize.height,
                                child: RotatedBox(
                                  quarterTurns: _quarterTurns,
                                  child: SizedBox(
                                    width: _unrotatedDisplaySize.width,
                                    height: _unrotatedDisplaySize.height,
                                    child: _showOriginalPreview
                                        ? Image.file(
                                            widget.sourceFile,
                                            fit: BoxFit.fill,
                                            filterQuality: FilterQuality.medium,
                                            cacheWidth: _cacheWidth,
                                            cacheHeight: _cacheHeight,
                                          )
                                        : ColorFiltered(
                                            colorFilter: ColorFilter.matrix(
                                              _buildColorMatrix(),
                                            ),
                                            child: Image.file(
                                              widget.sourceFile,
                                              fit: BoxFit.fill,
                                              filterQuality:
                                                  FilterQuality.medium,
                                              cacheWidth: _cacheWidth,
                                              cacheHeight: _cacheHeight,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fromRect(
                              rect: cropFrame,
                              child: ClipRect(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _DrawOverlayPainter(
                                      strokes: _showOriginalPreview
                                          ? const <_DrawStroke>[]
                                          : _strokes,
                                      currentStroke: _showOriginalPreview
                                          ? null
                                          : _currentStroke,
                                      viewport: viewport,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fromRect(
                              rect: cropFrame,
                              child: IgnorePointer(
                                ignoring:
                                    _activePanel == _EditorPanel.crop ||
                                    _showOriginalPreview,
                                child: ClipRect(
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      if (!_showOriginalPreview)
                                        for (final region in _hideRegions)
                                          _buildHideRegion(region, viewport),
                                      if (!_showOriginalPreview)
                                        for (final sticker in _stickers)
                                          _buildSticker(sticker, viewport),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_activePanel == _EditorPanel.draw &&
                                !_showOriginalPreview)
                              Positioned.fromRect(
                                rect: cropFrame,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: _startStroke,
                                  onPanUpdate: _extendStroke,
                                  onPanEnd: _finishStroke,
                                ),
                              ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _CropFramePainter(
                                    cropFrame: cropFrame,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top bar — hidden during capture
              if (!_isCapturing)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(context),
                ),

              // Bottom tools — hidden during capture
              if (!_isCapturing)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomOverlay(
                    context,
                    viewport: viewport,
                    selectedSticker: selectedSticker,
                    selectedHideRegion: selectedHideRegion,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Vazgeç',
              ),
              const Spacer(),
              IconButton(
                onPressed: _decodedImage == null || _isSaving
                    ? null
                    : _rotateImage,
                icon: const Icon(
                  Icons.rotate_90_degrees_ccw_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Döndür',
              ),
              IconButton(
                onPressed: _decodedImage == null || _isSaving
                    ? null
                    : _resetAll,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Sıfırla',
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : FilledButton(
                        onPressed: _decodedImage == null ? null : _saveCrop,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text(
                          'İleri',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(
    BuildContext context, {
    required Size viewport,
    required _OverlaySticker? selectedSticker,
    required _HideRegion? selectedHideRegion,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPanelControls(
              context,
              viewport: viewport,
              selectedSticker: selectedSticker,
              selectedHideRegion: selectedHideRegion,
            ),
            const SizedBox(height: 4),
            _buildPanelTabRow(context),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelTabRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTabIcon(_EditorPanel.crop, Icons.crop_rounded, 'Kırp'),
          _buildTabIcon(_EditorPanel.text, Icons.text_fields_rounded, 'Yazı'),
          _buildTabIcon(_EditorPanel.draw, Icons.brush_rounded, 'Çiz'),
          _buildTabIcon(_EditorPanel.hide, Icons.hide_image_outlined, 'Gizle'),
          _buildTabIcon(_EditorPanel.filter, Icons.tune_rounded, 'Filtre'),
        ],
      ),
    );
  }

  Widget _buildTabIcon(_EditorPanel panel, IconData icon, String label) {
    final selected = _activePanel == panel;
    final active = _decodedImage != null && !_isSaving;
    final color = selected
        ? Colors.white
        : active
        ? Colors.white60
        : Colors.white30;
    return GestureDetector(
      onTap: active ? () => _changePanel(panel) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelControls(
    BuildContext context, {
    required Size viewport,
    required _OverlaySticker? selectedSticker,
    required _HideRegion? selectedHideRegion,
  }) {
    if (_decodedImage == null) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(_activePanel),
        child: switch (_activePanel) {
          _EditorPanel.crop => _buildCropControls(context),
          _EditorPanel.text => _buildTextControls(context, selectedSticker),
          _EditorPanel.draw => _buildDrawControls(context),
          _EditorPanel.hide => _buildHideControls(context, selectedHideRegion),
          _EditorPanel.filter => _buildFilterControls(context),
        },
      ),
    );
  }

  Widget _buildCropControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _aspectChoices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final choice = _aspectChoices[index];
                final selected =
                    (choice.ratio == null && _selectedAspectRatio == null) ||
                    (choice.ratio != null &&
                        _selectedAspectRatio != null &&
                        (choice.ratio! - _selectedAspectRatio!).abs() < 0.001);
                return _OverlayChip(
                  label: choice.label,
                  selected: selected,
                  onTap: _isSaving
                      ? null
                      : () => _selectAspectRatio(choice.ratio),
                );
              },
            ),
          ),
          if (_isFreeformCrop) ...[
            const SizedBox(height: 8),
            _OverlaySlider(
              label: 'Gen',
              value: _freeformWidthFactor,
              min: 0.35,
              max: 1,
              onChanged: _isSaving ? null : _setFreeformWidthFactor,
            ),
            _OverlaySlider(
              label: 'Yük',
              value: _freeformHeightFactor,
              min: 0.35,
              max: 1,
              onChanged: _isSaving ? null : _setFreeformHeightFactor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextControls(BuildContext context, _OverlaySticker? sticker) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _OverlayChip(
                  label: '+ Yazı',
                  selected: false,
                  onTap: _isSaving ? null : _addSticker,
                ),
                if (sticker != null) ...[
                  const SizedBox(width: 10),
                  _OverlayIconBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Düzenle',
                    onTap: _isSaving ? null : _editSelectedSticker,
                  ),
                  const SizedBox(width: 8),
                  _OverlayIconBtn(
                    icon: Icons.close_rounded,
                    tooltip: 'Sil',
                    onTap: _isSaving ? null : _deleteSelectedSticker,
                  ),
                ],
              ],
            ),
          ),
          if (sticker != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _stickerColors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final choice = _stickerColors[index];
                  final sel = sticker.textColor == choice.color;
                  return GestureDetector(
                    onTap: _isSaving
                        ? null
                        : () => _updateSelectedStickerColor(choice.color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: choice.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? Colors.white : Colors.white30,
                          width: sel ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: _stickerFonts.length + 4,
                itemBuilder: (context, index) {
                  if (index < _stickerFonts.length) {
                    final font = _stickerFonts[index];
                    return _OverlayChip(
                      label: font.label,
                      selected: sticker.fontKind == font.kind,
                      onTap: _isSaving
                          ? null
                          : () => _updateSelectedStickerFont(font.kind),
                    );
                  }
                  const bgs = <(_StickerBackgroundStyle, String)>[
                    (_StickerBackgroundStyle.none, 'Şeffaf'),
                    (_StickerBackgroundStyle.soft, 'Yumuşak'),
                    (_StickerBackgroundStyle.dark, 'Koyu'),
                    (_StickerBackgroundStyle.light, 'Açık'),
                  ];
                  final (style, lbl) = bgs[index - _stickerFonts.length];
                  return _OverlayChip(
                    label: lbl,
                    selected: sticker.backgroundStyle == style,
                    onTap: _isSaving
                        ? null
                        : () => _updateSelectedStickerBackground(style),
                  );
                },
              ),
            ),
            _OverlaySlider(
              label: 'Boyut',
              value: sticker.scale.clamp(0.5, 4.0),
              min: 0.5,
              max: 4.0,
              onChanged: _isSaving ? null : _updateSelectedStickerScale,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _OverlayChip(
                  label: 'Kalem',
                  selected: _brushMode == _BrushMode.pen,
                  onTap: _isSaving
                      ? null
                      : () => _changeBrushMode(_BrushMode.pen),
                ),
                const SizedBox(width: 8),
                _OverlayChip(
                  label: 'Vurgulayıcı',
                  selected: _brushMode == _BrushMode.highlighter,
                  onTap: _isSaving
                      ? null
                      : () => _changeBrushMode(_BrushMode.highlighter),
                ),
                const Spacer(),
                if (_strokes.isNotEmpty)
                  _OverlayIconBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Çizimleri temizle',
                    onTap: _isSaving ? null : _clearDrawings,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: 6,
              itemBuilder: (context, index) {
                const swatches = <Color>[
                  Colors.white,
                  Color(0xFFFACC15),
                  Color(0xFF93C5FD),
                  Color(0xFFF9A8D4),
                  Color(0xFF86EFAC),
                  Color(0xFFFCA5A5),
                ];
                final swatch = swatches[index];
                final sel = _drawColor == swatch;
                return GestureDetector(
                  onTap: _isSaving ? null : () => _changeDrawColor(swatch),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? Colors.white : Colors.white30,
                        width: sel ? 3 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _OverlaySlider(
            label: 'Kalın',
            value: _drawWidth.clamp(2.0, 26.0),
            min: 2,
            max: 26,
            onChanged: _isSaving ? null : _changeDrawWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildHideControls(BuildContext context, _HideRegion? region) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _OverlayChip(
                  label: '+ Gizle',
                  selected: false,
                  onTap: _isSaving ? null : _addHideRegion,
                ),
                if (region != null) ...[
                  const SizedBox(width: 8),
                  _OverlayChip(
                    label: 'Blur',
                    selected: region.style == _HideRegionStyle.blur,
                    onTap: _isSaving
                        ? null
                        : () => _updateSelectedHideStyle(_HideRegionStyle.blur),
                  ),
                  const SizedBox(width: 8),
                  _OverlayChip(
                    label: 'Mozaik',
                    selected: region.style == _HideRegionStyle.mosaic,
                    onTap: _isSaving
                        ? null
                        : () =>
                              _updateSelectedHideStyle(_HideRegionStyle.mosaic),
                  ),
                  const SizedBox(width: 8),
                  _OverlayChip(
                    label: region.aspectLocked ? 'Kilitli' : 'Serbest',
                    selected: region.aspectLocked,
                    onTap: _isSaving ? null : _toggleSelectedHideAspectLock,
                  ),
                  const Spacer(),
                  _OverlayIconBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Sil',
                    onTap: _isSaving ? null : _deleteSelectedHideRegion,
                  ),
                ],
              ],
            ),
          ),
          if (region != null && !region.aspectLocked) ...[
            const SizedBox(height: 8),
            _OverlaySlider(
              label: 'Gen',
              value: region.size.width,
              min: 0.12,
              max: 0.82,
              onChanged: _isSaving
                  ? null
                  : (value) => _resizeSelectedHideRegion(width: value),
            ),
            _OverlaySlider(
              label: 'Yük',
              value: region.size.height,
              min: 0.08,
              max: 0.82,
              onChanged: _isSaving
                  ? null
                  : (value) => _resizeSelectedHideRegion(height: value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: _filterPresets.length + 1,
              itemBuilder: (context, index) {
                if (index == _filterPresets.length) {
                  return _OverlayChip(
                    label: 'Sıfırla',
                    selected: false,
                    onTap: _isSaving ? null : _resetFilters,
                  );
                }
                final preset = _filterPresets[index];
                return _OverlayChip(
                  label: preset.label,
                  selected: false,
                  onTap: _isSaving ? null : () => _applyFilterPreset(preset),
                );
              },
            ),
          ),
          _OverlaySlider(
            label: 'Prlk',
            value: _brightness,
            min: -0.35,
            max: 0.35,
            onChanged: _isSaving ? null : _setBrightness,
          ),
          _OverlaySlider(
            label: 'Krst',
            value: _contrast,
            min: 0.7,
            max: 1.4,
            onChanged: _isSaving ? null : _setContrast,
          ),
          _OverlaySlider(
            label: 'Scklk',
            value: _warmth,
            min: -0.4,
            max: 0.4,
            onChanged: _isSaving ? null : _setWarmth,
          ),
          _OverlaySlider(
            label: 'Dygn',
            value: _saturation,
            min: 0,
            max: 1.5,
            onChanged: _isSaving ? null : _setSaturation,
          ),
        ],
      ),
    );
  }

  void _changePanel(_EditorPanel panel) {
    setState(() {
      _activePanel = panel;
      _showOriginalPreview = false;
      if (panel != _EditorPanel.text) _selectedStickerId = null;
      if (panel != _EditorPanel.hide) _selectedHideRegionId = null;
    });
  }

  _DrawStroke? get _currentStroke {
    if (_currentStrokePoints.isEmpty) return null;
    return _DrawStroke(
      points: _currentStrokePoints,
      color: _drawColor,
      width: _drawWidth,
      mode: _brushMode,
    );
  }

  _OverlaySticker? get _selectedSticker {
    final selectedId = _selectedStickerId;
    if (selectedId == null) return null;
    for (final sticker in _stickers) {
      if (sticker.id == selectedId) return sticker;
    }
    return null;
  }

  _HideRegion? get _selectedHideRegion {
    final selectedId = _selectedHideRegionId;
    if (selectedId == null) return null;
    for (final region in _hideRegions) {
      if (region.id == selectedId) return region;
    }
    return null;
  }

  double? get _rotatedImageRatio {
    final image = _decodedImage;
    if (image == null || image.height == 0 || image.width == 0) return null;
    final turns = _quarterTurns % 2;
    if (turns == 0) return image.width / image.height;
    return image.height / image.width;
  }

  Size get _unrotatedDisplaySize {
    final image = _decodedImage;
    if (image == null) return Size.zero;
    return _constrainSize(
      Size(image.width.toDouble(), image.height.toDouble()),
      maxDimension: 1600,
    );
  }

  int? get _cacheWidth {
    final width = _unrotatedDisplaySize.width.toInt();
    return width > 0 ? width : null;
  }

  int? get _cacheHeight {
    final height = _unrotatedDisplaySize.height.toInt();
    return height > 0 ? height : null;
  }

  bool get _isFreeformCrop => _selectedAspectRatio == null;

  Future<void> _loadImage() async {
    final bytes = await widget.sourceFile.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final largestSide = math.max(descriptor.width, descriptor.height);
    final scale = largestSide <= _maxDecodedDimension
        ? 1.0
        : _maxDecodedDimension / largestSide;
    final codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _decodedImage = frame.image;
    });
  }

  Size _computeStageSize(Size available) {
    final maxWidth = math.max(available.width, 160.0);
    final maxHeight = math.max(available.height, 160.0);
    return Size(maxWidth, maxHeight);
  }

  Size _computeCropFrameSize(Size stage, double ratio) {
    final maxWidth = math.max(stage.width * 0.9, 160.0);
    final maxHeight = math.max(stage.height * 0.76, 160.0);
    if (_isFreeformCrop) {
      return Size(
        maxWidth * _freeformWidthFactor,
        maxHeight * _freeformHeightFactor,
      );
    }
    var width = maxWidth;
    var height = width / ratio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }
    return Size(width, height);
  }

  void _updateViewport(Size nextViewport, Size nextStage) {
    if (_decodedImage == null) return;
    final widthDelta = (nextViewport.width - _viewportSize.width).abs();
    final heightDelta = (nextViewport.height - _viewportSize.height).abs();
    final stageWidthDelta = (nextStage.width - _stageSize.width).abs();
    final stageHeightDelta = (nextStage.height - _stageSize.height).abs();
    if (widthDelta < 0.5 &&
        heightDelta < 0.5 &&
        stageWidthDelta < 0.5 &&
        stageHeightDelta < 0.5 &&
        _displayImageSize != Size.zero) {
      return;
    }

    Offset? normalizedCenter;
    double? relativeZoom;
    final previousViewport = _viewportSize;
    final previousDisplaySize = _displayImageSize;
    final previousBaseScale = _baseScale;
    if (previousViewport != Size.zero &&
        previousDisplaySize != Size.zero &&
        previousBaseScale > 0) {
      final cropOrigin = _cropFrameOrigin(previousViewport, _stageSize);
      final topLeft = _controller.toScene(cropOrigin);
      final bottomRight = _controller.toScene(
        cropOrigin + Offset(previousViewport.width, previousViewport.height),
      );
      normalizedCenter = Offset(
        ((topLeft.dx + bottomRight.dx) / 2 / previousDisplaySize.width).clamp(
          0.0,
          1.0,
        ),
        ((topLeft.dy + bottomRight.dy) / 2 / previousDisplaySize.height).clamp(
          0.0,
          1.0,
        ),
      );
      relativeZoom = (_controller.value.getMaxScaleOnAxis() / previousBaseScale)
          .clamp(1.0, 6.0);
    }

    _viewportSize = nextViewport;
    _stageSize = nextStage;
    final originalSize = _unrotatedDisplaySize;
    _displayImageSize = (_quarterTurns % 2 == 0)
        ? originalSize
        : Size(originalSize.height, originalSize.width);
    _baseScale = math.max(
      nextViewport.width / _displayImageSize.width,
      nextViewport.height / _displayImageSize.height,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSaving) return;
      if (normalizedCenter != null && relativeZoom != null) {
        _setImageTransform(center: normalizedCenter, zoom: relativeZoom);
      } else {
        _resetImageTransform();
      }
    });
  }

  void _resetImageTransform() {
    _setImageTransform(center: const Offset(0.5, 0.5), zoom: 1);
  }

  void _setImageTransform({required Offset center, required double zoom}) {
    if (_displayImageSize == Size.zero ||
        _viewportSize == Size.zero ||
        _stageSize == Size.zero) {
      return;
    }
    final scale = _baseScale * zoom.clamp(1.0, 6.0);
    final sceneCenter = Offset(
      center.dx.clamp(0.0, 1.0) * _displayImageSize.width,
      center.dy.clamp(0.0, 1.0) * _displayImageSize.height,
    );
    final cropOrigin = _cropFrameOrigin(_viewportSize, _stageSize);
    final cropCenter =
        cropOrigin + Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final dx = cropCenter.dx - (sceneCenter.dx * scale);
    final dy = cropCenter.dy - (sceneCenter.dy * scale);
    _controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  Offset _cropFrameOrigin(Size viewport, Size stage) {
    if (viewport == Size.zero || stage == Size.zero) return Offset.zero;
    return Offset(
      (stage.width - viewport.width) / 2,
      (stage.height - viewport.height) / 2,
    );
  }

  void _resetAll() {
    setState(() {
      _selectedAspectRatio = widget.initialAspectRatio;
      _quarterTurns = 0;
      _activePanel = _EditorPanel.crop;
      _showOriginalPreview = false;
      _freeformWidthFactor = 1;
      _freeformHeightFactor = 1;
      _selectedStickerId = null;
      _stickers = const [];
      _strokes = const [];
      _currentStrokePoints = const [];
      _selectedHideRegionId = null;
      _hideRegions = const [];
      _brightness = 0;
      _contrast = 1;
      _warmth = 0;
      _saturation = 1;
      _drawColor = Colors.white;
      _drawWidth = 8;
      _brushMode = _BrushMode.pen;
      _viewportSize = Size.zero;
      _stageSize = Size.zero;
    });
  }

  void _setOriginalPreview(bool visible) {
    if (!mounted || _showOriginalPreview == visible) return;
    setState(() {
      _showOriginalPreview = visible;
      if (visible) {
        _selectedStickerId = null;
        _selectedHideRegionId = null;
      }
    });
  }

  void _rotateImage() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _viewportSize = Size.zero;
      _stageSize = Size.zero;
      _selectedStickerId = null;
      _selectedHideRegionId = null;
    });
  }

  void _selectAspectRatio(double? ratio) {
    setState(() {
      _selectedAspectRatio = ratio;
      if (ratio == null) {
        _freeformWidthFactor = _freeformWidthFactor.clamp(0.35, 1.0);
        _freeformHeightFactor = _freeformHeightFactor.clamp(0.35, 1.0);
      }
      _viewportSize = Size.zero;
      _stageSize = Size.zero;
    });
  }

  void _setFreeformWidthFactor(double value) {
    setState(() {
      _selectedAspectRatio = null;
      _freeformWidthFactor = value.clamp(0.35, 1.0);
      _viewportSize = Size.zero;
      _stageSize = Size.zero;
    });
  }

  void _setFreeformHeightFactor(double value) {
    setState(() {
      _selectedAspectRatio = null;
      _freeformHeightFactor = value.clamp(0.35, 1.0);
      _viewportSize = Size.zero;
      _stageSize = Size.zero;
    });
  }

  Future<void> _addSticker() async {
    final text = await _openStickerDialog();
    if (!mounted || text == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _activePanel = _EditorPanel.text;
      final sticker = _OverlaySticker(
        id: _nextStickerId++,
        text: trimmed,
        anchor: const Offset(0.5, 0.22),
        scale: 1,
        textColor: Colors.white,
        backgroundStyle: _StickerBackgroundStyle.soft,
        fontKind: _StickerFontKind.sans,
        textAlign: TextAlign.center,
        bold: true,
      );
      _stickers = [..._stickers, sticker];
      _selectedStickerId = sticker.id;
    });
  }

  Future<void> _editSelectedSticker() async {
    final selected = _selectedSticker;
    if (selected == null) return;
    final text = await _openStickerDialog(initialValue: selected.text);
    if (!mounted || text == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          sticker.id == selected.id ? sticker.copyWith(text: trimmed) : sticker,
      ];
    });
  }

  void _deleteSelectedSticker() {
    final selectedId = _selectedStickerId;
    if (selectedId == null) return;
    setState(() {
      _stickers = _stickers
          .where((sticker) => sticker.id != selectedId)
          .toList();
      _selectedStickerId = null;
    });
  }

  Future<String?> _openStickerDialog({String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    try {
      return showDialog<String>(
        context: context,
        builder: (context) {
          final tokens = Theme.of(context).sdal;
          return AlertDialog(
            backgroundColor: tokens.panelRaised,
            title: Text(
              initialValue == null ? 'Yazı veya emoji ekle' : 'Yazıyı düzenle',
              style: TextStyle(color: tokens.foreground),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              maxLines: 3,
              style: TextStyle(color: tokens.foreground),
              decoration: InputDecoration(
                hintText: 'Merhaba, 🎉, Yeni ürün...',
                hintStyle: TextStyle(color: tokens.foregroundMuted),
                filled: true,
                fillColor: tokens.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _updateSelectedStickerScale(double value) {
    final selected = _selectedSticker;
    if (selected == null) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          sticker.id == selected.id ? sticker.copyWith(scale: value) : sticker,
      ];
    });
  }

  void _updateSelectedStickerColor(Color color) {
    final selected = _selectedSticker;
    if (selected == null) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          sticker.id == selected.id
              ? sticker.copyWith(textColor: color)
              : sticker,
      ];
    });
  }

  void _updateSelectedStickerBackground(_StickerBackgroundStyle style) {
    final selected = _selectedSticker;
    if (selected == null) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          sticker.id == selected.id
              ? sticker.copyWith(backgroundStyle: style)
              : sticker,
      ];
    });
  }

  void _updateSelectedStickerFont(_StickerFontKind kind) {
    final selected = _selectedSticker;
    if (selected == null) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          sticker.id == selected.id
              ? sticker.copyWith(fontKind: kind)
              : sticker,
      ];
    });
  }

  Widget _buildSticker(_OverlaySticker sticker, Size viewport) {
    final left = sticker.anchor.dx * viewport.width;
    final top = sticker.anchor.dy * viewport.height;
    final selected = sticker.id == _selectedStickerId;
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activePanel = _EditorPanel.text;
            _selectedStickerId = sticker.id;
          });
        },
        onScaleStart: (_) {
          setState(() {
            _activePanel = _EditorPanel.text;
            _selectedStickerId = sticker.id;
          });
          _stickerBaseScale = sticker.scale;
        },
        onScaleUpdate: (details) =>
            _transformSticker(sticker.id, details, viewport),
        onScaleEnd: (_) => _stickerBaseScale = null,
        child: Transform.translate(
          offset: const Offset(-38, -20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _stickerBackgroundColor(sticker.backgroundStyle),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      sticker.text,
                      textAlign: sticker.textAlign,
                      style: TextStyle(
                        color: sticker.textColor,
                        fontSize: 20 * sticker.scale,
                        fontWeight: sticker.bold
                            ? FontWeight.w800
                            : FontWeight.w500,
                        height: 1.08,
                        fontFamily: _fontFamilyFor(sticker.fontKind),
                        shadows: [
                          Shadow(
                            color: _shadowColorFor(
                              sticker.textColor,
                              sticker.backgroundStyle,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: -12,
                  bottom: -12,
                  child: _LayerResizeHandle(
                    onPanUpdate: (details) =>
                        _resizeStickerByDrag(sticker.id, details),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _resizeStickerByDrag(int id, DragUpdateDetails details) {
    final delta = details.delta.dx + details.delta.dy;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          if (sticker.id == id)
            sticker.copyWith(
              scale: (sticker.scale + (delta / 160)).clamp(0.5, 4.0),
            )
          else
            sticker,
      ];
    });
  }

  String? _fontFamilyFor(_StickerFontKind kind) {
    for (final item in _stickerFonts) {
      if (item.kind == kind) return item.family;
    }
    return null;
  }

  void _transformSticker(int id, ScaleUpdateDetails details, Size viewport) {
    final width = viewport.width <= 0 ? 1.0 : viewport.width;
    final height = viewport.height <= 0 ? 1.0 : viewport.height;
    final baseScale = _stickerBaseScale;
    if (baseScale == null) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          if (sticker.id == id)
            sticker.copyWith(
              anchor: Offset(
                (sticker.anchor.dx + (details.focalPointDelta.dx / width))
                    .clamp(0.08, 0.92),
                (sticker.anchor.dy + (details.focalPointDelta.dy / height))
                    .clamp(0.08, 0.92),
              ),
              scale: (baseScale * details.scale).clamp(0.5, 4.0),
            )
          else
            sticker,
      ];
    });
  }

  void _startStroke(DragStartDetails details) {
    setState(() {
      _currentStrokePoints = [_normalizeViewportPoint(details.localPosition)];
    });
  }

  void _extendStroke(DragUpdateDetails details) {
    setState(() {
      _currentStrokePoints = [
        ..._currentStrokePoints,
        _normalizeViewportPoint(details.localPosition),
      ];
    });
  }

  void _finishStroke(DragEndDetails details) {
    if (_currentStrokePoints.length < 2) {
      setState(() => _currentStrokePoints = const []);
      return;
    }
    setState(() {
      _strokes = [
        ..._strokes,
        _DrawStroke(
          points: _currentStrokePoints,
          color: _drawColor,
          width: _drawWidth,
          mode: _brushMode,
        ),
      ];
      _currentStrokePoints = const [];
    });
  }

  void _changeDrawColor(Color color) {
    setState(() => _drawColor = color);
  }

  void _changeDrawWidth(double width) {
    setState(() => _drawWidth = width);
  }

  void _changeBrushMode(_BrushMode mode) {
    setState(() => _brushMode = mode);
  }

  void _clearDrawings() {
    setState(() => _strokes = const []);
  }

  Offset _normalizeViewportPoint(Offset point) {
    final width = _viewportSize.width <= 0 ? 1.0 : _viewportSize.width;
    final height = _viewportSize.height <= 0 ? 1.0 : _viewportSize.height;
    return Offset(
      (point.dx / width).clamp(0.0, 1.0),
      (point.dy / height).clamp(0.0, 1.0),
    );
  }

  void _addHideRegion() {
    setState(() {
      _activePanel = _EditorPanel.hide;
      final region = _HideRegion(
        id: _nextHideRegionId++,
        center: const Offset(0.5, 0.5),
        size: const Size(0.32, 0.18),
        style: _HideRegionStyle.blur,
      );
      _hideRegions = [..._hideRegions, region];
      _selectedHideRegionId = region.id;
    });
  }

  void _deleteSelectedHideRegion() {
    final selectedId = _selectedHideRegionId;
    if (selectedId == null) return;
    setState(() {
      _hideRegions = _hideRegions
          .where((region) => region.id != selectedId)
          .toList();
      _selectedHideRegionId = null;
    });
  }

  void _updateSelectedHideStyle(_HideRegionStyle style) {
    final selected = _selectedHideRegion;
    if (selected == null) return;
    setState(() {
      _hideRegions = [
        for (final region in _hideRegions)
          region.id == selected.id ? region.copyWith(style: style) : region,
      ];
    });
  }

  void _toggleSelectedHideAspectLock() {
    final selected = _selectedHideRegion;
    if (selected == null) return;
    setState(() {
      _hideRegions = [
        for (final region in _hideRegions)
          region.id == selected.id
              ? region.copyWith(aspectLocked: !region.aspectLocked)
              : region,
      ];
    });
  }

  void _resizeSelectedHideRegion({double? width, double? height}) {
    final selected = _selectedHideRegion;
    if (selected == null) return;
    setState(() {
      _hideRegions = [
        for (final region in _hideRegions)
          region.id == selected.id
              ? region.copyWith(
                  size: Size(
                    (width ?? region.size.width).clamp(0.12, 0.82),
                    (height ?? region.size.height).clamp(0.08, 0.82),
                  ),
                )
              : region,
      ];
    });
  }

  Widget _buildHideRegion(_HideRegion region, Size viewport) {
    final selected = region.id == _selectedHideRegionId;
    final width = viewport.width * region.size.width;
    final height = viewport.height * region.size.height;
    final left = viewport.width * region.center.dx - (width / 2);
    final top = viewport.height * region.center.dy - (height / 2);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activePanel = _EditorPanel.hide;
                  _selectedHideRegionId = region.id;
                });
              },
              onScaleStart: (_) {
                setState(() {
                  _activePanel = _EditorPanel.hide;
                  _selectedHideRegionId = region.id;
                });
                _hideRegionBaseSize = region.size;
              },
              onScaleUpdate: (details) =>
                  _transformHideRegion(region.id, details, viewport),
              onScaleEnd: (_) => _hideRegionBaseSize = null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: region.style == _HideRegionStyle.blur ? 14 : 6,
                        sigmaY: region.style == _HideRegionStyle.blur ? 14 : 6,
                      ),
                      child: Container(
                        color: region.style == _HideRegionStyle.blur
                            ? Colors.black.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.28),
                      ),
                    ),
                    if (region.style == _HideRegionStyle.mosaic)
                      CustomPaint(painter: _MosaicOverlayPainter()),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: selected ? 1.8 : 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected) ..._buildHideResizeHandles(region, viewport),
        ],
      ),
    );
  }

  List<Widget> _buildHideResizeHandles(_HideRegion region, Size viewport) {
    final handles = <Widget>[
      _positionedResizeHandle(
        left: -12,
        top: -12,
        onPanUpdate: (details) => _resizeHideRegionByHandle(
          region.id,
          _ResizeHandle.topLeft,
          details,
          viewport,
        ),
      ),
      _positionedResizeHandle(
        right: -12,
        top: -12,
        onPanUpdate: (details) => _resizeHideRegionByHandle(
          region.id,
          _ResizeHandle.topRight,
          details,
          viewport,
        ),
      ),
      _positionedResizeHandle(
        right: -12,
        bottom: -12,
        onPanUpdate: (details) => _resizeHideRegionByHandle(
          region.id,
          _ResizeHandle.bottomRight,
          details,
          viewport,
        ),
      ),
      _positionedResizeHandle(
        left: -12,
        bottom: -12,
        onPanUpdate: (details) => _resizeHideRegionByHandle(
          region.id,
          _ResizeHandle.bottomLeft,
          details,
          viewport,
        ),
      ),
    ];

    if (!region.aspectLocked) {
      handles.addAll([
        _positionedResizeHandle(
          top: -12,
          centerX: true,
          onPanUpdate: (details) => _resizeHideRegionByHandle(
            region.id,
            _ResizeHandle.top,
            details,
            viewport,
          ),
        ),
        _positionedResizeHandle(
          right: -12,
          centerY: true,
          onPanUpdate: (details) => _resizeHideRegionByHandle(
            region.id,
            _ResizeHandle.right,
            details,
            viewport,
          ),
        ),
        _positionedResizeHandle(
          bottom: -12,
          centerX: true,
          onPanUpdate: (details) => _resizeHideRegionByHandle(
            region.id,
            _ResizeHandle.bottom,
            details,
            viewport,
          ),
        ),
        _positionedResizeHandle(
          left: -12,
          centerY: true,
          onPanUpdate: (details) => _resizeHideRegionByHandle(
            region.id,
            _ResizeHandle.left,
            details,
            viewport,
          ),
        ),
      ]);
    }

    return handles;
  }

  Widget _positionedResizeHandle({
    double? left,
    double? top,
    double? right,
    double? bottom,
    bool centerX = false,
    bool centerY = false,
    required GestureDragUpdateCallback onPanUpdate,
  }) {
    final handle = _LayerResizeHandle(onPanUpdate: onPanUpdate);
    if (centerX) {
      return Positioned(
        left: 0,
        top: top,
        right: 0,
        bottom: bottom,
        child: Center(child: handle),
      );
    }
    if (centerY) {
      return Positioned(
        left: left,
        top: 0,
        right: right,
        bottom: 0,
        child: Center(child: handle),
      );
    }
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: handle,
    );
  }

  void _resizeHideRegionByHandle(
    int id,
    _ResizeHandle handle,
    DragUpdateDetails details,
    Size viewport,
  ) {
    final viewportWidth = viewport.width <= 0 ? 1.0 : viewport.width;
    final viewportHeight = viewport.height <= 0 ? 1.0 : viewport.height;
    final dx = details.delta.dx / viewportWidth;
    final dy = details.delta.dy / viewportHeight;

    setState(() {
      _hideRegions = [
        for (final region in _hideRegions)
          if (region.id == id)
            _resizeHideRegion(region, handle, dx, dy)
          else
            region,
      ];
    });
  }

  _HideRegion _resizeHideRegion(
    _HideRegion region,
    _ResizeHandle handle,
    double dx,
    double dy,
  ) {
    var left = region.center.dx - (region.size.width / 2);
    var right = region.center.dx + (region.size.width / 2);
    var top = region.center.dy - (region.size.height / 2);
    var bottom = region.center.dy + (region.size.height / 2);

    switch (handle) {
      case _ResizeHandle.topLeft:
        left += dx;
        top += dy;
      case _ResizeHandle.top:
        top += dy;
      case _ResizeHandle.topRight:
        right += dx;
        top += dy;
      case _ResizeHandle.right:
        right += dx;
      case _ResizeHandle.bottomRight:
        right += dx;
        bottom += dy;
      case _ResizeHandle.bottom:
        bottom += dy;
      case _ResizeHandle.bottomLeft:
        left += dx;
        bottom += dy;
      case _ResizeHandle.left:
        left += dx;
    }

    if (region.aspectLocked) {
      final aspect = region.size.width / math.max(region.size.height, 0.01);
      final oldWidth = region.size.width;
      final oldHeight = region.size.height;
      final widthDelta = (right - left) - oldWidth;
      final heightDelta = ((bottom - top) - oldHeight) * aspect;
      final nextWidth = (oldWidth + _dominantDelta(widthDelta, heightDelta))
          .clamp(0.12, 0.82);
      final nextHeight = (nextWidth / aspect).clamp(0.08, 0.82);
      final fixedCenter = region.center;
      return region.copyWith(
        center: Offset(
          fixedCenter.dx.clamp(0.06, 0.94),
          fixedCenter.dy.clamp(0.06, 0.94),
        ),
        size: Size(nextWidth, nextHeight),
      );
    }

    const minWidth = 0.12;
    const minHeight = 0.08;
    left = left.clamp(0.0, 1.0 - minWidth);
    right = right.clamp(minWidth, 1.0);
    top = top.clamp(0.0, 1.0 - minHeight);
    bottom = bottom.clamp(minHeight, 1.0);
    if (right - left < minWidth) {
      handle == _ResizeHandle.left
          ? left = right - minWidth
          : right = left + minWidth;
    }
    if (bottom - top < minHeight) {
      handle == _ResizeHandle.top
          ? top = bottom - minHeight
          : bottom = top + minHeight;
    }

    return region.copyWith(
      center: Offset((left + right) / 2, (top + bottom) / 2),
      size: Size(
        (right - left).clamp(0.12, 0.82),
        (bottom - top).clamp(0.08, 0.82),
      ),
    );
  }

  double _dominantDelta(double widthDelta, double heightDelta) {
    return widthDelta.abs() >= heightDelta.abs() ? widthDelta : heightDelta;
  }

  void _transformHideRegion(int id, ScaleUpdateDetails details, Size viewport) {
    final selected = _selectedHideRegion;
    final baseSize = _hideRegionBaseSize;
    if (selected == null || baseSize == null) return;
    final width = viewport.width <= 0 ? 1.0 : viewport.width;
    final height = viewport.height <= 0 ? 1.0 : viewport.height;
    setState(() {
      _hideRegions = [
        for (final region in _hideRegions)
          if (region.id == id)
            region.copyWith(
              center: Offset(
                (region.center.dx + (details.focalPointDelta.dx / width)).clamp(
                  0.12,
                  0.88,
                ),
                (region.center.dy + (details.focalPointDelta.dy / height))
                    .clamp(0.12, 0.88),
              ),
              size: region.aspectLocked
                  ? Size(
                      (baseSize.width * details.scale).clamp(0.12, 0.82),
                      (baseSize.height * details.scale).clamp(0.08, 0.82),
                    )
                  : Size(
                      (baseSize.width * details.horizontalScale).clamp(
                        0.12,
                        0.82,
                      ),
                      (baseSize.height * details.verticalScale).clamp(
                        0.08,
                        0.82,
                      ),
                    ),
            )
          else
            region,
      ];
    });
  }

  void _setBrightness(double value) {
    setState(() => _brightness = value);
  }

  void _setContrast(double value) {
    setState(() => _contrast = value);
  }

  void _setWarmth(double value) {
    setState(() => _warmth = value);
  }

  void _setSaturation(double value) {
    setState(() => _saturation = value);
  }

  void _resetFilters() {
    setState(() {
      _brightness = 0;
      _contrast = 1;
      _warmth = 0;
      _saturation = 1;
    });
  }

  void _applyFilterPreset(_FilterPreset preset) {
    setState(() {
      _brightness = preset.brightness;
      _contrast = preset.contrast;
      _warmth = preset.warmth;
      _saturation = preset.saturation;
    });
  }

  List<double> _buildColorMatrix() {
    final contrast = _contrast;
    final brightness = _brightness * 255;
    final warmth = _warmth;
    final saturation = _saturation;
    final rwgt = 0.3086;
    final gwgt = 0.6094;
    final bwgt = 0.0820;
    final satInv = 1 - saturation;
    final r = satInv * rwgt;
    final g = satInv * gwgt;
    final b = satInv * bwgt;
    final redScale = 1 + (warmth * 0.22);
    final blueScale = 1 - (warmth * 0.22);
    return <double>[
      contrast * (r + saturation) * redScale,
      contrast * g,
      contrast * b,
      0,
      brightness,
      contrast * r,
      contrast * (g + saturation),
      contrast * b,
      0,
      brightness,
      contrast * r,
      contrast * g,
      contrast * (b + saturation) * blueScale,
      0,
      brightness,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Color _stickerBackgroundColor(_StickerBackgroundStyle style) {
    return switch (style) {
      _StickerBackgroundStyle.none => Colors.transparent,
      _StickerBackgroundStyle.soft => Colors.black38,
      _StickerBackgroundStyle.dark => Colors.black87,
      _StickerBackgroundStyle.light => Colors.white.withValues(alpha: 0.92),
    };
  }

  Color _shadowColorFor(Color textColor, _StickerBackgroundStyle style) {
    if (style == _StickerBackgroundStyle.light) return Colors.black38;
    if (textColor.computeLuminance() < 0.35) return Colors.white24;
    return Colors.black87;
  }

  void _restoreInitialMetadata() {
    final metadata = widget.initialMetadata;
    if (metadata.isEmpty) return;

    final restoredAspectRatio = _readDouble(metadata['aspectRatio']);
    if (restoredAspectRatio != null) {
      _selectedAspectRatio = restoredAspectRatio;
    }
    _freeformWidthFactor = (_readDouble(metadata['freeformWidthFactor']) ?? 1)
        .clamp(0.35, 1.0);
    _freeformHeightFactor = (_readDouble(metadata['freeformHeightFactor']) ?? 1)
        .clamp(0.35, 1.0);

    final restoredQuarterTurns = _readInt(metadata['quarterTurns']) ?? 0;
    _quarterTurns = ((restoredQuarterTurns % 4) + 4) % 4;

    final filters = _readMap(metadata['filters']);
    _brightness = _readDouble(filters['brightness']) ?? 0;
    _contrast = _readDouble(filters['contrast']) ?? 1;
    _warmth = _readDouble(filters['warmth']) ?? 0;
    _saturation = _readDouble(filters['saturation']) ?? 1;

    final restoredStickers = <_OverlaySticker>[];
    for (final item in _readList(metadata['stickers'])) {
      final map = _readMap(item);
      final id =
          _readInt(map['id']) ?? (_nextStickerId + restoredStickers.length);
      restoredStickers.add(
        _OverlaySticker(
          id: id,
          text: _readString(map['text']) ?? '',
          anchor: Offset(
            _readDouble(map['anchorX']) ?? 0.5,
            _readDouble(map['anchorY']) ?? 0.22,
          ),
          scale: _readDouble(map['scale']) ?? 1,
          textColor: _colorFromValue(map['textColor'], fallback: Colors.white),
          backgroundStyle: _enumByName(
            _StickerBackgroundStyle.values,
            _readString(map['backgroundStyle']),
            _StickerBackgroundStyle.soft,
          ),
          fontKind: _enumByName(
            _StickerFontKind.values,
            _readString(map['fontKind']),
            _StickerFontKind.sans,
          ),
          textAlign: _enumByName(
            TextAlign.values,
            _readString(map['textAlign']),
            TextAlign.center,
          ),
          bold: _readBool(map['bold']) ?? true,
        ),
      );
    }
    if (restoredStickers.isNotEmpty) {
      _stickers = restoredStickers;
      _nextStickerId =
          restoredStickers.map((item) => item.id).fold<int>(0, math.max) + 1;
    }

    final restoredStrokes = <_DrawStroke>[];
    final metadataCoordinateSpace = _readString(metadata['coordinateSpace']);
    final metadataViewportWidth = _readDouble(metadata['viewportWidth']);
    final metadataViewportHeight = _readDouble(metadata['viewportHeight']);
    for (final item in _readList(metadata['strokes'])) {
      final map = _readMap(item);
      final points = <Offset>[
        for (final point in _readList(map['points']))
          _restoreStrokePoint(
            _readMap(point),
            coordinateSpace: metadataCoordinateSpace,
            viewportWidth: metadataViewportWidth,
            viewportHeight: metadataViewportHeight,
          ),
      ];
      if (points.length < 2) continue;
      restoredStrokes.add(
        _DrawStroke(
          points: points,
          color: _colorFromValue(map['color'], fallback: Colors.white),
          width: _readDouble(map['width']) ?? 8,
          mode: _enumByName(
            _BrushMode.values,
            _readString(map['mode']),
            _BrushMode.pen,
          ),
        ),
      );
    }
    if (restoredStrokes.isNotEmpty) {
      _strokes = restoredStrokes;
    }

    final restoredHideRegions = <_HideRegion>[];
    for (final item in _readList(metadata['hideRegions'])) {
      final map = _readMap(item);
      final id =
          _readInt(map['id']) ??
          (_nextHideRegionId + restoredHideRegions.length);
      restoredHideRegions.add(
        _HideRegion(
          id: id,
          center: Offset(
            _readDouble(map['centerX']) ?? 0.5,
            _readDouble(map['centerY']) ?? 0.5,
          ),
          size: Size(
            _readDouble(map['width']) ?? 0.32,
            _readDouble(map['height']) ?? 0.18,
          ),
          style: _enumByName(
            _HideRegionStyle.values,
            _readString(map['style']),
            _HideRegionStyle.blur,
          ),
          aspectLocked: _readBool(map['aspectLocked']) ?? true,
        ),
      );
    }
    if (restoredHideRegions.isNotEmpty) {
      _hideRegions = restoredHideRegions;
      _nextHideRegionId =
          restoredHideRegions.map((item) => item.id).fold<int>(0, math.max) + 1;
    }
  }

  Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _readList(Object? value) {
    return value is List ? value : const <dynamic>[];
  }

  String? _readString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _readDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool? _readBool(Object? value) {
    if (value is bool) return value;
    final raw = value?.toString().toLowerCase();
    if (raw == 'true' || raw == '1') return true;
    if (raw == 'false' || raw == '0') return false;
    return null;
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  Color _colorFromValue(Object? value, {required Color fallback}) {
    final raw = _readInt(value);
    if (raw == null) return fallback;
    return Color(raw & 0xFFFFFFFF);
  }

  Offset _restoreStrokePoint(
    Map<String, dynamic> point, {
    required String? coordinateSpace,
    required double? viewportWidth,
    required double? viewportHeight,
  }) {
    final x = _readDouble(point['x']) ?? 0;
    final y = _readDouble(point['y']) ?? 0;
    if (coordinateSpace == 'normalizedViewport' || (x <= 1 && y <= 1)) {
      return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
    }
    final width = (viewportWidth != null && viewportWidth > 0)
        ? viewportWidth
        : 390.0;
    final height = (viewportHeight != null && viewportHeight > 0)
        ? viewportHeight
        : 520.0;
    return Offset((x / width).clamp(0.0, 1.0), (y / height).clamp(0.0, 1.0));
  }

  Map<String, dynamic> _buildEditMetadata() {
    return {
      'version': 2,
      'coordinateSpace': 'normalizedViewport',
      'viewportWidth': _viewportSize.width,
      'viewportHeight': _viewportSize.height,
      'aspectRatio': _selectedAspectRatio,
      'freeformWidthFactor': _freeformWidthFactor,
      'freeformHeightFactor': _freeformHeightFactor,
      'quarterTurns': _quarterTurns,
      'filters': {
        'brightness': _brightness,
        'contrast': _contrast,
        'warmth': _warmth,
        'saturation': _saturation,
      },
      'stickers': _stickers
          .map(
            (sticker) => {
              'id': sticker.id,
              'text': sticker.text,
              'anchorX': sticker.anchor.dx,
              'anchorY': sticker.anchor.dy,
              'scale': sticker.scale,
              'textColor': sticker.textColor.toARGB32(),
              'backgroundStyle': sticker.backgroundStyle.name,
              'fontKind': sticker.fontKind.name,
              'textAlign': sticker.textAlign.name,
              'bold': sticker.bold,
            },
          )
          .toList(growable: false),
      'strokes': _strokes
          .map(
            (stroke) => {
              'color': stroke.color.toARGB32(),
              'width': stroke.width,
              'mode': stroke.mode.name,
              'points': stroke.points
                  .map((point) => {'x': point.dx, 'y': point.dy})
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'hideRegions': _hideRegions
          .map(
            (region) => {
              'id': region.id,
              'centerX': region.center.dx,
              'centerY': region.center.dy,
              'width': region.size.width,
              'height': region.size.height,
              'style': region.style.name,
              'aspectLocked': region.aspectLocked,
            },
          )
          .toList(growable: false),
    };
  }

  Future<void> _saveCrop() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      _logSaveStage('save-start');
      // Selection chrome and overlay UI must be removed before taking the snapshot.
      setState(() {
        _selectedStickerId = null;
        _selectedHideRegionId = null;
        _showOriginalPreview = false;
        _isCapturing = true;
      });

      await _waitForCaptureFrame();
      if (!mounted) return;
      _logSaveStage('capture-begin');
      final imageBytes = await _captureEditedImageBytes();
      if (mounted) setState(() => _isCapturing = false);
      _logSaveStage('capture-done', details: 'bytes=${imageBytes.length}');

      _logSaveStage('tempdir-begin');
      final tempDir = await Directory.systemTemp.createTemp('sdal-photo-edit-');
      final output = File(
        '${tempDir.path}/crop-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      _logSaveStage('write-begin', details: output.path);
      await output.writeAsBytes(imageBytes, flush: true);
      _logSaveStage('write-done', details: output.path);

      if (!mounted) return;
      _logSaveStage('navigator-pop');
      Navigator.of(context).pop(
        EditedMediaResult(
          file: output,
          sourceFile: widget.sourceFile,
          metadata: _buildEditMetadata(),
        ),
      );
    } catch (e, st) {
      _logSaveError(e, st);
      debugPrint('Save crop failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görsel şu an kaydedilemedi. Lütfen tekrar dene.'),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _waitForCaptureFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 32));
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<Uint8List> _captureEditedImageBytes() async {
    _logSaveStage('image-encode-begin');
    final bitmap = await _buildExportBitmap();
    final bytes = Uint8List.fromList(img.encodeJpg(bitmap, quality: 84));
    _logSaveStage(
      'image-encode-done',
      details: '${bitmap.width}x${bitmap.height} -> ${bytes.length} bytes',
    );
    return bytes;
  }

  Future<img.Image> _buildExportBitmap() async {
    _logSaveStage('bitmap-build-begin');
    final baseImage = await _decodeEditableBitmap();
    _logSaveStage(
      'bitmap-base-ready',
      details: '${baseImage.width}x${baseImage.height}',
    );
    final rotatedImage = _applyQuarterTurns(baseImage, _quarterTurns % 4);
    final cropRect = _resolveCropRectInRotatedBitmap(rotatedImage);
    _logSaveStage(
      'crop-rect-resolved',
      details:
          'x=${cropRect.left.round()} y=${cropRect.top.round()} w=${cropRect.width.round()} h=${cropRect.height.round()}',
    );
    var cropped = img.copyCrop(
      rotatedImage,
      x: cropRect.left.round(),
      y: cropRect.top.round(),
      width: cropRect.width.round(),
      height: cropRect.height.round(),
    );
    final constrainedOutputSize = _constrainSize(
      Size(cropped.width.toDouble(), cropped.height.toDouble()),
      maxDimension: _maxExportDimension,
    );
    final outputWidth = math.max(1, constrainedOutputSize.width.round());
    final outputHeight = math.max(1, constrainedOutputSize.height.round());
    if (cropped.width != outputWidth || cropped.height != outputHeight) {
      cropped = img.copyResize(
        cropped,
        width: outputWidth,
        height: outputHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    _logSaveStage(
      'bitmap-cropped',
      details: '${cropped.width}x${cropped.height}',
    );
    _applyColorMatrixToBitmap(cropped);
    _paintStrokesOnBitmap(cropped);
    _paintHideRegionsOnBitmap(cropped);
    _paintStickersOnBitmap(cropped);
    _logSaveStage('bitmap-build-done');
    return cropped;
  }

  Future<img.Image> _decodeEditableBitmap() async {
    _logSaveStage('decode-begin', details: widget.sourceFile.path);
    final sourceBytes = await widget.sourceFile.readAsBytes();
    _logSaveStage('decode-bytes-read', details: '${sourceBytes.length} bytes');
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw StateError('Gorsel decode edilemedi.');
    }
    var oriented = img.bakeOrientation(decoded);
    final largestSide = math.max(oriented.width, oriented.height).toDouble();
    if (largestSide > _maxDecodedDimension) {
      final scale = _maxDecodedDimension / largestSide;
      oriented = img.copyResize(
        oriented,
        width: math.max(1, (oriented.width * scale).round()),
        height: math.max(1, (oriented.height * scale).round()),
        interpolation: img.Interpolation.linear,
      );
    }
    _logSaveStage(
      'decode-done',
      details: 'source ${oriented.width}x${oriented.height}',
    );
    return oriented;
  }

  void _logSaveStage(String stage, {String? details}) {
    final message = details == null ? stage : '$stage | $details';
    developer.log(message, name: 'photo_editor.save');
    debugPrint('photo_editor.save: $message');
  }

  void _logSaveError(Object error, StackTrace stackTrace) {
    developer.log(
      '$error',
      name: 'photo_editor.save',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  img.Image _applyQuarterTurns(img.Image source, int turns) {
    return switch (turns % 4) {
      1 => img.copyRotate(source, angle: 90),
      2 => img.copyRotate(source, angle: 180),
      3 => img.copyRotate(source, angle: -90),
      _ => img.Image.from(source),
    };
  }

  Rect _resolveCropRectInRotatedBitmap(img.Image rotatedImage) {
    if (_viewportSize == Size.zero ||
        _stageSize == Size.zero ||
        _displayImageSize == Size.zero) {
      throw StateError('Kirpma alani hazir degil.');
    }

    final cropOrigin = _cropFrameOrigin(_viewportSize, _stageSize);
    final topLeft = _controller.toScene(cropOrigin);
    final bottomRight = _controller.toScene(
      cropOrigin + Offset(_viewportSize.width, _viewportSize.height),
    );
    final left = math
        .min(topLeft.dx, bottomRight.dx)
        .clamp(0.0, _displayImageSize.width);
    final top = math
        .min(topLeft.dy, bottomRight.dy)
        .clamp(0.0, _displayImageSize.height);
    final right = math
        .max(topLeft.dx, bottomRight.dx)
        .clamp(0.0, _displayImageSize.width);
    final bottom = math
        .max(topLeft.dy, bottomRight.dy)
        .clamp(0.0, _displayImageSize.height);
    final displayRect = Rect.fromLTRB(left, top, right, bottom);
    if (displayRect.width <= 0 || displayRect.height <= 0) {
      throw StateError('Kirpma alani hesaplanamadi.');
    }

    final scaleX = rotatedImage.width / _displayImageSize.width;
    final scaleY = rotatedImage.height / _displayImageSize.height;
    return Rect.fromLTRB(
      displayRect.left * scaleX,
      displayRect.top * scaleY,
      displayRect.right * scaleX,
      displayRect.bottom * scaleY,
    ).intersect(
      Rect.fromLTWH(
        0,
        0,
        rotatedImage.width.toDouble(),
        rotatedImage.height.toDouble(),
      ),
    );
  }

  void _applyColorMatrixToBitmap(img.Image image) {
    final matrix = _buildColorMatrix();
    final isIdentity =
        _brightness == 0 && _contrast == 1 && _warmth == 0 && _saturation == 1;
    if (isIdentity) return;

    for (final pixel in image) {
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();
      final nextR =
          (matrix[0] * r) + (matrix[1] * g) + (matrix[2] * b) + matrix[4];
      final nextG =
          (matrix[5] * r) + (matrix[6] * g) + (matrix[7] * b) + matrix[9];
      final nextB =
          (matrix[10] * r) + (matrix[11] * g) + (matrix[12] * b) + matrix[14];
      pixel
        ..r = nextR.clamp(0, 255).round()
        ..g = nextG.clamp(0, 255).round()
        ..b = nextB.clamp(0, 255).round();
    }
  }

  void _paintStrokesOnBitmap(img.Image image) {
    for (final stroke in _strokes) {
      if (stroke.points.length < 2) continue;
      final color = stroke.mode == _BrushMode.highlighter
          ? stroke.color.withValues(alpha: 0.34)
          : stroke.color;
      for (final segment in stroke.points.skip(1).indexed) {
        final start = stroke.points[segment.$1];
        final end = segment.$2;
        img.drawLine(
          image,
          x1: (start.dx * image.width).round(),
          y1: (start.dy * image.height).round(),
          x2: (end.dx * image.width).round(),
          y2: (end.dy * image.height).round(),
          color: _toImgColor(color),
          thickness: math.max(
            1,
            (stroke.width * math.max(image.width, image.height) / 720).round(),
          ),
          antialias: true,
        );
      }
    }
  }

  void _paintHideRegionsOnBitmap(img.Image image) {
    if (_viewportSize == Size.zero) return;
    if (image.isEmpty) return;
    final radius =
        18 *
        ((image.width / _viewportSize.width) +
            (image.height / _viewportSize.height)) /
        2;

    for (final region in _hideRegions) {
      final regionRect = Rect.fromCenter(
        center: Offset(
          region.center.dx * image.width,
          region.center.dy * image.height,
        ),
        width: image.width * region.size.width,
        height: image.height * region.size.height,
      );
      final clippedRegion = regionRect.intersect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );
      if (clippedRegion.isEmpty) continue;
      if (region.style == _HideRegionStyle.blur) {
        final sample = img.copyCrop(
          image,
          x: clippedRegion.left.round(),
          y: clippedRegion.top.round(),
          width: math.max(1, clippedRegion.width.round()),
          height: math.max(1, clippedRegion.height.round()),
          radius: radius,
        );
        img.gaussianBlur(sample, radius: 14);
        img.compositeImage(
          image,
          sample,
          dstX: clippedRegion.left.round(),
          dstY: clippedRegion.top.round(),
        );
        img.fillRect(
          image,
          x1: clippedRegion.left.round(),
          y1: clippedRegion.top.round(),
          x2: clippedRegion.right.round(),
          y2: clippedRegion.bottom.round(),
          color: _toImgColor(Colors.black.withValues(alpha: 0.16)),
          radius: radius,
        );
        continue;
      }
      img.fillRect(
        image,
        x1: clippedRegion.left.round(),
        y1: clippedRegion.top.round(),
        x2: clippedRegion.right.round(),
        y2: clippedRegion.bottom.round(),
        color: _toImgColor(Colors.black.withValues(alpha: 0.28)),
        radius: radius,
      );
      _paintMosaicRegion(image, clippedRegion);
    }
  }

  void _paintMosaicRegion(img.Image image, Rect rect) {
    const step = 10.0;
    final color = _toImgColor(Colors.white.withValues(alpha: 0.16));
    for (double x = rect.left; x < rect.right; x += step) {
      img.drawLine(
        image,
        x1: x.round(),
        y1: rect.top.round(),
        x2: x.round(),
        y2: rect.bottom.round(),
        color: color,
      );
    }
    for (double y = rect.top; y < rect.bottom; y += step) {
      img.drawLine(
        image,
        x1: rect.left.round(),
        y1: y.round(),
        x2: rect.right.round(),
        y2: y.round(),
        color: color,
      );
    }
  }

  void _paintStickersOnBitmap(img.Image image) {
    if (_viewportSize == Size.zero) return;
    final scaleX = image.width / _viewportSize.width;
    final scaleY = image.height / _viewportSize.height;
    final visualScale = (scaleX + scaleY) / 2;

    for (final sticker in _stickers) {
      if (sticker.text.trim().isEmpty) continue;
      final font = _fontForSticker(sticker, visualScale);
      final lines = sticker.text.split(RegExp(r'\r?\n'));
      final textWidths = [
        for (final line in lines) _measureBitmapTextWidth(font, line),
      ];
      final textWidth = textWidths.fold<int>(0, math.max);
      final lineHeight = font.lineHeight > 0 ? font.lineHeight : font.base;
      final textHeight = math.max(lineHeight, lineHeight * lines.length);
      final paddingX = math.max(6, (14 * scaleX).round());
      final paddingY = math.max(4, (8 * scaleY).round());
      final backgroundRect = Rect.fromLTWH(
        (sticker.anchor.dx * image.width) + (-38 * scaleX),
        (sticker.anchor.dy * image.height) + (-20 * scaleY),
        (textWidth + (paddingX * 2)).toDouble(),
        (textHeight + (paddingY * 2)).toDouble(),
      );
      final backgroundColor = _stickerBackgroundColor(sticker.backgroundStyle);
      if (backgroundColor.toARGB32() != 0) {
        img.fillRect(
          image,
          x1: backgroundRect.left.round(),
          y1: backgroundRect.top.round(),
          x2: backgroundRect.right.round(),
          y2: backgroundRect.bottom.round(),
          color: _toImgColor(backgroundColor),
          radius: 18 * visualScale,
        );
      }

      final shadowColor = _toImgColor(
        _shadowColorFor(sticker.textColor, sticker.backgroundStyle),
      );
      final textColor = _toImgColor(sticker.textColor);
      for (final line in lines.indexed) {
        final textY =
            backgroundRect.top.round() + paddingY + (line.$1 * lineHeight);
        final lineWidth = textWidths[line.$1];
        final textX = switch (sticker.textAlign) {
          TextAlign.right ||
          TextAlign.end => backgroundRect.right.round() - paddingX - lineWidth,
          TextAlign.center =>
            backgroundRect.left.round() +
                ((backgroundRect.width - lineWidth) / 2).round(),
          _ => backgroundRect.left.round() + paddingX,
        };
        img.drawString(
          image,
          line.$2,
          font: font,
          x: textX + math.max(1, visualScale.round()),
          y: textY + math.max(1, (visualScale * 0.8).round()),
          color: shadowColor,
        );
        img.drawString(
          image,
          line.$2,
          font: font,
          x: textX,
          y: textY,
          color: textColor,
        );
      }
    }
  }

  img.BitmapFont _fontForSticker(_OverlaySticker sticker, double visualScale) {
    final targetSize =
        20 * sticker.scale * visualScale * (sticker.bold ? 1.08 : 1);
    if (targetSize >= 36) return img.arial48;
    if (targetSize >= 19) return img.arial24;
    return img.arial14;
  }

  int _measureBitmapTextWidth(img.BitmapFont font, String text) {
    var width = 0;
    for (final rune in text.runes) {
      width += font.characterXAdvance(String.fromCharCode(rune));
    }
    return width;
  }

  img.Color _toImgColor(Color color) {
    final argb = color.toARGB32();
    return img.ColorRgba8(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
      (argb >> 24) & 0xFF,
    );
  }

  Size _constrainSize(Size input, {required double maxDimension}) {
    final maxSide = math.max(input.width, input.height);
    if (maxSide <= maxDimension) return input;
    final scale = maxDimension / maxSide;
    return Size(input.width * scale, input.height * scale);
  }
}

class _LayerResizeHandle extends StatelessWidget {
  const _LayerResizeHandle({required this.onPanUpdate});

  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black87, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropFramePainter extends CustomPainter {
  const _CropFramePainter({required this.cropFrame});

  final Rect cropFrame;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectXY(cropFrame, 14, 14));
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const dash = 10.0;
    const gap = 7.0;
    final path = Path()
      ..addRRect(RRect.fromRectXY(cropFrame.deflate(0.7), 14, 14));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CropFramePainter oldDelegate) {
    return oldDelegate.cropFrame != cropFrame;
  }
}

class _DrawOverlayPainter extends CustomPainter {
  const _DrawOverlayPainter({
    required this.strokes,
    required this.currentStroke,
    required this.viewport,
  });

  final List<_DrawStroke> strokes;
  final _DrawStroke? currentStroke;
  final Size viewport;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, ?currentStroke]) {
      if (stroke.points.length < 2) continue;
      final path = Path()
        ..moveTo(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width
        ..color = stroke.mode == _BrushMode.highlighter
            ? stroke.color.withValues(alpha: 0.34)
            : stroke.color;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawOverlayPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.viewport != viewport;
  }
}

class _MosaicOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 10.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterPreset {
  const _FilterPreset(
    this.label,
    this.brightness,
    this.contrast,
    this.warmth,
    this.saturation,
  );

  final String label;
  final double brightness;
  final double contrast;
  final double warmth;
  final double saturation;
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.white30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _OverlayIconBtn extends StatelessWidget {
  const _OverlayIconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _OverlaySlider extends StatelessWidget {
  const _OverlaySlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
