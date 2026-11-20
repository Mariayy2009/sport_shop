import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cart_actions.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/product.dart';
import '../../models/try_on.dart';
import '../../services/try_on/body_pose.dart';
import '../../services/try_on/body_shading.dart';
import '../../services/try_on/garment_color.dart';
import '../../services/try_on/garment_mesh.dart';
import '../../services/try_on/live_try_on_service.dart';
import '../../services/try_on/photo_try_on_service.dart';
import '../../widgets/garment_3d_painter.dart';
import '../../widgets/try_on_product_strip.dart';

/// Живая примерка: камера, поза тела в реальном времени и 3D-модель
/// вещи, которая следует за плечами, руками, корпусом и ногами.
///
/// На компьютере камеры и определения позы нет — там показывается
/// предпросмотр 3D-модели на условной фигуре, с явной подписью.
class LiveTryOnScreen extends StatefulWidget {
  const LiveTryOnScreen({super.key, this.productId});

  final int? productId;

  @override
  State<LiveTryOnScreen> createState() => _LiveTryOnScreenState();
}

class _LiveTryOnScreenState extends State<LiveTryOnScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final LiveTryOnService _service = LiveTryOnService();
  final PhotoTryOnService _images = PhotoTryOnService();
  StreamSubscription<BodyPose?>? _subscription;
  StreamSubscription<BodyShading>? _shadingSubscription;

  /// Свет и силуэт из последнего кадра камеры.
  ui.Image? _shading;
  bool _shadingBusy = false;

  /// Движение условной фигуры в предпросмотре (без камеры).
  late final AnimationController _demo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  List<Product> _products = const [];
  Product? _product;
  GarmentMesh? _mesh;
  Color _color = GarmentColor.fallback;
  BodyPose? _pose;
  String? _error;
  bool _isStarting = true;
  bool _showJoints = false;

  bool get _live => LiveTryOnService.isSupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final List<Product> all =
        await context.read<ProductRepository>().getProducts();
    if (!mounted) return;
    _products = all.where((product) => TryOnSupport.of(product).live).toList();
    Product? initial;
    for (final Product product in _products) {
      if (product.id == widget.productId) initial = product;
    }
    await _wear(initial ?? _products.firstOrNull);
    if (_live) {
      await _startCamera();
    } else {
      _demo.repeat();
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      await _service.start();
      _subscription ??= _service.poses.listen((pose) {
        if (mounted) setState(() => _pose = pose);
      });
      _shadingSubscription ??= _service.shading.listen(_onShading);
    } on AppException catch (error) {
      _error = error.message;
    } on Exception catch (error) {
      debugPrint('Не удалось запустить живую примерку: $error');
      _error = 'Не удалось запустить камеру';
    }
    if (mounted) setState(() => _isStarting = false);
  }

  Future<void> _onShading(BodyShading shading) async {
    if (_shadingBusy) return;
    _shadingBusy = true;
    try {
      final ui.Image image = await shading.toImage();
      if (!mounted) {
        image.dispose();
        return;
      }
      final ui.Image? old = _shading;
      setState(() => _shading = image);
      // Старую картинку освобождаем после того, как кадр перерисован.
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    } finally {
      _shadingBusy = false;
    }
  }

  /// Смена вещи без остановки камеры: меняются только модель и цвет.
  Future<void> _wear(Product? product) async {
    if (product == null) return;
    final GarmentShape? shape = TryOnSupport.of(product).shape;
    if (shape == null) return;
    try {
      final ByteData data = await rootBundle.load(shape.assetPath);
      final GarmentMesh mesh = GarmentMesh.fromGlb(data.buffer.asUint8List());
      Color color = GarmentColor.fallback;
      try {
        color = await GarmentColor.forProduct(
            product.imageUrl, await _images.loadProductImage(product));
      } on AppException {
        // У товара нет фото — оставляем цвет по умолчанию.
      }
      if (!mounted) return;
      setState(() {
        _product = product;
        _mesh = mesh;
        _color = color;
      });
    } on Exception catch (error) {
      debugPrint('Не удалось загрузить 3D-модель: $error');
      if (mounted) setState(() => _error = 'Не удалось загрузить 3D-модель вещи');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_live) return;
    // Камеру нельзя держать, когда приложение свёрнуто.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _service.stop();
    } else if (state == AppLifecycleState.resumed && _service.camera == null) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _shadingSubscription?.cancel();
    _shading?.dispose();
    _demo.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Product? product = _product;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildStage(),
          // Затемнение сверху и снизу, чтобы подписи читались на любом фоне.
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 110,
            child: ColoredBox(color: Color(0x66000000)),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: product?.name ?? 'Живая примерка',
                  canSwitch: _live && _service.canSwitchCamera,
                  showJoints: _showJoints,
                  onClose: () => Navigator.of(context).maybePop(),
                  onSwitch: () async {
                    await _service.switchCamera();
                    if (mounted) setState(() {});
                  },
                  onToggleJoints: () => setState(() => _showJoints = !_showJoints),
                ),
                const Spacer(),
                if (_statusText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.m),
                    child: _Hint(text: _statusText!),
                  ),
                TryOnProductStrip(
                  products: _products,
                  selectedId: product?.id,
                  dark: true,
                  onSelected: _wear,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.screenPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Завершить'),
                        ),
                      ),
                      if (product != null) ...[
                        const SizedBox(width: AppSizes.m),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                            ),
                            onPressed: () => CartActions.addToCart(context, product),
                            child: const Text('В корзину'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Подсказка над лентой товаров: что сейчас происходит.
  String? get _statusText {
    if (_error != null) return _error;
    if (_isStarting) return 'Запускаю камеру…';
    if (!_live) {
      return 'Предпросмотр 3D-модели на условной фигуре. Живая примерка '
          'с камерой работает на телефоне';
    }
    final BodyPose? pose = _pose;
    if (pose == null) return 'Встаньте перед камерой';
    final GarmentShape? shape =
        _product == null ? null : TryOnSupport.of(_product!).shape;
    final bool lower = shape == GarmentShape.shorts || shape == GarmentShape.pants;
    if (!pose.hasTorso) {
      return 'Отойдите подальше: в кадре должны быть плечи и бёдра';
    }
    if (lower && pose[BodyJoint.leftKnee] == null && pose[BodyJoint.rightKnee] == null) {
      return 'Для шорт и штанов в кадре должны быть ноги';
    }
    return null;
  }

  Widget _buildStage() {
    final GarmentMesh? mesh = _mesh;
    if (!_live) {
      return ColoredBox(
        color: const Color(0xFF2A2F3A),
        child: AnimatedBuilder(
          animation: _demo,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final BodyPose pose = _demoPose(_demo.value);
              return CustomPaint(
                painter: _StagePainter(
                  mesh: mesh,
                  pose: pose,
                  color: _color,
                  showJoints: true,
                ),
                size: constraints.biggest,
              );
            },
          ),
        ),
      );
    }

    final CameraController? camera = _service.camera;
    final Size? preview = _service.previewSize;
    if (camera == null || preview == null || !camera.value.isInitialized) {
      return const SizedBox.expand();
    }
    // Кадр камеры и слой с одеждой лежат в одной системе координат
    // и вместе растягиваются на весь экран (с обрезкой краёв).
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: preview.width,
        height: preview.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(camera),
            CustomPaint(
              painter: _StagePainter(
                mesh: mesh,
                pose: _pose,
                color: _color,
                showJoints: _showJoints,
                shading: _shading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Условная фигура для предпросмотра: покачивается и двигает руками.
  static BodyPose _demoPose(double t) {
    final double phase = t * 2 * math.pi;
    final double sway = math.sin(phase) * 0.03;
    final double turn = math.sin(phase * 0.5) * 0.35;
    final double arm = 0.5 + 0.5 * math.sin(phase * 1.5);
    final double half = 0.105 * (1 - turn.abs() * 0.35);
    final double cx = 0.5 + sway;
    return BodyPose({
      BodyJoint.leftShoulder: BodyPoint(cx - half, 0.27, turn * 0.08),
      BodyJoint.rightShoulder: BodyPoint(cx + half, 0.27, -turn * 0.08),
      BodyJoint.leftElbow: BodyPoint(cx - half - 0.05 - arm * 0.07, 0.39 - arm * 0.05),
      BodyJoint.rightElbow: BodyPoint(cx + half + 0.04, 0.40),
      BodyJoint.leftWrist: BodyPoint(cx - half - 0.07 - arm * 0.12, 0.49 - arm * 0.16),
      BodyJoint.rightWrist: BodyPoint(cx + half + 0.05, 0.52),
      BodyJoint.leftHip: BodyPoint(0.5 - 0.07 + sway * 0.4, 0.53),
      BodyJoint.rightHip: BodyPoint(0.5 + 0.07 + sway * 0.4, 0.53),
      BodyJoint.leftKnee: BodyPoint(0.5 - 0.075, 0.70),
      BodyJoint.rightKnee: BodyPoint(0.5 + 0.075, 0.70),
      BodyJoint.leftAnkle: BodyPoint(0.5 - 0.08, 0.87),
      BodyJoint.rightAnkle: BodyPoint(0.5 + 0.08, 0.87),
    });
  }
}

/// Слой поверх кадра: 3D-одежда и, по желанию, точки суставов.
class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.mesh,
    required this.pose,
    required this.color,
    required this.showJoints,
    this.shading,
  });

  final GarmentMesh? mesh;
  final BodyPose? pose;
  final Color color;
  final bool showJoints;
  final ui.Image? shading;

  static const List<(BodyJoint, BodyJoint)> _bones = [
    (BodyJoint.leftShoulder, BodyJoint.rightShoulder),
    (BodyJoint.leftShoulder, BodyJoint.leftElbow),
    (BodyJoint.leftElbow, BodyJoint.leftWrist),
    (BodyJoint.rightShoulder, BodyJoint.rightElbow),
    (BodyJoint.rightElbow, BodyJoint.rightWrist),
    (BodyJoint.leftShoulder, BodyJoint.leftHip),
    (BodyJoint.rightShoulder, BodyJoint.rightHip),
    (BodyJoint.leftHip, BodyJoint.rightHip),
    (BodyJoint.leftHip, BodyJoint.leftKnee),
    (BodyJoint.leftKnee, BodyJoint.leftAnkle),
    (BodyJoint.rightHip, BodyJoint.rightKnee),
    (BodyJoint.rightKnee, BodyJoint.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final BodyPose? pose = this.pose;
    if (pose == null) return;
    if (showJoints) _paintSkeleton(canvas, size, pose);
    final GarmentMesh? mesh = this.mesh;
    if (mesh == null) return;
    Garment3DPainter(
      mesh: mesh,
      frames: BodyRig.frames(pose, size.width, size.height),
      color: color,
      shading: shading,
    ).paint(canvas, size);
  }

  void _paintSkeleton(Canvas canvas, Size size, BodyPose pose) {
    final Paint line = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = size.shortestSide * 0.008
      ..strokeCap = StrokeCap.round;
    Offset? at(BodyJoint joint) {
      final BodyPoint? point = pose[joint];
      return point == null
          ? null
          : Offset(point.x * size.width, point.y * size.height);
    }

    for (final (BodyJoint a, BodyJoint b) in _bones) {
      final Offset? from = at(a);
      final Offset? to = at(b);
      if (from != null && to != null) canvas.drawLine(from, to, line);
    }
    for (final BodyJoint joint in BodyJoint.values) {
      final Offset? point = at(joint);
      if (point != null) {
        canvas.drawCircle(
          point,
          size.shortestSide * 0.012,
          Paint()..color = AppColors.accent,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.mesh != mesh ||
      oldDelegate.color != color ||
      oldDelegate.shading != shading ||
      oldDelegate.showJoints != showJoints;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.canSwitch,
    required this.showJoints,
    required this.onClose,
    required this.onSwitch,
    required this.onToggleJoints,
  });

  final String title;
  final bool canSwitch;
  final bool showJoints;
  final VoidCallback onClose;
  final VoidCallback onSwitch;
  final VoidCallback onToggleJoints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s, vertical: AppSizes.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Закрыть примерку',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Живая примерка',
                  style: AppTextStyles.caption.copyWith(color: AppColors.white),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: showJoints ? 'Скрыть точки тела' : 'Показать точки тела',
            onPressed: onToggleJoints,
            icon: Icon(
              Icons.accessibility_new,
              color: showJoints ? AppColors.accent : AppColors.white,
            ),
          ),
          if (canSwitch)
            IconButton(
              tooltip: 'Сменить камеру',
              onPressed: onSwitch,
              icon: const Icon(Icons.cameraswitch_outlined, color: AppColors.white),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.l, vertical: AppSizes.m),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySecondary.copyWith(color: AppColors.white),
      ),
    );
  }
}
