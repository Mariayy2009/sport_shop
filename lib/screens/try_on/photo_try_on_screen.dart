import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/cart_actions.dart';
import '../../data/repositories/product_repository.dart';
import '../../models/product.dart';
import '../../models/try_on.dart';
import '../../services/media_storage.dart';
import '../../state/auth_state.dart';
import '../../state/try_on_controller.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/guest_prompt.dart';
import '../../widgets/photo_action_sheet.dart';
import '../../widgets/product_image.dart';
import '../../widgets/try_on_product_strip.dart';
import '../../widgets/try_on_server_sheet.dart';

/// Примерка по фотографии: выбор фото → генерация → результат.
///
/// Изображение создаёт открытая модель FASHN VTON v1.5 на ноутбуке
/// пользователя; приложение отправляет ей фото человека и фото товара.
class PhotoTryOnScreen extends StatefulWidget {
  const PhotoTryOnScreen({super.key, this.productId});

  final int? productId;

  @override
  State<PhotoTryOnScreen> createState() => _PhotoTryOnScreenState();
}

class _PhotoTryOnScreenState extends State<PhotoTryOnScreen> {
  late final Future<List<Product>> _products = _load();

  /// Товары, которые можно примерить по фото. Товар из аргумента
  /// маршрута выбирается, если контроллер ещё не знает о нём.
  Future<List<Product>> _load() async {
    final TryOnController controller = context.read<TryOnController>();
    final List<Product> all =
        await context.read<ProductRepository>().getProducts();
    final List<Product> wearable =
        all.where((product) => TryOnSupport.of(product).photo).toList();
    if (controller.product == null) {
      for (final Product product in wearable) {
        if (product.id == widget.productId) controller.selectProduct(product);
      }
    }
    unawaited(controller.checkServer());
    return wearable;
  }

  Future<void> _pickPerson() async {
    final TryOnController controller = context.read<TryOnController>();
    final PhotoAction? action = await PhotoActionSheet.show(
      context,
      title: 'Ваша фотография',
    );
    if (action == null || action == PhotoAction.delete) return;
    try {
      await controller.pickPerson(
        action == PhotoAction.camera ? PhotoSource.camera : PhotoSource.gallery,
      );
    } on AppException catch (error) {
      if (mounted) AppMessages.showWarning(context, error.message);
    } on Exception catch (error) {
      debugPrint('Не удалось выбрать фото для примерки: $error');
      if (mounted) {
        AppMessages.showError(
          context,
          'Не удалось получить фото. Проверьте доступ к камере и галерее',
        );
      }
    }
  }

  Future<void> _deletePhotos() async {
    final TryOnController controller = context.read<TryOnController>();
    final bool confirmed = await AppMessages.showConfirmDialog(
      context,
      title: 'Удалить мои фото?',
      message: 'Ваша фотография и все сохранённые примерки будут '
          'удалены с телефона.',
      confirmText: 'Удалить',
      isDestructive: true,
    );
    if (!confirmed) return;
    await controller.deleteAllPhotos();
    if (mounted) AppMessages.showSuccess(context, 'Фото и примерки удалены');
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final TryOnController controller = context.watch<TryOnController>();

    return PopScope(
      // Во время генерации «Назад» сначала спрашивает про отмену.
      canPop: !controller.isBusy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        final bool stop = await AppMessages.showConfirmDialog(
          context,
          title: 'Остановить примерку?',
          message: 'Генерация ещё идёт. Если выйти, она будет отменена.',
          confirmText: 'Остановить',
          isDestructive: true,
        );
        if (!stop) return;
        await controller.cancel();
        navigator.pop();
      },
      child: AppScaffold(
        title: 'Примерка по фото',
        navTab: MainTab.home,
        body: !isLoggedIn
            ? const GuestPrompt(
                title: 'Примерка по фотографии',
                message: 'Войдите, чтобы загрузить фото и увидеть вещь на себе',
                icon: Icons.auto_awesome,
              )
            : FutureBuilder<List<Product>>(
                future: _products,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final List<Product> products = snapshot.data ?? const [];
                  return switch (controller.phase) {
                    TryOnPhase.uploading ||
                    TryOnPhase.generating =>
                      _GeneratingView(controller: controller),
                    TryOnPhase.done => _ResultView(
                        controller: controller,
                        products: products,
                      ),
                    TryOnPhase.idle => _SetupView(
                        controller: controller,
                        products: products,
                        onPickPerson: _pickPerson,
                        onDeletePhotos: _deletePhotos,
                      ),
                  };
                },
              ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Подготовка: сервер, фото, товар
// -----------------------------------------------------------------------------

class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.controller,
    required this.products,
    required this.onPickPerson,
    required this.onDeletePhotos,
  });

  final TryOnController controller;
  final List<Product> products;
  final VoidCallback onPickPerson;
  final VoidCallback onDeletePhotos;

