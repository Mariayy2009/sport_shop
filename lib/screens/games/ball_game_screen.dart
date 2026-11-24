import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/games/ball_game.dart';
import '../../services/try_on/body_pose.dart';
import '../../services/try_on/live_try_on_service.dart';
import '../../widgets/dark_pill.dart';

/// Игра «Набей мяч»: камера находит тело (ML Kit Pose, на телефоне),
/// сверху падает мяч из каталога — его нужно отбивать.
///
/// Футбол — чеканка стопой, коленом, головой. Волейбол — нижний приём
/// (предплечья) или верхний (ладони над головой). На компьютере без
/// камеры мяч отбивается пальцем — чтобы проверить игру.
class BallGameScreen extends StatefulWidget {
  const BallGameScreen({super.key, this.initialMode = BallGameMode.football});

  final BallGameMode initialMode;

  @override
  State<BallGameScreen> createState() => _BallGameScreenState();
}

class _BallGameScreenState extends State<BallGameScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Мячи из каталога: футбольный и волейбольный.
  static const String footballImage = 'assets/images/products/trionda_ball.jpg';
  static const String volleyballImage = 'assets/images/products/mikasa_v200w.jpg';
  /// Свой рисунок: на фото каталога мяч обрезан краем кадра.
  static const String basketballImage = 'assets/images/game_basketball.png';

  /// Кадр без камеры (компьютер): вертикальный, как телефон.
  static const Size _demoFrame = Size(720, 1280);

  final LiveTryOnService _service = LiveTryOnService(withShading: false);
  late final Ticker _ticker = createTicker(_onTick);
  late final BallGame _game =
      BallGame(size: _demoFrame, mode: widget.initialMode);
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  StreamSubscription<BodyPose?>? _poses;
  BodyPose? _pose;
  Duration _lastTick = Duration.zero;
  final Map<String, ui.Image> _balls = {};
  Map<BallGameMode, int> _best = {};
  bool _isStarting = true;
  String? _error;

  /// Сколько ещё показывать вспышку касания (секунды).
  double _flash = 0;
  bool _newRecord = false;

  bool get _live => LiveTryOnService.isSupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_loadBalls(), _loadBest()]);
    if (_live) {
      await _startCamera();
    } else if (mounted) {
      setState(() => _isStarting = false);
    }
    _ticker.start();
  }

  Future<void> _loadBalls() async {
    for (final String path in [footballImage, volleyballImage, basketballImage]) {
      try {
        final ByteData data = await rootBundle.load(path);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 256,
        );
        _balls[path] = (await codec.getNextFrame()).image;
      } on Exception catch (error) {
        debugPrint('Картинка мяча не загрузилась: $error');
      }
    }
  }

  static String _bestKey(BallGameMode mode) => 'ball_game_best_${mode.name}';

  Future<void> _loadBest() async {
    final Map<BallGameMode, int> best = {};
    for (final BallGameMode mode in BallGameMode.values) {
      try {
        best[mode] = await _preferences.getInt(_bestKey(mode)) ?? 0;
      } on Exception {
        best[mode] = 0;
      }
    }
    _best = best;
  }

  Future<void> _startCamera() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      await _service.start();
      final Size? preview = _service.previewSize;
      if (preview != null) _game.size = preview;
      _game.reset();
      _poses ??= _service.poses.listen((pose) {
        _pose = pose;
        _game.updatePose(pose);
      });
    } on AppException catch (error) {
      _error = error.message;
    } on Exception catch (error) {
      debugPrint('Камера для игры не запустилась: $error');
      _error = 'Не удалось запустить камеру';
    }
    if (mounted) setState(() => _isStarting = false);
  }

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _lastTick = elapsed;
    final bool wasPlaying = _game.phase == BallGamePhase.playing;
    final BallHit? hit = _game.step(dt);
    if (hit != null) {
      _flash = 0.25;
      HapticFeedback.lightImpact();
    }
    _flash = math.max(0, _flash - dt);
    if (wasPlaying && _game.phase == BallGamePhase.over) _finish();
    if (mounted) setState(() {});
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final BallGameMode mode = _game.mode;
    if (_game.score > (_best[mode] ?? 0)) {
      _best = {..._best, mode: _game.score};
      _newRecord = true;
      try {
        await _preferences.setInt(_bestKey(mode), _game.score);
      } on Exception catch (error) {
        debugPrint('Рекорд не сохранился: $error');
      }
    }
  }

  void _start() {
    _newRecord = false;
    _game.start();
  }

  void _setMode(BallGameMode mode) {
    if (_game.mode == mode) return;
    setState(() {
      _game.mode = mode;
      _game.reset();
      _game.updatePose(_pose);
      _newRecord = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_live) return;
    // Камеру нельзя держать, когда приложение свёрнуто.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _service.stop();
      _game.reset();
    } else if (state == AppLifecycleState.resumed && _service.camera == null) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _poses?.cancel();
    _service.dispose();
    for (final ui.Image image in _balls.values) {
      image.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  String? get _statusText {
    if (_error != null) return _error;
    if (_isStarting) return 'Запускаю камеру…';
    if (!_live) {
      return 'На компьютере камеры нет: отбивай мяч мышкой. '
          'На телефоне мяч отбивается телом через камеру';
    }
    final BodyPose? pose = _pose;
    if (pose == null) return 'Встань перед камерой: поставь телефон и отойди';
    if ((_game.mode == BallGameMode.football ||
            _game.mode == BallGameMode.basketball) &&
        pose[BodyJoint.leftAnkle] == null &&
        pose[BodyJoint.rightAnkle] == null) {
      return 'Отойди дальше: в кадре нужны ноги';
    }
    if (_game.phase == BallGamePhase.playing) return null;
    return _game.mode.hint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildStage(),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 150,
            child: ColoredBox(color: Color(0x66000000)),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  canSwitch: _live && _service.canSwitchCamera,
                  onClose: () => Navigator.of(context).maybePop(),
                  onSwitch: () async {
                    await _service.switchCamera();
                    final Size? preview = _service.previewSize;
                    if (preview != null) _game.size = preview;
                    _game.reset();
                    if (mounted) setState(() {});
                  },
                ),
                _ModeTabs(selected: _game.mode, onSelected: _setMode),
                const SizedBox(height: AppSizes.s),
                _ScoreBar(
                  score: _game.score,
                  best: _best[_game.mode] ?? 0,
                ),
                const Spacer(),
                if (_statusText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.m),
                    child: _Hint(text: _statusText!),
                  ),
                if (_game.phase != BallGamePhase.playing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.screenPadding,
                      0,
                      AppSizes.screenPadding,
                      AppSizes.screenPadding,
                    ),
                    child: _StartPanel(
                      phase: _game.phase,
                      score: _game.score,
                      newRecord: _newRecord,
                      onStart: _isStarting ? null : _start,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage() {
    final Size frame = _game.size;
    final Widget painter = GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Без камеры мяч отбивается пальцем (мышкой).
      onTapDown: _live ? null : (details) => _game.tap(details.localPosition),
      child: CustomPaint(
        painter: _GamePainter(
          game: _game,
          pose: _live ? _pose : null,
          ball: _balls[switch (_game.mode) {
            BallGameMode.football => footballImage,
            BallGameMode.basketball => basketballImage,
            _ => volleyballImage,
          }],
          flash: _flash,
        ),
      ),
    );
    final CameraController? camera = _service.camera;
    final bool hasCamera = _live && camera != null && camera.value.isInitialized;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: frame.width,
        height: frame.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCamera)
              CameraPreview(camera)
            else
              const ColoredBox(color: Color(0xFF1F3B2A)),
            painter,
          ],
        ),
      ),
    );
  }
}

