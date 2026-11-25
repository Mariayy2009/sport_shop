import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cart_actions.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/try_on_scan_repository.dart';
import '../../models/product.dart';
import '../../models/try_on.dart';
import '../../services/try_on/body_pose.dart';
import '../../services/size_advisor.dart';
import '../../services/try_on/body_shading.dart';
import '../../services/try_on/garment_cutout.dart';
import '../../services/try_on/garment_scan.dart';
import '../../services/try_on/garment_color.dart';
import '../../services/try_on/garment_mesh.dart';
import '../../services/try_on/kimono_outfit.dart';
import '../../services/try_on/live_try_on_service.dart';
import '../../services/try_on/photo_try_on_service.dart';
import '../../state/profile_state.dart';
import '../../widgets/dark_pill.dart';
import '../../widgets/garment_3d_painter.dart';
import '../../widgets/fitted_garment_painter.dart';
import '../../widgets/size_fit.dart';
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

  /// Цвет кожи человека в кадре — им закрывается своя одежда.
  Color? _skin;
  bool _shadingBusy = false;

  /// Движение условной фигуры в предпросмотре (без камеры).
  late final AnimationController _demo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  List<Product> _products = const [];
  Product? _product;
  GarmentMesh? _mesh;

  /// Для кимоно: штаны (3D) и пояс. null — не кимоно.
  KimonoOutfit? _kimono;
  GarmentMesh? _pantsMesh;
  Color _color = GarmentColor.fallback;
  BodyPose? _pose;

  /// Поза для слоя одежды: каждый кадр перерисовывается только он,
  /// без пересборки всего экрана (камера, панели) — это убирает лаги.
  final ValueNotifier<BodyPose?> _poseNotifier = ValueNotifier<BodyPose?>(null);

  /// Что видно в кадре — от этого зависит подсказка; экран
  /// пересобирается, только когда это меняется.
  (bool, bool, bool) _poseState(BodyPose? pose) => (
        pose != null,
        pose?.hasTorso ?? false,
        pose?[BodyJoint.leftKnee] != null || pose?[BodyJoint.rightKnee] != null,
      );
  String? _error;
  bool _isStarting = true;
  bool _showJoints = false;

  /// Вещь, вырезанная из фото товара (режим «Фото вещи»). null — фото
  /// не подходит (вещь снята на человеке или фон не однотонный).
  GarmentCutout? _cutout;

  /// Вещь сзади — если продавец отсканировал примерку с поворотом.
  GarmentCutout? _backCutout;

  /// Примерка снята продавцом на человеке (а не из фото каталога).
  bool _scanned = false;

  /// true — накладывать фото вещи, false — 3D-модель.
  bool _photoMode = true;
  String? _size;
  SizeAdvice? _advice;
  static const SizeAdvisor _sizeAdvisor = SizeAdvisor();

  bool get _usePhoto => _photoMode && _cutout != null;


  double get _sizeScale => SizeFit.scale(
        _product?.availableSizes ?? const [],
        _size,
        _advice?.size,
      );

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
        if (!mounted) return;
        final bool changed = _poseState(pose) != _poseState(_pose);
        _pose = pose;
        _poseNotifier.value = pose;
        if (changed) setState(() {});
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
      setState(() {
        _shading = image;
        _skin = shading.skin ?? _skin;
      });
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
      GarmentCutout? cutout;
      GarmentCutout? backCutout;
      bool scanned = false;
      final KimonoOutfit? kimono =
          KimonoOutfit.isKimono(product) ? KimonoOutfit.of(product) : null;
      final TryOnScanRepository scans = context.read<TryOnScanRepository>();
      try {
        // Примерка, снятая продавцом на человеке, — лучше фото каталога.
        final ScanRecord? scan = await scans.forProduct(product.id!);
        if (scan != null) {
          cutout = await GarmentCutout.fromScan(
            await File(scan.frontPath).readAsBytes(),
            scan.front,
          );
          if (scan.backPath != null && scan.back != null) {
            backCutout = await GarmentCutout.fromScan(
              await File(scan.backPath!).readAsBytes(),
              scan.back!,
            );
          }
          scanned = cutout != null;
        }
      } on Exception catch (error) {
        debugPrint('Отсканированная примерка не открылась: $error');
      }
      try {
        final Uint8List bytes = await _images.loadProductImage(product);
        color = await GarmentColor.forProduct(product.imageUrl, bytes);
        // Вещь на фото надета на человека — вырезать её нельзя.
        if (cutout == null &&
            !PhotoTryOnService.modelPhotos.contains(product.imageUrl) &&
            (kimono?.photoUsable ?? true)) {
          cutout = await GarmentCutout.fromImage(
            bytes,
            isBottom: shape == GarmentShape.shorts || shape == GarmentShape.pants,
          );
        }
      } on AppException {
        // У товара нет фото — оставляем цвет по умолчанию.
      }
      // Кимоно: штаны надеваются 3D-моделью, если их нет на фото.
      GarmentMesh? pantsMesh;
      if (kimono != null && !(kimono.photoHasPants && cutout != null && !scanned)) {
        final ByteData pants = await rootBundle.load(GarmentShape.pants.assetPath);
        pantsMesh = GarmentMesh.fromGlb(pants.buffer.asUint8List());
      }
      if (!mounted) return;
      final SizeAdvice? advice =
          _sizeAdvisor.advise(product, context.read<ProfileState>().sizes);
      final List<String> sizes = product.availableSizes;
      setState(() {
        _product = product;
        _mesh = mesh;
        _kimono = kimono;
        _pantsMesh = pantsMesh;
        _color = color;
        _cutout = cutout;
        _backCutout = backCutout;
        _scanned = scanned;
        _advice = advice;
        // Сначала — рекомендуемый размер, без анкеты — средний.
        _size = advice?.size ??
            (sizes.isEmpty ? null : sizes[sizes.length ~/ 2]);
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
    _poseNotifier.dispose();
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
                if (_scanned && _usePhoto)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.xs),
                    child: Text(
                      'Примерка снята продавцом на человеке',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (product != null)
                  _FitPanel(
                    sizes: product.availableSizes,
                    selected: _size,
                    advice: _advice,
                    hasPhoto: _cutout != null,
                    photoMode: _photoMode,
                    onSize: (size) => setState(() => _size = size),
                    onPhotoMode: (value) => setState(() => _photoMode = value),
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
      return 'Предпросмотр на условной фигуре. Живая примерка '
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

  /// Пояс рисуется отдельно, если его нет на вырезанном фото
  /// (у кимоно, снятого целиком, пояс уже на фото).
  Color? get _beltColor {
    final KimonoOutfit? kimono = _kimono;
    if (kimono == null) return null;
    final bool photoBelt =
        _usePhoto && _cutout != null && !_scanned && kimono.photoHasPants;
    return photoBelt ? null : kimono.belt;
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
                  cutout: _usePhoto ? _cutout : null,
                  shape: _product == null ? null : TryOnSupport.of(_product!).shape,
                  sizeScale: _sizeScale,
                  pantsMesh: _pantsMesh,
                  belt: _beltColor,
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
                pose: null,
                poseListenable: _poseNotifier,
                color: _color,
                showJoints: _showJoints,
                shading: _shading,
                skin: _skin,
                cutout: _usePhoto ? _cutout : null,
                backCutout: _usePhoto ? _backCutout : null,
                shape: _product == null ? null : TryOnSupport.of(_product!).shape,
                sizeScale: _sizeScale,
                pantsMesh: _pantsMesh,
                belt: _beltColor,
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
    this.cutout,
    this.backCutout,
    this.shape,
    this.sizeScale = 1,
    this.skin,
    this.pantsMesh,
    this.belt,
    this.poseListenable,
  }) : super(repaint: poseListenable);

  /// Живая поза — перерисовка по каждому кадру без пересборки экрана.
  final ValueListenable<BodyPose?>? poseListenable;

  final GarmentMesh? mesh;
  final GarmentMesh? pantsMesh;
  final Color? belt;
  final GarmentCutout? cutout;
  final GarmentCutout? backCutout;
  final GarmentShape? shape;
  final double sizeScale;
  final Color? skin;
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
    final BodyPose? pose = poseListenable?.value ?? this.pose;
    if (pose == null) return;
    if (showJoints) _paintSkeleton(canvas, size, pose);
    // Штаны кимоно — под курткой.
    final GarmentMesh? pants = pantsMesh;
    if (pants != null) {
      Garment3DPainter(
        mesh: pants,
        frames: BodyRig.frames(pose, size.width, size.height),
        color: color,
        shading: shading,
      ).paint(canvas, size);
    }
    _paintTop(canvas, size, pose);
    final Color? belt = this.belt;
    if (belt != null) FittedGarmentPainter.paintBelt(canvas, size, pose, belt);
  }

  void _paintTop(Canvas canvas, Size size, BodyPose pose) {
    final GarmentCutout? cutout = this.cutout;
    final GarmentShape? shape = this.shape;
    if (cutout != null && shape != null) {
      // Человек повернулся спиной (лица не видно) — показываем спинку вещи.
      final bool facingAway = (pose.joints[BodyJoint.nose]?.confidence ?? 1) < 0.3;
      try {
        FittedGarmentPainter.paint(
          canvas,
          size,
          pose,
          facingAway && backCutout != null ? backCutout! : cutout,
          shape: shape,
          sizeScale: sizeScale,
          shading: shading,
          skin: skin,
        );
        return;
      } on Object catch (error) {
        // Фото вещи не нарисовалось — показываем 3D, а не роняем экран.
        debugPrint('Примерка по фото вещи: $error');
      }
    }
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
      oldDelegate.pantsMesh != pantsMesh ||
      oldDelegate.belt != belt ||
      oldDelegate.color != color ||
      oldDelegate.shading != shading ||
      oldDelegate.cutout != cutout ||
      oldDelegate.skin != skin ||
      oldDelegate.sizeScale != sizeScale ||
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

/// Размер и режим примерки: «Фото вещи» (настоящий принт и надписи)
/// или 3D-модель (следует за руками). Размер меняет вещь на теле:
/// больше рекомендуемого — шире и длиннее, меньше — уже и короче.
class _FitPanel extends StatelessWidget {
  const _FitPanel({
    required this.sizes,
    required this.selected,
    required this.advice,
    required this.hasPhoto,
    required this.photoMode,
    required this.onSize,
    required this.onPhotoMode,
  });

  final List<String> sizes;
  final String? selected;
  final SizeAdvice? advice;
  final bool hasPhoto;
  final bool photoMode;
  final ValueChanged<String> onSize;
  final ValueChanged<bool> onPhotoMode;

  @override
  Widget build(BuildContext context) {
    final String fit = SizeFit.describe(sizes, selected, advice?.size);
    final String note = advice == null
        ? 'Укажите рост и вес в профиле — подскажем размер'
        : selected == advice!.size
            ? 'Ваш размер по параметрам: ${advice!.size}'
            : 'Советуем ${advice!.size}. Размер $selected будет: $fit';
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding, 0, AppSizes.screenPadding, AppSizes.s,
      ),
      padding: const EdgeInsets.all(AppSizes.s),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  note,
                  style: AppTextStyles.caption.copyWith(color: AppColors.white),
                ),
              ),
              if (hasPhoto)
                TextButton(
                  onPressed: () => onPhotoMode(!photoMode),
                  child: Text(
                    photoMode ? 'Показать 3D' : 'Показать фото вещи',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (sizes.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xs),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sizes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSizes.xs),
                itemBuilder: (context, index) {
                  final String size = sizes[index];
                  final bool isSelected = size == selected;
                  final bool isAdvice = size == advice?.size;
                  return Center(
                    child: DarkPill(
                      label: size,
                      selected: isSelected,
                      highlighted: isAdvice,
                      onTap: () => onSize(size),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
