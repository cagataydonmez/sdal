import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../theme/sdal_theme_tokens.dart';

enum CropAspectPreset {
  square(1),
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
  });

  final int id;
  final Offset center;
  final Size size;
  final _HideRegionStyle style;

  _HideRegion copyWith({Offset? center, Size? size, _HideRegionStyle? style}) {
    return _HideRegion(
      id: id,
      center: center ?? this.center,
      size: size ?? this.size,
      style: style ?? this.style,
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

Future<File?> pickAndCropImage(
  BuildContext context, {
  required ImageSource source,
  CropAspectPreset? aspectPreset,
  int imageQuality = 92,
  double? maxWidth = 2200,
  String title = 'Fotoğrafı düzenle',
}) async {
  final result = await pickAndEditImage(
    context,
    source: source,
    aspectPreset: aspectPreset,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    title: title,
  );
  return result?.file;
}

Future<EditedMediaResult?> pickAndEditImage(
  BuildContext context, {
  required ImageSource source,
  CropAspectPreset? aspectPreset,
  int imageQuality = 92,
  double? maxWidth = 2200,
  String title = 'Fotoğrafı düzenle',
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
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
  CropAspectPreset? aspectPreset,
  int imageQuality = 92,
  double? maxWidth = 2200,
  String title = 'Fotoğrafı düzenle',
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickMultiImage(
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
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
  static const MethodChannel _nativeCaptureChannel = MethodChannel(
    'sdal/photo_editor_capture',
  );
  static const double _maxDecodedDimension = 2048;
  static const double _maxExportDimension = 1800;
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
  final GlobalKey _boundaryKey = GlobalKey();
  final GlobalKey _captureRegionKey = GlobalKey();

  ui.Image? _decodedImage;
  Size _viewportSize = Size.zero;
  Size _displayImageSize = Size.zero;
  double _baseScale = 1;
  bool _isSaving = false;
  bool _isFocusMode = false;
  bool _isToolbarCollapsed = false;
  bool _showOriginalPreview = false;
  double _toolbarHeight = 174;
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
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    final ratio = _selectedAspectRatio ?? _rotatedImageRatio ?? 1;
    final canTransformImage =
        _activePanel == _EditorPanel.crop && !_showOriginalPreview;
    final selectedSticker = _selectedSticker;
    final selectedHideRegion = _selectedHideRegion;
    final toolbarVisible = !_isFocusMode && !_isToolbarCollapsed;
    final editorBackground = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        tokens.canvas,
        Color.lerp(tokens.canvasSubtle, tokens.panelRaised, 0.36)!,
      ],
    );
    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.foreground,
        actions: [
          IconButton(
            onPressed: _decodedImage == null || _isSaving
                ? null
                : _toggleFocusMode,
            icon: Icon(
              _isFocusMode
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
            tooltip: _isFocusMode ? 'Düzenlemeye dön' : 'Odak modu',
          ),
          IconButton(
            onPressed: _decodedImage == null || _isSaving ? null : _rotateImage,
            icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
            tooltip: 'Döndür',
          ),
          TextButton(
            onPressed: _decodedImage == null || _isSaving ? null : _resetAll,
            child: const Text('Sıfırla'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: editorBackground),
        child: LayoutBuilder(
          builder: (context, bodyConstraints) {
            final toolbarMinHeight = 132.0;
            final toolbarMaxHeight = math.max(
              toolbarMinHeight,
              bodyConstraints.maxHeight * 0.46,
            );
            final toolbarHeight = _resolvedToolbarHeight(
              toolbarMinHeight,
              toolbarMaxHeight,
            );
            return Column(
              children: [
                if (!_isFocusMode) const SizedBox(height: 8),
                if (!_isFocusMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.panel.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(
                          SdalThemeTokens.radiusXl,
                        ),
                        border: Border.all(color: tokens.panelBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Text(
                          _instructionText(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.foregroundMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                if (!_isFocusMode) const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewport = _computeViewportSize(
                        constraints.biggest,
                        ratio,
                      );
                      _updateViewport(viewport);
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          _isFocusMode ? 8 : 0,
                          12,
                          _isFocusMode ? 8 : 4,
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.deferToChild,
                          onLongPressStart: _decodedImage == null || _isSaving
                              ? null
                              : (_) => _setOriginalPreview(true),
                          onLongPressEnd: _decodedImage == null || _isSaving
                              ? null
                              : (_) => _setOriginalPreview(false),
                          onLongPressCancel: () => _setOriginalPreview(false),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    _isFocusMode
                                        ? SdalThemeTokens.radius2xl
                                        : SdalThemeTokens.radiusXl,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      tokens.storyOverlay,
                                      tokens.panel.withValues(alpha: 0.94),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.storyOverlay.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 18),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: tokens.panelBorder.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: RepaintBoundary(
                                  key: _boundaryKey,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      _isFocusMode
                                          ? SdalThemeTokens.radius2xl
                                          : SdalThemeTokens.radiusXl,
                                    ),
                                    child: SizedBox(
                                      width: viewport.width,
                                      height: viewport.height,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: ColoredBox(
                                              color: tokens.storyOverlay,
                                            ),
                                          ),
                                          IgnorePointer(
                                            child: _CropMask(
                                              viewportSize: viewport,
                                            ),
                                          ),
                                          RepaintBoundary(
                                            child: ClipRect(
                                              key: _captureRegionKey,
                                              child: SizedBox(
                                                width: viewport.width,
                                                height: viewport.height,
                                                child: Stack(
                                                  children: [
                                                    InteractiveViewer(
                                                      transformationController:
                                                          _controller,
                                                      constrained: false,
                                                      minScale: _baseScale,
                                                      maxScale: math.max(
                                                        _baseScale * 6,
                                                        6,
                                                      ),
                                                      boundaryMargin:
                                                          const EdgeInsets.all(
                                                            1200,
                                                          ),
                                                      clipBehavior: Clip.none,
                                                      panEnabled:
                                                          canTransformImage,
                                                      scaleEnabled:
                                                          canTransformImage,
                                                      child: SizedBox(
                                                        width: _displayImageSize
                                                            .width,
                                                        height:
                                                            _displayImageSize
                                                                .height,
                                                        child: RotatedBox(
                                                          quarterTurns:
                                                              _quarterTurns,
                                                          child: SizedBox(
                                                            width:
                                                                _unrotatedDisplaySize
                                                                    .width,
                                                            height:
                                                                _unrotatedDisplaySize
                                                                    .height,
                                                            child:
                                                                _showOriginalPreview
                                                                ? Image.file(
                                                                    widget
                                                                        .sourceFile,
                                                                    fit: BoxFit
                                                                        .fill,
                                                                    filterQuality:
                                                                        FilterQuality
                                                                            .medium,
                                                                    cacheWidth:
                                                                        _cacheWidth,
                                                                    cacheHeight:
                                                                        _cacheHeight,
                                                                  )
                                                                : ColorFiltered(
                                                                    colorFilter:
                                                                        ColorFilter.matrix(
                                                                          _buildColorMatrix(),
                                                                        ),
                                                                    child: Image.file(
                                                                      widget
                                                                          .sourceFile,
                                                                      fit: BoxFit
                                                                          .fill,
                                                                      filterQuality:
                                                                          FilterQuality
                                                                              .medium,
                                                                      cacheWidth:
                                                                          _cacheWidth,
                                                                      cacheHeight:
                                                                          _cacheHeight,
                                                                    ),
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned.fill(
                                                      child: IgnorePointer(
                                                        child: CustomPaint(
                                                          painter: _DrawOverlayPainter(
                                                            strokes:
                                                                _showOriginalPreview
                                                                ? const <
                                                                    _DrawStroke
                                                                  >[]
                                                                : _strokes,
                                                            currentStroke:
                                                                _showOriginalPreview
                                                                ? null
                                                                : _currentStroke,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned.fill(
                                                      child: IgnorePointer(
                                                        ignoring:
                                                            _activePanel ==
                                                                _EditorPanel
                                                                    .crop ||
                                                            _showOriginalPreview,
                                                        child: Stack(
                                                          clipBehavior:
                                                              Clip.none,
                                                          children: [
                                                            if (!_showOriginalPreview)
                                                              for (final region
                                                                  in _hideRegions)
                                                                _buildHideRegion(
                                                                  region,
                                                                  viewport,
                                                                ),
                                                            if (!_showOriginalPreview)
                                                              for (final sticker
                                                                  in _stickers)
                                                                _buildSticker(
                                                                  sticker,
                                                                  viewport,
                                                                ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (_activePanel ==
                                                            _EditorPanel.draw &&
                                                        !_showOriginalPreview)
                                                      Positioned.fill(
                                                        child: GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onPanStart:
                                                              _startStroke,
                                                          onPanUpdate:
                                                              _extendStroke,
                                                          onPanEnd:
                                                              _finishStroke,
                                                        ),
                                                      ),
                                                  ],
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
                              Positioned(
                                top: 14,
                                left: 14,
                                right: 14,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _StageHintChip(
                                        label: _showOriginalPreview
                                            ? 'Orijinal görünüyor'
                                            : 'Fotoğrafa basılı tut: orijinal',
                                        icon: _showOriginalPreview
                                            ? Icons.visibility_rounded
                                            : Icons.touch_app_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (!_isFocusMode)
                                      _StageActionButton(
                                        icon: _isToolbarCollapsed
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        tooltip: _isToolbarCollapsed
                                            ? 'Araçları aç'
                                            : 'Araçları kapat',
                                        onTap:
                                            _decodedImage == null || _isSaving
                                            ? null
                                            : _toggleToolbarCollapsed,
                                      ),
                                    const SizedBox(width: 10),
                                    _StageActionButton(
                                      icon: _isFocusMode
                                          ? Icons.fullscreen_exit_rounded
                                          : Icons.fullscreen_rounded,
                                      tooltip: _isFocusMode
                                          ? 'Düzenlemeye dön'
                                          : 'Odak modu',
                                      onTap: _decodedImage == null || _isSaving
                                          ? null
                                          : _toggleFocusMode,
                                    ),
                                  ],
                                ),
                              ),
                              if (_isFocusMode)
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 18,
                                  child: FilledButton.icon(
                                    onPressed:
                                        _decodedImage == null || _isSaving
                                        ? null
                                        : _saveCrop,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.check_rounded),
                                    label: Text(
                                      _isSaving
                                          ? 'Kaydediliyor...'
                                          : 'Kaydet ve devam et',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: toolbarVisible
                      ? AnimatedContainer(
                          key: const ValueKey('toolbar-open'),
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          height: toolbarHeight,
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          decoration: BoxDecoration(
                            color: tokens.panelRaised.withValues(alpha: 0.97),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(SdalThemeTokens.radius2xl),
                            ),
                            border: Border.all(color: tokens.panelBorder),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.storyOverlay.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, -6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) {
                                  _resizeToolbarByDelta(
                                    -details.delta.dy,
                                    minHeight: toolbarMinHeight,
                                    maxHeight: toolbarMaxHeight,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    10,
                                    18,
                                    8,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: tokens.panelBorder,
                                          borderRadius: BorderRadius.circular(
                                            SdalThemeTokens.radiusPill,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.unfold_less_rounded,
                                            size: 18,
                                            color: tokens.foregroundMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Araçlar',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color: tokens.foreground,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Sürükleyerek büyüt',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: tokens.foregroundMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: _EditorToolbar(
                                    activePanel: _activePanel,
                                    onPanelChanged:
                                        _decodedImage == null || _isSaving
                                        ? null
                                        : _changePanel,
                                    aspectChoices: _aspectChoices,
                                    selectedRatio: _selectedAspectRatio,
                                    freeformWidthFactor: _freeformWidthFactor,
                                    freeformHeightFactor: _freeformHeightFactor,
                                    onAspectSelected:
                                        _decodedImage == null || _isSaving
                                        ? null
                                        : _selectAspectRatio,
                                    onFreeformWidthChanged:
                                        _decodedImage == null || _isSaving
                                        ? null
                                        : _setFreeformWidthFactor,
                                    onFreeformHeightChanged:
                                        _decodedImage == null || _isSaving
                                        ? null
                                        : _setFreeformHeightFactor,
                                    onRotate: _decodedImage == null || _isSaving
                                        ? null
                                        : _rotateImage,
                                    onAddText:
                                        _decodedImage == null || _isSaving
                                        ? null
                                        : _addSticker,
                                    selectedSticker: selectedSticker,
                                    stickerColors: _stickerColors,
                                    stickerFonts: _stickerFonts,
                                    onEditSelectedSticker:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _editSelectedSticker,
                                    onDeleteSelectedSticker:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _deleteSelectedSticker,
                                    onStickerScaleChanged:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _updateSelectedStickerScale,
                                    onStickerColorChanged:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _updateSelectedStickerColor,
                                    onStickerBackgroundChanged:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _updateSelectedStickerBackground,
                                    onStickerFontChanged:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _updateSelectedStickerFont,
                                    onStickerAlignChanged:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _updateSelectedStickerAlign,
                                    onStickerBoldChanged:
                                        selectedSticker == null || _isSaving
                                        ? null
                                        : _updateSelectedStickerBold,
                                    drawColor: _drawColor,
                                    drawWidth: _drawWidth,
                                    brushMode: _brushMode,
                                    onDrawColorChanged: _isSaving
                                        ? null
                                        : _changeDrawColor,
                                    onDrawWidthChanged: _isSaving
                                        ? null
                                        : _changeDrawWidth,
                                    onBrushModeChanged: _isSaving
                                        ? null
                                        : _changeBrushMode,
                                    onClearDrawings:
                                        _strokes.isEmpty || _isSaving
                                        ? null
                                        : _clearDrawings,
                                    selectedHideRegion: selectedHideRegion,
                                    onAddHideRegion:
                                        _decodedImage == null || _isSaving
                                        ? null
                                        : _addHideRegion,
                                    onDeleteHideRegion:
                                        selectedHideRegion == null || _isSaving
                                        ? null
                                        : _deleteSelectedHideRegion,
                                    onHideRegionStyleChanged:
                                        selectedHideRegion == null || _isSaving
                                        ? null
                                        : _updateSelectedHideStyle,
                                    brightness: _brightness,
                                    contrast: _contrast,
                                    warmth: _warmth,
                                    saturation: _saturation,
                                    onBrightnessChanged: _isSaving
                                        ? null
                                        : _setBrightness,
                                    onContrastChanged: _isSaving
                                        ? null
                                        : _setContrast,
                                    onWarmthChanged: _isSaving
                                        ? null
                                        : _setWarmth,
                                    onSaturationChanged: _isSaving
                                        ? null
                                        : _setSaturation,
                                    presets: _filterPresets,
                                    onApplyPreset: _isSaving
                                        ? null
                                        : _applyFilterPreset,
                                    onResetFilters:
                                        (_brightness == 0 &&
                                                _contrast == 1 &&
                                                _warmth == 0 &&
                                                _saturation == 1) ||
                                            _isSaving
                                        ? null
                                        : _resetFilters,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('toolbar-closed'),
                          height: 12,
                        ),
                ),
                if (!_isFocusMode)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _decodedImage == null || _isSaving
                              ? null
                              : _saveCrop,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _isSaving
                                ? 'Kaydediliyor...'
                                : 'Kaydet ve devam et',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _instructionText() {
    return switch (_activePanel) {
      _EditorPanel.crop =>
        'İki parmakla yakınlaştır, sürükleyerek kadrajı ayarla ve oran seç.',
      _EditorPanel.text =>
        'Yazı veya emoji ekle. Sticker seçiliyken sürükleyebilir, büyütebilir ve stilini değiştirebilirsin.',
      _EditorPanel.draw =>
        'Parmağınla çiz. Vurgulayıcı modu daha yumuşak ve yarı saydam iz bırakır.',
      _EditorPanel.hide =>
        'Gizleme bölgesi ekle. Bölgeyi sürükleyebilir, pinch ile büyütüp küçültebilir ve blur/mosaic seçebilirsin.',
      _EditorPanel.filter =>
        'Parlaklık, kontrast, sıcaklık ve doygunluk ayarlarını bu panelden düzenle.',
    };
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

  Size _computeViewportSize(Size available, double ratio) {
    final maxWidth = math.max(available.width - 12, 160.0);
    final maxHeight = math.max(available.height - 12, 160.0);
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

  void _updateViewport(Size nextViewport) {
    if (_decodedImage == null) return;
    final widthDelta = (nextViewport.width - _viewportSize.width).abs();
    final heightDelta = (nextViewport.height - _viewportSize.height).abs();
    if (widthDelta < 0.5 &&
        heightDelta < 0.5 &&
        _displayImageSize != Size.zero) {
      return;
    }
    _viewportSize = nextViewport;
    final originalSize = _unrotatedDisplaySize;
    _displayImageSize = (_quarterTurns % 2 == 0)
        ? originalSize
        : Size(originalSize.height, originalSize.width);
    _baseScale = math.max(
      nextViewport.width / _displayImageSize.width,
      nextViewport.height / _displayImageSize.height,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetImageTransform();
    });
  }

  void _resetImageTransform() {
    if (_displayImageSize == Size.zero || _viewportSize == Size.zero) return;
    final dx = (_viewportSize.width - _displayImageSize.width * _baseScale) / 2;
    final dy =
        (_viewportSize.height - _displayImageSize.height * _baseScale) / 2;
    _controller.value = Matrix4.diagonal3Values(_baseScale, _baseScale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  void _resetAll() {
    setState(() {
      _selectedAspectRatio = widget.initialAspectRatio;
      _quarterTurns = 0;
      _activePanel = _EditorPanel.crop;
      _isFocusMode = false;
      _isToolbarCollapsed = false;
      _showOriginalPreview = false;
      _toolbarHeight = 174;
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
    });
  }

  void _changePanel(_EditorPanel panel) {
    setState(() {
      _activePanel = panel;
      _showOriginalPreview = false;
      if (panel != _EditorPanel.text) _selectedStickerId = null;
      if (panel != _EditorPanel.hide) _selectedHideRegionId = null;
    });
  }

  void _toggleFocusMode() {
    setState(() {
      _isFocusMode = !_isFocusMode;
      if (_isFocusMode) {
        _isToolbarCollapsed = true;
      }
    });
  }

  void _toggleToolbarCollapsed() {
    setState(() {
      _isToolbarCollapsed = !_isToolbarCollapsed;
    });
  }

  double _resolvedToolbarHeight(double minHeight, double maxHeight) {
    return _toolbarHeight.clamp(minHeight, maxHeight);
  }

  void _setToolbarHeight(
    double value, {
    required double minHeight,
    required double maxHeight,
  }) {
    setState(() {
      _toolbarHeight = value.clamp(minHeight, maxHeight);
    });
  }

  void _resizeToolbarByDelta(
    double delta, {
    required double minHeight,
    required double maxHeight,
  }) {
    _setToolbarHeight(
      _toolbarHeight + delta,
      minHeight: minHeight,
      maxHeight: maxHeight,
    );
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
    });
  }

  void _setFreeformWidthFactor(double value) {
    setState(() {
      _selectedAspectRatio = null;
      _freeformWidthFactor = value.clamp(0.35, 1.0);
      _viewportSize = Size.zero;
    });
  }

  void _setFreeformHeightFactor(double value) {
    setState(() {
      _selectedAspectRatio = null;
      _freeformHeightFactor = value.clamp(0.35, 1.0);
      _viewportSize = Size.zero;
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

  void _updateSelectedStickerAlign(TextAlign align) {
    final selected = _selectedSticker;
    if (selected == null) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          sticker.id == selected.id
              ? sticker.copyWith(textAlign: align)
              : sticker,
      ];
    });
  }

  void _updateSelectedStickerBold(bool value) {
    final selected = _selectedSticker;
    if (selected == null) return;
    setState(() {
      _stickers = [
        for (final sticker in _stickers)
          sticker.id == selected.id ? sticker.copyWith(bold: value) : sticker,
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
          child: DecoratedBox(
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
        ),
      ),
    );
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
              scale: (baseScale * details.scale).clamp(0.7, 2.8),
            )
          else
            sticker,
      ];
    });
  }

  void _startStroke(DragStartDetails details) {
    setState(() {
      _currentStrokePoints = [details.localPosition];
    });
  }

  void _extendStroke(DragUpdateDetails details) {
    setState(() {
      _currentStrokePoints = [..._currentStrokePoints, details.localPosition];
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
    );
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
              size: Size(
                (baseSize.width * details.scale).clamp(0.12, 0.82),
                (baseSize.height * details.scale).clamp(0.08, 0.82),
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
    for (final item in _readList(metadata['strokes'])) {
      final map = _readMap(item);
      final points = <Offset>[
        for (final point in _readList(map['points']))
          Offset(
            _readDouble(_readMap(point)['x']) ?? 0,
            _readDouble(_readMap(point)['y']) ?? 0,
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

  Map<String, dynamic> _buildEditMetadata() {
    return {
      'version': 1,
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
      // Selection chrome must be removed before taking the snapshot.
      if (_selectedStickerId != null ||
          _selectedHideRegionId != null ||
          _showOriginalPreview) {
        setState(() {
          _selectedStickerId = null;
          _selectedHideRegionId = null;
          _showOriginalPreview = false;
        });
      }

      await _waitForCaptureFrame();
      if (!mounted) return;
      _logSaveStage('capture-begin');
      final imageBytes = await _captureEditedImageBytes();
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _waitForCaptureFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 32));
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<Uint8List> _captureEditedImageBytes() async {
    if (Platform.isIOS) {
      try {
        _logSaveStage('native-capture-begin');
        final imageBytes = await _captureEditedImageBytesFromNative();
        _logSaveStage(
          'native-capture-done',
          details: '${imageBytes.length} bytes',
        );
        return imageBytes;
      } catch (error, stackTrace) {
        _logSaveStage('native-capture-failed', details: '$error');
        _logSaveError(error, stackTrace);
      }
    }
    _logSaveStage('image-encode-begin');
    final bitmap = await _buildExportBitmap();
    final bytes = Uint8List.fromList(img.encodeJpg(bitmap, quality: 90));
    _logSaveStage(
      'image-encode-done',
      details: '${bitmap.width}x${bitmap.height} -> ${bytes.length} bytes',
    );
    return bytes;
  }

  Future<Uint8List> _captureEditedImageBytesFromNative() async {
    final renderBox =
        _captureRegionKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      throw StateError('Native capture alani bulunamadi.');
    }

    final origin = renderBox.localToGlobal(Offset.zero);
    final captureRect = origin & renderBox.size;
    if (captureRect.isEmpty) {
      throw StateError('Native capture alani bos.');
    }

    _logSaveStage(
      'native-capture-rect',
      details:
          'x=${captureRect.left.toStringAsFixed(1)} y=${captureRect.top.toStringAsFixed(1)} '
          'w=${captureRect.width.toStringAsFixed(1)} h=${captureRect.height.toStringAsFixed(1)}',
    );

    final result = await _nativeCaptureChannel
        .invokeMethod<Uint8List>('captureRegion', <String, double>{
          'x': captureRect.left,
          'y': captureRect.top,
          'width': captureRect.width,
          'height': captureRect.height,
        });
    if (result == null || result.isEmpty) {
      throw StateError('Native capture bos dondu.');
    }
    return result;
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
    if (_viewportSize == Size.zero || _displayImageSize == Size.zero) {
      throw StateError('Kirpma alani hazir degil.');
    }

    final topLeft = _controller.toScene(Offset.zero);
    final bottomRight = _controller.toScene(
      Offset(_viewportSize.width, _viewportSize.height),
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
    if (_viewportSize == Size.zero) return;
    final scaleX = image.width / _viewportSize.width;
    final scaleY = image.height / _viewportSize.height;
    final widthScale = (scaleX + scaleY) / 2;

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
          x1: (start.dx * scaleX).round(),
          y1: (start.dy * scaleY).round(),
          x2: (end.dx * scaleX).round(),
          y2: (end.dy * scaleY).round(),
          color: _toImgColor(color),
          thickness: math.max(1, (stroke.width * widthScale).round()),
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

class _CropMask extends StatelessWidget {
  const _CropMask({required this.viewportSize});

  final Size viewportSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return SizedBox(
      width: viewportSize.width,
      height: viewportSize.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.foregroundOnAccent, width: 2),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: tokens.storyOverlay.withValues(alpha: 0.82),
              blurRadius: 0,
              spreadRadius: 1600,
            ),
          ],
        ),
      ),
    );
  }
}

class _StageHintChip extends StatelessWidget {
  const _StageHintChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.sdal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tokens.foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: tokens.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageActionButton extends StatelessWidget {
  const _StageActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.panel.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(SdalThemeTokens.radiusPill),
          border: Border.all(color: tokens.panelBorder),
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: tokens.foreground),
        ),
      ),
    );
  }
}

class _DrawOverlayPainter extends CustomPainter {
  const _DrawOverlayPainter({
    required this.strokes,
    required this.currentStroke,
  });

  final List<_DrawStroke> strokes;
  final _DrawStroke? currentStroke;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, ?currentStroke]) {
      if (stroke.points.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
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
        oldDelegate.currentStroke != currentStroke;
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

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.activePanel,
    required this.onPanelChanged,
    required this.aspectChoices,
    required this.selectedRatio,
    required this.freeformWidthFactor,
    required this.freeformHeightFactor,
    required this.onAspectSelected,
    required this.onFreeformWidthChanged,
    required this.onFreeformHeightChanged,
    required this.onRotate,
    required this.onAddText,
    required this.selectedSticker,
    required this.stickerColors,
    required this.stickerFonts,
    required this.onEditSelectedSticker,
    required this.onDeleteSelectedSticker,
    required this.onStickerScaleChanged,
    required this.onStickerColorChanged,
    required this.onStickerBackgroundChanged,
    required this.onStickerFontChanged,
    required this.onStickerAlignChanged,
    required this.onStickerBoldChanged,
    required this.drawColor,
    required this.drawWidth,
    required this.brushMode,
    required this.onDrawColorChanged,
    required this.onDrawWidthChanged,
    required this.onBrushModeChanged,
    required this.onClearDrawings,
    required this.selectedHideRegion,
    required this.onAddHideRegion,
    required this.onDeleteHideRegion,
    required this.onHideRegionStyleChanged,
    required this.brightness,
    required this.contrast,
    required this.warmth,
    required this.saturation,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onWarmthChanged,
    required this.onSaturationChanged,
    required this.presets,
    required this.onApplyPreset,
    required this.onResetFilters,
  });

  final _EditorPanel activePanel;
  final ValueChanged<_EditorPanel>? onPanelChanged;
  final List<_AspectChoice> aspectChoices;
  final double? selectedRatio;
  final double freeformWidthFactor;
  final double freeformHeightFactor;
  final ValueChanged<double?>? onAspectSelected;
  final ValueChanged<double>? onFreeformWidthChanged;
  final ValueChanged<double>? onFreeformHeightChanged;
  final VoidCallback? onRotate;
  final VoidCallback? onAddText;
  final _OverlaySticker? selectedSticker;
  final List<_StickerColorChoice> stickerColors;
  final List<_StickerFontChoice> stickerFonts;
  final VoidCallback? onEditSelectedSticker;
  final VoidCallback? onDeleteSelectedSticker;
  final ValueChanged<double>? onStickerScaleChanged;
  final ValueChanged<Color>? onStickerColorChanged;
  final ValueChanged<_StickerBackgroundStyle>? onStickerBackgroundChanged;
  final ValueChanged<_StickerFontKind>? onStickerFontChanged;
  final ValueChanged<TextAlign>? onStickerAlignChanged;
  final ValueChanged<bool>? onStickerBoldChanged;
  final Color drawColor;
  final double drawWidth;
  final _BrushMode brushMode;
  final ValueChanged<Color>? onDrawColorChanged;
  final ValueChanged<double>? onDrawWidthChanged;
  final ValueChanged<_BrushMode>? onBrushModeChanged;
  final VoidCallback? onClearDrawings;
  final _HideRegion? selectedHideRegion;
  final VoidCallback? onAddHideRegion;
  final VoidCallback? onDeleteHideRegion;
  final ValueChanged<_HideRegionStyle>? onHideRegionStyleChanged;
  final double brightness;
  final double contrast;
  final double warmth;
  final double saturation;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onContrastChanged;
  final ValueChanged<double>? onWarmthChanged;
  final ValueChanged<double>? onSaturationChanged;
  final List<_FilterPreset> presets;
  final ValueChanged<_FilterPreset>? onApplyPreset;
  final VoidCallback? onResetFilters;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: aspectChoices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final choice = aspectChoices[index];
                final selected =
                    (choice.ratio == null && selectedRatio == null) ||
                    (choice.ratio != null &&
                        selectedRatio != null &&
                        (choice.ratio! - selectedRatio!).abs() < 0.001);
                return ChoiceChip(
                  label: Text(choice.label),
                  selected: selected,
                  onSelected: onAspectSelected == null
                      ? null
                      : (_) => onAspectSelected!(choice.ratio),
                  selectedColor: tokens.accentMuted,
                  labelStyle: TextStyle(
                    color: selected
                        ? tokens.foreground
                        : tokens.foregroundMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: tokens.panel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: selected ? tokens.accent : tokens.panelBorder,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PanelChip(
                label: 'Kırp',
                selected: activePanel == _EditorPanel.crop,
                onTap: onPanelChanged == null
                    ? null
                    : () => onPanelChanged!(_EditorPanel.crop),
              ),
              _PanelChip(
                label: 'Yazı',
                selected: activePanel == _EditorPanel.text,
                onTap: onPanelChanged == null
                    ? null
                    : () => onPanelChanged!(_EditorPanel.text),
              ),
              _PanelChip(
                label: 'Çiz',
                selected: activePanel == _EditorPanel.draw,
                onTap: onPanelChanged == null
                    ? null
                    : () => onPanelChanged!(_EditorPanel.draw),
              ),
              _PanelChip(
                label: 'Gizle',
                selected: activePanel == _EditorPanel.hide,
                onTap: onPanelChanged == null
                    ? null
                    : () => onPanelChanged!(_EditorPanel.hide),
              ),
              _PanelChip(
                label: 'Filtre',
                selected: activePanel == _EditorPanel.filter,
                onTap: onPanelChanged == null
                    ? null
                    : () => onPanelChanged!(_EditorPanel.filter),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (activePanel == _EditorPanel.crop)
            _CropPanel(
              onRotate: onRotate,
              isFreeform: selectedRatio == null,
              freeformWidthFactor: freeformWidthFactor,
              freeformHeightFactor: freeformHeightFactor,
              onFreeformWidthChanged: onFreeformWidthChanged,
              onFreeformHeightChanged: onFreeformHeightChanged,
            )
          else if (activePanel == _EditorPanel.text)
            _TextPanel(
              onAddText: onAddText,
              selectedSticker: selectedSticker,
              colors: stickerColors,
              fonts: stickerFonts,
              onEditSelectedSticker: onEditSelectedSticker,
              onDeleteSelectedSticker: onDeleteSelectedSticker,
              onStickerScaleChanged: onStickerScaleChanged,
              onStickerColorChanged: onStickerColorChanged,
              onStickerBackgroundChanged: onStickerBackgroundChanged,
              onStickerFontChanged: onStickerFontChanged,
              onStickerAlignChanged: onStickerAlignChanged,
              onStickerBoldChanged: onStickerBoldChanged,
            )
          else if (activePanel == _EditorPanel.draw)
            _DrawPanel(
              color: drawColor,
              width: drawWidth,
              brushMode: brushMode,
              onColorChanged: onDrawColorChanged,
              onWidthChanged: onDrawWidthChanged,
              onBrushModeChanged: onBrushModeChanged,
              onClear: onClearDrawings,
            )
          else if (activePanel == _EditorPanel.hide)
            _HidePanel(
              selectedRegion: selectedHideRegion,
              onAddRegion: onAddHideRegion,
              onDeleteRegion: onDeleteHideRegion,
              onStyleChanged: onHideRegionStyleChanged,
            )
          else
            _FilterPanel(
              presets: presets,
              brightness: brightness,
              contrast: contrast,
              warmth: warmth,
              saturation: saturation,
              onApplyPreset: onApplyPreset,
              onBrightnessChanged: onBrightnessChanged,
              onContrastChanged: onContrastChanged,
              onWarmthChanged: onWarmthChanged,
              onSaturationChanged: onSaturationChanged,
              onReset: onResetFilters,
            ),
        ],
      ),
    );
  }
}

class _PanelChip extends StatelessWidget {
  const _PanelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      selectedColor: tokens.accentMuted,
      backgroundColor: tokens.panel,
      labelStyle: TextStyle(
        color: selected ? tokens.foreground : tokens.foregroundMuted,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? tokens.accent : tokens.panelBorder),
      ),
    );
  }
}

class _ToolbarCard extends StatelessWidget {
  const _ToolbarCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: child,
    );
  }
}

class _CropPanel extends StatelessWidget {
  const _CropPanel({
    required this.onRotate,
    required this.isFreeform,
    required this.freeformWidthFactor,
    required this.freeformHeightFactor,
    required this.onFreeformWidthChanged,
    required this.onFreeformHeightChanged,
  });

  final VoidCallback? onRotate;
  final bool isFreeform;
  final double freeformWidthFactor;
  final double freeformHeightFactor;
  final ValueChanged<double>? onFreeformWidthChanged;
  final ValueChanged<double>? onFreeformHeightChanged;

  @override
  Widget build(BuildContext context) {
    return _ToolbarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRotate,
                  icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
                  label: const Text('Görseli döndür'),
                ),
              ),
            ],
          ),
          if (isFreeform) ...[
            const SizedBox(height: 10),
            _FilterSlider(
              label: 'Genişlik',
              value: freeformWidthFactor,
              min: 0.35,
              max: 1,
              onChanged: onFreeformWidthChanged,
            ),
            _FilterSlider(
              label: 'Yükseklik',
              value: freeformHeightFactor,
              min: 0.35,
              max: 1,
              onChanged: onFreeformHeightChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({
    required this.onAddText,
    required this.selectedSticker,
    required this.colors,
    required this.fonts,
    required this.onEditSelectedSticker,
    required this.onDeleteSelectedSticker,
    required this.onStickerScaleChanged,
    required this.onStickerColorChanged,
    required this.onStickerBackgroundChanged,
    required this.onStickerFontChanged,
    required this.onStickerAlignChanged,
    required this.onStickerBoldChanged,
  });

  final VoidCallback? onAddText;
  final _OverlaySticker? selectedSticker;
  final List<_StickerColorChoice> colors;
  final List<_StickerFontChoice> fonts;
  final VoidCallback? onEditSelectedSticker;
  final VoidCallback? onDeleteSelectedSticker;
  final ValueChanged<double>? onStickerScaleChanged;
  final ValueChanged<Color>? onStickerColorChanged;
  final ValueChanged<_StickerBackgroundStyle>? onStickerBackgroundChanged;
  final ValueChanged<_StickerFontKind>? onStickerFontChanged;
  final ValueChanged<TextAlign>? onStickerAlignChanged;
  final ValueChanged<bool>? onStickerBoldChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    final sticker = selectedSticker;
    return _ToolbarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddText,
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  label: const Text('Yeni yazı / emoji'),
                ),
              ),
              if (sticker != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onEditSelectedSticker,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDeleteSelectedSticker,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          if (sticker != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Boyut', style: TextStyle(color: tokens.foregroundMuted)),
                Expanded(
                  child: Slider(
                    value: sticker.scale.clamp(0.7, 2.8),
                    min: 0.7,
                    max: 2.8,
                    divisions: 21,
                    label: sticker.scale.toStringAsFixed(1),
                    onChanged: onStickerScaleChanged,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in colors)
                  GestureDetector(
                    onTap: onStickerColorChanged == null
                        ? null
                        : () => onStickerColorChanged!(choice.color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: choice.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sticker.textColor == choice.color
                              ? tokens.accent
                              : tokens.panelBorder,
                          width: sticker.textColor == choice.color ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in fonts)
                  _PanelChip(
                    label: choice.label,
                    selected: sticker.fontKind == choice.kind,
                    onTap: onStickerFontChanged == null
                        ? null
                        : () => onStickerFontChanged!(choice.kind),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PanelChip(
                  label: 'Sola',
                  selected: sticker.textAlign == TextAlign.left,
                  onTap: onStickerAlignChanged == null
                      ? null
                      : () => onStickerAlignChanged!(TextAlign.left),
                ),
                _PanelChip(
                  label: 'Ortala',
                  selected: sticker.textAlign == TextAlign.center,
                  onTap: onStickerAlignChanged == null
                      ? null
                      : () => onStickerAlignChanged!(TextAlign.center),
                ),
                _PanelChip(
                  label: 'Sağa',
                  selected: sticker.textAlign == TextAlign.right,
                  onTap: onStickerAlignChanged == null
                      ? null
                      : () => onStickerAlignChanged!(TextAlign.right),
                ),
                _PanelChip(
                  label: sticker.bold ? 'Kalın' : 'Normal',
                  selected: sticker.bold,
                  onTap: onStickerBoldChanged == null
                      ? null
                      : () => onStickerBoldChanged!(!sticker.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PanelChip(
                  label: 'Şeffaf',
                  selected:
                      sticker.backgroundStyle == _StickerBackgroundStyle.none,
                  onTap: onStickerBackgroundChanged == null
                      ? null
                      : () => onStickerBackgroundChanged!(
                          _StickerBackgroundStyle.none,
                        ),
                ),
                _PanelChip(
                  label: 'Yumuşak',
                  selected:
                      sticker.backgroundStyle == _StickerBackgroundStyle.soft,
                  onTap: onStickerBackgroundChanged == null
                      ? null
                      : () => onStickerBackgroundChanged!(
                          _StickerBackgroundStyle.soft,
                        ),
                ),
                _PanelChip(
                  label: 'Koyu',
                  selected:
                      sticker.backgroundStyle == _StickerBackgroundStyle.dark,
                  onTap: onStickerBackgroundChanged == null
                      ? null
                      : () => onStickerBackgroundChanged!(
                          _StickerBackgroundStyle.dark,
                        ),
                ),
                _PanelChip(
                  label: 'Açık',
                  selected:
                      sticker.backgroundStyle == _StickerBackgroundStyle.light,
                  onTap: onStickerBackgroundChanged == null
                      ? null
                      : () => onStickerBackgroundChanged!(
                          _StickerBackgroundStyle.light,
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawPanel extends StatelessWidget {
  const _DrawPanel({
    required this.color,
    required this.width,
    required this.brushMode,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onBrushModeChanged,
    required this.onClear,
  });

  final Color color;
  final double width;
  final _BrushMode brushMode;
  final ValueChanged<Color>? onColorChanged;
  final ValueChanged<double>? onWidthChanged;
  final ValueChanged<_BrushMode>? onBrushModeChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).sdal;
    return _ToolbarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PanelChip(
                label: 'Kalem',
                selected: brushMode == _BrushMode.pen,
                onTap: onBrushModeChanged == null
                    ? null
                    : () => onBrushModeChanged!(_BrushMode.pen),
              ),
              const SizedBox(width: 8),
              _PanelChip(
                label: 'Vurgulayıcı',
                selected: brushMode == _BrushMode.highlighter,
                onTap: onBrushModeChanged == null
                    ? null
                    : () => onBrushModeChanged!(_BrushMode.highlighter),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Temizle'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const [
                      Colors.white,
                      Color(0xFFFACC15),
                      Color(0xFF93C5FD),
                      Color(0xFFF9A8D4),
                      Color(0xFF86EFAC),
                      Color(0xFFFCA5A5),
                    ]
                    .map(
                      (swatch) => GestureDetector(
                        onTap: onColorChanged == null
                            ? null
                            : () => onColorChanged!(swatch),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == swatch
                                  ? tokens.accent
                                  : tokens.panelBorder,
                              width: color == swatch ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          Row(
            children: [
              Text('Kalınlık', style: TextStyle(color: tokens.foregroundMuted)),
              Expanded(
                child: Slider(
                  value: width.clamp(2, 26),
                  min: 2,
                  max: 26,
                  divisions: 24,
                  label: width.toStringAsFixed(0),
                  onChanged: onWidthChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HidePanel extends StatelessWidget {
  const _HidePanel({
    required this.selectedRegion,
    required this.onAddRegion,
    required this.onDeleteRegion,
    required this.onStyleChanged,
  });

  final _HideRegion? selectedRegion;
  final VoidCallback? onAddRegion;
  final VoidCallback? onDeleteRegion;
  final ValueChanged<_HideRegionStyle>? onStyleChanged;

  @override
  Widget build(BuildContext context) {
    return _ToolbarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddRegion,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Bölge ekle'),
                ),
              ),
              if (selectedRegion != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onDeleteRegion,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          if (selectedRegion != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PanelChip(
                  label: 'Blur',
                  selected: selectedRegion!.style == _HideRegionStyle.blur,
                  onTap: onStyleChanged == null
                      ? null
                      : () => onStyleChanged!(_HideRegionStyle.blur),
                ),
                _PanelChip(
                  label: 'Mosaic',
                  selected: selectedRegion!.style == _HideRegionStyle.mosaic,
                  onTap: onStyleChanged == null
                      ? null
                      : () => onStyleChanged!(_HideRegionStyle.mosaic),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.presets,
    required this.brightness,
    required this.contrast,
    required this.warmth,
    required this.saturation,
    required this.onApplyPreset,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onWarmthChanged,
    required this.onSaturationChanged,
    required this.onReset,
  });

  final List<_FilterPreset> presets;
  final double brightness;
  final double contrast;
  final double warmth;
  final double saturation;
  final ValueChanged<_FilterPreset>? onApplyPreset;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onContrastChanged;
  final ValueChanged<double>? onWarmthChanged;
  final ValueChanged<double>? onSaturationChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return _ToolbarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets)
                _PanelChip(
                  label: preset.label,
                  selected: false,
                  onTap: onApplyPreset == null
                      ? null
                      : () => onApplyPreset!(preset),
                ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Sıfırla'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FilterSlider(
            label: 'Parlaklık',
            value: brightness,
            min: -0.35,
            max: 0.35,
            onChanged: onBrightnessChanged,
          ),
          _FilterSlider(
            label: 'Kontrast',
            value: contrast,
            min: 0.7,
            max: 1.4,
            onChanged: onContrastChanged,
          ),
          _FilterSlider(
            label: 'Sıcaklık',
            value: warmth,
            min: -0.4,
            max: 0.4,
            onChanged: onWarmthChanged,
          ),
          _FilterSlider(
            label: 'Doygunluk',
            value: saturation,
            min: 0,
            max: 1.5,
            onChanged: onSaturationChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterSlider extends StatelessWidget {
  const _FilterSlider({
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
    final tokens = Theme.of(context).sdal;
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: TextStyle(color: tokens.foregroundMuted)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
