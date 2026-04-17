import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum CropAspectPreset {
  square(1),
  portrait45(4 / 5),
  story916(9 / 16),
  wide169(16 / 9);

  const CropAspectPreset(this.ratio);
  final double ratio;
}

Future<File?> pickAndCropImage(
  BuildContext context, {
  required ImageSource source,
  CropAspectPreset? aspectPreset,
  int imageQuality = 92,
  double? maxWidth = 2200,
  String title = 'Fotoğrafı kırp',
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  if (picked == null || !context.mounted) return null;
  return Navigator.of(context).push<File>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CropImagePage(
        sourceFile: File(picked.path),
        title: title,
        aspectRatio: aspectPreset?.ratio,
      ),
    ),
  );
}

class _CropImagePage extends StatefulWidget {
  const _CropImagePage({
    required this.sourceFile,
    required this.title,
    required this.aspectRatio,
  });

  final File sourceFile;
  final String title;
  final double? aspectRatio;

  @override
  State<_CropImagePage> createState() => _CropImagePageState();
}

class _CropImagePageState extends State<_CropImagePage> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _boundaryKey = GlobalKey();

  ui.Image? _decodedImage;
  Size _viewportSize = Size.zero;
  Size _displayImageSize = Size.zero;
  double _baseScale = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
    final ratio = widget.aspectRatio ?? _imageRatio ?? 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _decodedImage == null || _isSaving ? null : _resetView,
            child: const Text('Sıfırla'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = _computeViewportSize(constraints.biggest, ratio);
          _updateViewport(viewport);
          return Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'İki parmakla yakınlaştır, sürükleyerek kadrajı ayarla. Kaydettiğinde kırpılmış hali yüklenecek.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: _decodedImage == null
                      ? const CircularProgressIndicator()
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            IgnorePointer(
                              child: _CropMask(viewportSize: viewport),
                            ),
                            RepaintBoundary(
                              key: _boundaryKey,
                              child: ClipRect(
                                child: SizedBox(
                                  width: viewport.width,
                                  height: viewport.height,
                                  child: InteractiveViewer(
                                    transformationController: _controller,
                                    constrained: false,
                                    minScale: _baseScale,
                                    maxScale: math.max(_baseScale * 6, 6),
                                    boundaryMargin: const EdgeInsets.all(1200),
                                    clipBehavior: Clip.none,
                                    child: SizedBox(
                                      width: _displayImageSize.width,
                                      height: _displayImageSize.height,
                                      child: Image.file(
                                        widget.sourceFile,
                                        fit: BoxFit.fill,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
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
                        _isSaving ? 'Kaydediliyor...' : 'Kırp ve devam et',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double? get _imageRatio {
    final image = _decodedImage;
    if (image == null || image.height == 0) return null;
    return image.width / image.height;
  }

  Future<void> _loadImage() async {
    final bytes = await widget.sourceFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _decodedImage = frame.image;
    });
  }

  Size _computeViewportSize(Size available, double ratio) {
    final maxWidth = math.max(available.width - 32, 160.0);
    final maxHeight = math.max(available.height - 220, 160.0);
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
    if (widthDelta < 0.5 && heightDelta < 0.5 && _displayImageSize != Size.zero) {
      return;
    }
    _viewportSize = nextViewport;
    final originalSize = Size(
      _decodedImage!.width.toDouble(),
      _decodedImage!.height.toDouble(),
    );
    _displayImageSize = _constrainSize(originalSize, maxDimension: 1600);
    _baseScale = math.max(
      nextViewport.width / _displayImageSize.width,
      nextViewport.height / _displayImageSize.height,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetView();
    });
  }

  void _resetView() {
    if (_displayImageSize == Size.zero || _viewportSize == Size.zero) return;
    final dx = (_viewportSize.width - _displayImageSize.width * _baseScale) / 2;
    final dy = (_viewportSize.height - _displayImageSize.height * _baseScale) / 2;
    _controller.value = Matrix4.diagonal3Values(_baseScale, _baseScale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  Future<void> _saveCrop() async {
    setState(() => _isSaving = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = _decodedImage;
      final display = _displayImageSize;
      final viewport = _viewportSize;
      final pixelRatio = image == null || display.width == 0 || viewport.width == 0
          ? 3.0
          : math.min(
              4.0,
              math.max(
                image.width / display.width,
                image.height / display.height,
              ),
            );
      final raster = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await raster.toByteData(format: ui.ImageByteFormat.png);
      raster.dispose();
      if (byteData == null) return;
      final tempDir = await getTemporaryDirectory();
      final output = File(
        '${tempDir.path}/crop-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await output.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(output);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
    return SizedBox(
      width: viewportSize.width,
      height: viewportSize.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 0,
              spreadRadius: 1600,
            ),
          ],
        ),
      ),
    );
  }
}