  @override
  Widget build(BuildContext context) {
    final Product? product = controller.product;
    final bool canStart = controller.serverReady &&
        controller.personPhoto != null &&
        product != null;
    final TryOnServerStatus? server = controller.server;
    // Прогноз по времени последней генерации на этом ноутбуке.
    final String estimate = server?.secondsPerStep == null
        ? 'Первая примерка покажет, сколько это занимает на вашем ноутбуке'
        : 'Обычно около ${_minutes(server!.secondsPerStep! * 20)}';

    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        _ServerCard(controller: controller),
        const SizedBox(height: AppSizes.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PhotoSlot(
                title: 'Ваше фото',
                hint: 'В полный рост, при хорошем свете',
                onTap: onPickPerson,
                child: controller.personPhoto == null
                    ? null
                    : Image.file(
                        File(controller.personPhoto!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
              ),
            ),
            const SizedBox(width: AppSizes.m),
            Expanded(
              child: _PhotoSlot(
                title: 'Товар',
                hint: product?.name ?? 'Выберите товар ниже',
                child: product == null
                    ? null
                    : ProductImage(imageUrl: product.imageUrl, borderRadius: 0),
              ),
            ),
          ],
        ),
        if (controller.error != null) ...[
          const SizedBox(height: AppSizes.m),
          Container(
            padding: const EdgeInsets.all(AppSizes.m),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: AppSizes.s),
                Expanded(
                  child: Text(controller.error!, style: AppTextStyles.bodySecondary),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSizes.l),
        ElevatedButton.icon(
          onPressed: canStart ? controller.generate : null,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Примерить'),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          canStart
              ? estimate
              : !controller.serverReady
                  ? 'Сначала подключите сервер примерки'
                  : controller.personPhoto == null
                      ? 'Добавьте свою фотографию'
                      : 'Выберите товар',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSizes.l),
        const Text('Что примерить', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSizes.s),
        TryOnProductStrip(
          products: products,
          selectedId: product?.id,
          onSelected: controller.selectProduct,
        ),
        if (controller.saved.isNotEmpty) ...[
          const SizedBox(height: AppSizes.l),
          const Text('Мои примерки', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSizes.s),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.saved.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSizes.s),
              itemBuilder: (context, index) => _SavedTile(
                result: controller.saved[index],
                onDelete: () => controller.deleteSaved(controller.saved[index]),
              ),
            ),
          ),
        ],
        if (controller.personPhoto != null || controller.saved.isNotEmpty) ...[
          const SizedBox(height: AppSizes.m),
          Center(
            child: TextButton.icon(
              onPressed: onDeletePhotos,
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              label: const Text(
                'Удалить моё фото и примерки',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Состояние сервера примерки и переход к его настройке.
class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.controller});

  final TryOnController controller;

  @override
  Widget build(BuildContext context) {
    final TryOnServerStatus? server = controller.server;
    final String? url = controller.serverUrl;
    final (Color dot, String title, String subtitle) = controller.isCheckingServer
        ? (AppColors.warning, 'Проверяю сервер…', url ?? '')
        : url == null
            ? (
                AppColors.textHint,
                'Сервер примерки не подключён',
                'Запустите его на ноутбуке и укажите адрес',
              )
            : server == null || !server.reachable
                ? (
                    AppColors.error,
                    'Сервер недоступен',
                    server?.message ?? url,
                  )
                : !server.modelReady
                    ? (
                        AppColors.warning,
                        'Сервер запускается',
                        server.message ?? 'Модель загружается',
                      )
                    : (
                        AppColors.success,
                        'Сервер готов',
                        '$url · ${server.device == 'cuda' ? 'видеокарта' : 'процессор'}',
                      );

    return AppCard(
      onTap: () => TryOnServerSheet.show(context),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSizes.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (url != null)
            IconButton(
              tooltip: 'Проверить ещё раз',
              onPressed: controller.isCheckingServer ? null : controller.checkServer,
              icon: const Icon(Icons.refresh),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Плитка с фотографией: человек или товар.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.title,
    required this.hint,
    required this.child,
    this.onTap,
  });

  final String title;
  final String hint;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSizes.s),
        AspectRatio(
          aspectRatio: 0.75,
          child: Material(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child ??
                      const Center(
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 40,
                          color: AppColors.accent,
                        ),
                      ),
                  if (onTap != null && child != null)
                    Positioned(
                      right: AppSizes.s,
                      bottom: AppSizes.s,
                      child: Container(
                        padding: const EdgeInsets.all(AppSizes.s),
                        decoration: const BoxDecoration(
                          color: AppColors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          color: AppColors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          hint,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.result, required this.onDelete});

  final TryOnResult result;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Stack(
        children: [
          InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(child: Image.file(File(result.path))),
              ),
            ),
            child: Image.file(
              File(result.path),
              width: 112,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 112,
                height: 150,
                color: AppColors.accentSoft,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Удалить примерку',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.black.withValues(alpha: 0.55),
              ),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.close, color: AppColors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Генерация
// -----------------------------------------------------------------------------

class _GeneratingView extends StatefulWidget {
  const _GeneratingView({required this.controller});

  final TryOnController controller;

  @override
  State<_GeneratingView> createState() => _GeneratingViewState();
}

class _GeneratingViewState extends State<_GeneratingView> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Секундомер обновляется сам, даже когда сервер молчит между шагами.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TryOnController controller = widget.controller;
    final TryOnJobStatus? job = controller.job;
    final bool uploading = controller.phase == TryOnPhase.uploading;
    final double? progress =
        job == null || job.step == 0 ? null : job.progress;
    final String stage = uploading
        ? 'Отправляю фото на ноутбук'
        : job == null
            ? 'Жду ответа сервера'
            : job.state == TryOnJobState.queued
                ? 'В очереди'
                : job.step == 0
                    ? (job.stage ?? 'Подготовка фото')
                    : 'Шаг ${job.step} из ${job.totalSteps}';
    final double? eta = job?.etaSeconds;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: AppColors.accentSoft,
                    color: AppColors.accent,
                  ),
                  Center(
                    child: progress == null
                        ? const Icon(
                            Icons.auto_awesome,
                            size: 44,
                            color: AppColors.accent,
                          )
                        : Text(
                            '${(progress * 100).round()}%',
                            style: AppTextStyles.screenTitle.copyWith(fontSize: 36),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            const Text('Нейросеть примеряет вещь', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSizes.xs),
            Text(stage, style: AppTextStyles.body),
            const SizedBox(height: AppSizes.m),
            Text(
              'Прошло ${_clock(controller.elapsed.inSeconds)}'
              '${eta == null ? '' : ' · осталось около ${_minutes(eta)}'}',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSizes.l),
            const Text(
              'Генерация идёт на процессоре вашего ноутбука и занимает '
              'несколько минут. Не закрывайте сервер и не выключайте Wi-Fi; '
              'приложение можно свернуть.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.xl),
            CustomButton(
              text: 'Отменить',
              variant: ButtonVariant.secondary,
              onPressed: controller.cancel,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Результат
// -----------------------------------------------------------------------------

class _ResultView extends StatefulWidget {
  const _ResultView({required this.controller, required this.products});

  final TryOnController controller;
  final List<Product> products;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  /// Показывать исходное фото вместо результата.
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final TryOnController controller = widget.controller;
    final Product? product = controller.product;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          child: AspectRatio(
            aspectRatio: 0.75,
            child: ColoredBox(
              color: AppColors.black,
              child: _showOriginal && controller.personPhoto != null
                  ? Image.file(File(controller.personPhoto!), fit: BoxFit.contain)
                  : InteractiveViewer(
                      child: Image.memory(
                        controller.result!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.m),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.surface,
            selectedBackgroundColor: AppColors.black,
            selectedForegroundColor: AppColors.white,
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
          ),
          segments: const [
            ButtonSegment(value: false, label: Text('С вещью')),
            ButtonSegment(value: true, label: Text('Исходное фото')),
          ],
          selected: {_showOriginal},
          onSelectionChanged: (value) =>
              setState(() => _showOriginal = value.first),
        ),
        const SizedBox(height: AppSizes.m),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.resultSaved
                    ? null
                    : () async {
                        await controller.saveResult();
                        if (context.mounted) {
                          AppMessages.showSuccess(
                            context,
                            'Сохранено в «Мои примерки»',
                          );
                        }
                      },
                icon: Icon(
                  controller.resultSaved ? Icons.check : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(controller.resultSaved ? 'Сохранено' : 'Сохранить'),
              ),
            ),
            const SizedBox(width: AppSizes.m),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.generate(again: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Ещё вариант'),
              ),
            ),
          ],
        ),
        if (product != null) ...[
          const SizedBox(height: AppSizes.m),
          ElevatedButton.icon(
            onPressed: () => CartActions.addToCart(context, product),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Положить в корзину'),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamed(AppRoutes.product, arguments: product.id),
              child: Text('Открыть «${product.name}»'),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.m),
        const Text('Примерить другой товар', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSizes.s),
        TryOnProductStrip(
          products: widget.products,
          selectedId: product?.id,
          // Выбор другого товара возвращает к подготовке с тем же фото.
          onSelected: controller.selectProduct,
        ),
        const SizedBox(height: AppSizes.s),
        Center(
          child: TextButton(
            onPressed: controller.backToStart,
            child: const Text('Сменить фотографию'),
          ),
        ),
      ],
    );
  }
}

/// 125 → «2:05»
String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// 400 секунд → «7 мин»
String _minutes(double seconds) {
  if (seconds < 90) return 'минуты';
  return '${(seconds / 60).round()} мин';
}
