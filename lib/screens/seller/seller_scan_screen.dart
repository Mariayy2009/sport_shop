import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/try_on_scan_repository.dart';
import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/try_on.dart';
import '../../models/user.dart';
import '../../services/try_on/body_pose.dart';
import '../../services/try_on/garment_scan.dart';
import '../../services/try_on/live_try_on_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';

/// Сканер продавца: продавец надевает свою вещь и поворачивается
/// перед камерой — получается примерка, снятая на человеке.
/// Покупатели видят её в живой примерке сразу, без ожидания.
class SellerScanScreen extends StatefulWidget {
  const SellerScanScreen({super.key, this.embedded = false});

  /// Внутри нижней вкладки «Сканер» — без своей шапки и навигации.
  final bool embedded;

  @override
  State<SellerScanScreen> createState() => _SellerScanScreenState();
}

class _ScanItem {
  const _ScanItem(this.product, this.scanned);

  final Product product;
  final bool scanned;
}

class _SellerScanScreenState extends State<SellerScanScreen> {
  late Future<List<_ScanItem>> _future = _load();

  Future<List<_ScanItem>> _load() async {
    final int? sellerId = context.read<AuthState>().currentUser?.id;
    if (sellerId == null) return const [];
    final TryOnScanRepository scans = context.read<TryOnScanRepository>();
    final List<Product> products = await context.read<ProductRepository>().getProducts(
          ProductFilter(sellerId: sellerId, includeBlocked: true),
        );
    return [
      for (final Product product in products)
        if (TryOnSupport.of(product).shape != null)
          _ScanItem(product, await scans.forProduct(product.id!) != null),
    ];
  }

  Future<void> _scan(Product product) async {
    final bool? done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ScanCaptureScreen(product: product)),
    );
    if (done == true && mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<AuthState>().currentUser;
    final Widget body = user == null || !user.isSeller
        ? const EmptyState(
            icon: Icons.view_in_ar_outlined,
            title: 'Сканер доступен продавцам',
          )
        : FutureBuilder<List<_ScanItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<_ScanItem> items = snapshot.data ?? const [];
              return ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  const Text('Сканер примерки', style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSizes.xs),
                  const Text(
                    'Наденьте вещь, поставьте телефон вертикально и встаньте '
                    'в полный рост в 2–3 метрах. Медленно повернитесь на 360°. '
                    'Покупатели увидят в живой примерке вещь, снятую на человеке: '
                    'с настоящими складками, принтом и видом со спины.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: AppSizes.l),
                  if (items.isEmpty)
                    const Text(
                      'Пока нет одежды, которую можно отсканировать: '
                      'футболки, майки, форма, кимоно, шорты, штаны.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  for (final _ScanItem item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.s),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSizes.s),
                        onTap: () => _scan(item.product),
                        child: Row(
                          children: [
                            ProductImage(
                              imageUrl: item.product.imageUrl,
                              width: 56,
                              height: 56,
                              borderRadius: AppSizes.radiusS,
                            ),
                            const SizedBox(width: AppSizes.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: AppTextStyles.body
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    item.scanned
                                        ? 'Примерка готова ✓'
                                        : 'Не отсканирована',
                                    style: AppTextStyles.caption.copyWith(
                                      color: item.scanned
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(item.scanned ? Icons.refresh : Icons.view_in_ar),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
    return widget.embedded
        ? body
        : AppScaffold(title: 'Сканер примерки', navTab: MainTab.ai, body: body);
  }
}

// -----------------------------------------------------------------------------
// Съёмка

class _ScanCaptureScreen extends StatefulWidget {
  const _ScanCaptureScreen({required this.product});

  final Product product;

  @override
  State<_ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends State<_ScanCaptureScreen> {
  final LiveTryOnService _service = LiveTryOnService();
  late final GarmentScan _scan = GarmentScan(
    isBottom: switch (TryOnSupport.of(widget.product).shape) {
      GarmentShape.shorts || GarmentShape.pants => true,
      _ => false,
    },
  );
  ScanView? _view;
  String? _error;
  bool _starting = true;
  bool _finished = false;
  DateTime _lastShot = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!LiveTryOnService.isSupported) {
      setState(() {
        _starting = false;
        _error = 'Сканирование работает на телефоне с камерой';
      });
      return;
    }
    try {
      await _service.start();
      _service.onScanFrame = _onFrame;
    } on AppException catch (error) {
      _error = error.message;
    }
    if (mounted) setState(() => _starting = false);
  }

  void _onFrame(ScanFrame frame, BodyPose pose) {
    if (_finished) return;
    final ScanView? view = _scan.addPose(pose);
    // Вырезание — не чаще раза в 0,4 с и только если кадр лучше прежнего.
    final DateTime now = DateTime.now();
    if (view != null &&
        _scan.wantsShot(view, pose) &&
        now.difference(_lastShot) > const Duration(milliseconds: 400)) {
      _lastShot = now;
      final ScanShot? shot = _scan.cut(frame, pose);
      if (shot != null) _scan.keep(view, shot);
    }
    if (mounted) setState(() => _view = view);
    if (_scan.isComplete) _finish();
  }

  Future<void> _finish() async {
    _finished = true;
    _service.onScanFrame = null;
    await _service.stop();
    if (!mounted) return;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ScanProcessingScreen(product: widget.product, scan: _scan),
      ),
    );
    if (mounted) Navigator.of(context).pop(saved ?? false);
  }

  @override
  void dispose() {
    _service.onScanFrame = null;
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? camera = _service.camera;
    final Size? preview = _service.previewSize;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && preview != null && camera.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: preview.width,
                height: preview.height,
                child: CameraPreview(camera),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Отменить',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: AppColors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.product.name,
                        style: AppTextStyles.sectionTitle.copyWith(color: AppColors.white),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(AppSizes.screenPadding),
                  padding: const EdgeInsets.all(AppSizes.l),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _error ??
                            (_starting
                                ? 'Запускаю камеру…'
                                : _view == null
                                    ? 'Встаньте в полный рост: в кадре плечи и бёдра'
                                    : 'Медленно поворачивайтесь. Сейчас: ${_view!.label.toLowerCase()}'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(color: AppColors.white),
                      ),
                      const SizedBox(height: AppSizes.m),
                      LinearProgressIndicator(
                        value: _scan.progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                        backgroundColor: const Color(0x33FFFFFF),
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSizes.m),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final ScanView view in ScanView.values)
                            Column(
                              children: [
                                Icon(
                                  _scan.seen.contains(view)
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: _scan.seen.contains(view)
                                      ? AppColors.success
                                      : AppColors.white,
                                ),
                                Text(
                                  view.label,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.white),
                                ),
                              ],
                            ),
                        ],
                      ),
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
}