/// Мяч, вспышка касания и точки, которыми можно бить.
class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.game,
    required this.pose,
    required this.ball,
    required this.flash,
  }) : super(repaint: null);

  final BallGame game;
  final BodyPose? pose;
  final ui.Image? ball;
  final double flash;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = game.radius;

    // Точки тела, которыми сейчас можно бить, — чтобы игрок видел,
    // что камера его нашла.
    for (final Offset point in game.parts.values) {
      canvas.drawCircle(
        point,
        r * 0.35,
        Paint()..color = AppColors.white.withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        point,
        r * 0.35,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08
          ..color = AppColors.accent,
      );
    }

    final BallHit? hit = game.lastHit;
    if (hit != null && flash > 0) {
      final double t = 1 - flash / 0.25;
      canvas.drawCircle(
        hit.at,
        r * (0.8 + t * 1.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.15 * (1 - t)
          ..color = AppColors.star.withValues(alpha: 1 - t),
      );
    }

    // Тень мяча и сам мяч — круг, вырезанный из фото товара.
    canvas.drawCircle(
      game.position + Offset(r * 0.12, r * 0.18),
      r,
      Paint()..color = const Color(0x55000000),
    );
    final ui.Image? image = ball;
    canvas.save();
    canvas.translate(game.position.dx, game.position.dy);
    canvas.rotate(game.angle);
    final Rect circle = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.clipPath(Path()..addOval(circle));
    if (image == null) {
      canvas.drawCircle(Offset.zero, r, Paint()..color = AppColors.white);
    } else {
      // Мяч на фото занимает почти весь квадрат — чуть обрезаем края.
      final double side = math.min(image.width, image.height) * 0.94;
      final Rect source = Rect.fromCenter(
        center: Offset(image.width / 2, image.height / 2),
        width: side,
        height: side,
      );
      canvas.drawImageRect(
        image,
        source,
        circle,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GamePainter oldDelegate) => true;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.canSwitch,
    required this.onClose,
    required this.onSwitch,
  });

  final bool canSwitch;
  final VoidCallback onClose;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Закрыть',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.white),
          ),
          Expanded(
            child: Text(
              'Набей мяч',
              style: AppTextStyles.sectionTitle.copyWith(color: AppColors.white),
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

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.selected, required this.onSelected});

  final BallGameMode selected;
  final ValueChanged<BallGameMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: [
          for (final BallGameMode mode in BallGameMode.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.s),
              child: DarkPill(
                label: '${mode.sport}: ${mode.title.toLowerCase()}',
                selected: mode == selected,
                onTap: () => onSelected(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score, required this.best});

  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$score',
            style: AppTextStyles.screenTitle.copyWith(
              color: AppColors.white,
              fontSize: 48,
              height: 1,
            ),
          ),
          const SizedBox(width: AppSizes.s),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'касаний',
              style: AppTextStyles.body.copyWith(color: AppColors.white),
            ),
          ),
          const Spacer(),
          const Icon(Icons.emoji_events, color: AppColors.star, size: 20),
          const SizedBox(width: AppSizes.xxs),
          Text(
            'Рекорд: $best',
            style: AppTextStyles.body.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.phase,
    required this.score,
    required this.newRecord,
    required this.onStart,
  });

  final BallGamePhase phase;
  final int score;
  final bool newRecord;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final bool over = phase == BallGamePhase.over;
    return Container(
      padding: const EdgeInsets.all(AppSizes.l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (over) ...[
            Text(
              newRecord ? 'Новый рекорд: $score!' : 'Мяч упал. Касаний: $score',
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.m),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.m),
              ),
              icon: const Icon(Icons.sports_soccer),
              label: Text(over ? 'Ещё раз' : 'Начать'),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.m, vertical: AppSizes.s),
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