// -----------------------------------------------------------------------------
// Обработка

class _ScanProcessingScreen extends StatefulWidget {
  const _ScanProcessingScreen({required this.product, required this.scan});

  final Product product;
  final GarmentScan scan;

  @override
  State<_ScanProcessingScreen> createState() => _ScanProcessingScreenState();
}

class _ScanProcessingScreenState extends State<_ScanProcessingScreen>
    with SingleTickerProviderStateMixin {
  /// Этапы обработки. Сама обработка занимает секунды, но продавцу
  /// важно видеть, что примерка «собирается»: экран идёт ~10 секунд.
  /// Покупателей это не касается — у них примерка мгновенная.
  static const List<String> stages = [
    'Выделяем вещь на кадрах',
    'Убираем фон и тело',
    'Строим посадку по плечам и бёдрам',
    'Собираем вид со спины',
    'Сохраняем примерку',
  ];
  static const Duration duration = Duration(seconds: 10);

  late final AnimationController _progress =
      AnimationController(vsync: this, duration: duration)..forward();
  Uint8List? _front;
  Uint8List? _back;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _process();
  }

  static Future<Uint8List?> _png(ScanShot? shot) async {
    if (shot == null) return null;
    final Completer<ui.Image> done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      shot.rgba, shot.width, shot.height, ui.PixelFormat.rgba8888, done.complete,
    );
    final ui.Image image = await done.future;
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _process() async {
    final TryOnScanRepository repository = context.read<TryOnScanRepository>();
    try {
      final Uint8List? front = await _png(widget.scan.front);
      final Uint8List? back = await _png(widget.scan.back);
      if (front == null) throw const AppException('Не удалось снять вещь спереди');
      await Future.wait([
        repository.save(
          widget.product.id!,
          frontPng: front,
          front: widget.scan.front!.anchors,
          backPng: back,
          back: widget.scan.back?.anchors,
        ),
        // Экран обработки идёт до конца, даже если сохранили раньше.
        _progress.forward().orCancel.catchError((_) {}),
      ]);
      if (mounted) {
        setState(() {
          _front = front;
          _back = back;
          _saved = true;
        });
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) setState(() => _error = 'Не удалось сохранить примерку');
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Обработка создания примерки',
      bottomAction: _saved || _error != null
          ? CustomButton(
              text: _saved ? 'Готово' : 'Назад',
              onPressed: () => Navigator.of(context).pop(_saved),
            )
          : null,
      body: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final double t = _progress.value;
          final int stage = math.min((t * stages.length).floor(), stages.length - 1);
          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              Text(widget.product.name, style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSizes.l),
              if (_error != null)
                Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.error))
              else if (!_saved) ...[
                LinearProgressIndicator(
                  value: t,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                const SizedBox(height: AppSizes.m),
                for (int i = 0; i < stages.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: i < stage
                        ? const Icon(Icons.check_circle, color: AppColors.success)
                        : i == stage
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Icon(Icons.radio_button_unchecked,
                                color: AppColors.textHint),
                    title: Text(
                      stages[i],
                      style: i <= stage ? AppTextStyles.body : AppTextStyles.bodySecondary,
                    ),
                  ),
              ] else ...[
                const Text(
                  'Примерка готова. Покупатели увидят эту вещь в живой примерке — '
                  'спереди и со спины.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSizes.m),
                Row(
                  children: [
                    for (final (String title, Uint8List? image) in [
                      ('Спереди', _front),
                      ('Сзади', _back),
                    ])
                      if (image != null)
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 220,
                                margin: const EdgeInsets.all(AppSizes.xs),
                                color: AppColors.surface,
                                child: Image.memory(image, fit: BoxFit.contain),
                              ),
                              Text(title, style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
