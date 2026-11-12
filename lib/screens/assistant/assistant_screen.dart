import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_messages.dart';
import '../../core/utils/cart_actions.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/product_actions.dart';
import '../../models/chat_message.dart';
import '../../models/user.dart';
import '../../models/user_sizes.dart';
import '../../state/assistant_state.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../state/profile_state.dart';
import '../../state/recommendation_state.dart';
import '../../widgets/product_image.dart';

/// ИИ-помощник: чат, в котором можно собрать комплект, подобрать размер,
/// сравнить товары и найти экипировку под бюджет. Ответы содержат
/// карточки реальных товаров каталога с объяснением выбора.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _shownMessages = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _input.clear();
    await context.read<AssistantState>().send(
          text,
          user: context.read<AuthState>().currentUser,
          sizes: context.read<ProfileState>().sizes,
        );
  }

  void _openQuiz() {
    if (!context.read<AuthState>().isLoggedIn) {
      AppMessages.showInfo(context, 'Опрос доступен после входа в аккаунт');
      Navigator.of(context).pushNamed(AppRoutes.login);
      return;
    }
    context
        .read<RecommendationState>()
        .startQuiz(context.read<ProfileState>().sizes);
    Navigator.of(context).pushNamed(AppRoutes.recommendationQuiz);
  }

  /// После нового сообщения прокручиваем чат к нему.
  void _scrollToEndIfNeeded(int count) {
    if (count == _shownMessages) return;
    _shownMessages = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AssistantState state = context.watch<AssistantState>();
    final User? user = context.watch<AuthState>().currentUser;
    final UserSizes? sizes = context.watch<ProfileState>().sizes;
    final List<ChatMessage> messages = state.messages;
    _scrollToEndIfNeeded(messages.length + (state.isTyping ? 1 : 0));

    return Column(
      children: [
        _AssistantBar(
          canClear: messages.isNotEmpty,
          onQuiz: _openQuiz,
          onClear: state.clear,
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              _Welcome(
                name: user?.greetingName,
                sportName: sizes?.sportName,
                showStarters: messages.isEmpty,
                onStarter: _send,
              ),
              for (int i = 0; i < messages.length; i++)
                _MessageView(
                  message: messages[i],
                  // Подсказки показываем только под последним ответом.
                  showSuggestions: i == messages.length - 1 && !state.isTyping,
                  onSuggestion: _send,
                ),
              if (state.isTyping) const _TypingBubble(),
            ],
          ),
        ),
        _InputBar(
          controller: _input,
          enabled: !state.isTyping,
          onSend: () => _send(_input.text),
        ),
      ],
    );
  }
}

class _AssistantBar extends StatelessWidget {
  const _AssistantBar({
    required this.canClear,
    required this.onQuiz,
    required this.onClear,
  });

  final bool canClear;
  final VoidCallback onQuiz;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSizes.l, AppSizes.s, AppSizes.s, AppSizes.s),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.white, size: 18),
            ),
            const SizedBox(width: AppSizes.m),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ИИ-помощник', style: AppTextStyles.sectionTitle),
                  Text('Подбор по каталогу магазина', style: AppTextStyles.caption),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onQuiz,
              icon: const Icon(Icons.checklist, size: 18),
              label: const Text('Опрос'),
            ),
            if (canClear)
              IconButton(
                tooltip: 'Начать диалог заново',
                onPressed: onClear,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}

/// Приветствие и стартовые вопросы в начале диалога.
class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.name,
    required this.sportName,
    required this.showStarters,
    required this.onStarter,
  });

  final String? name;
  final String? sportName;
  final bool showStarters;
  final ValueChanged<String> onStarter;

  List<String> get _starters {
    final String sport = sportName == null ? '' : ' для вида спорта «$sportName»';
    return [
      'Собери комплект$sport',
      'Какой размер мне подойдёт?',
      'Что купить до 20 000 ₸?',
      'Сравни обувь',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bubble(
          isUser: false,
          child: Text(
            'Привет${name == null ? '' : ', $name'}! Я помогу выбрать '
            'экипировку: соберу комплект под твой вид спорта и уровень, '
            'подберу размер, сравню товары и уложусь в бюджет. '
            'Спроси своими словами или выбери вариант ниже.',
            style: AppTextStyles.body.copyWith(height: 1.4),
          ),
        ),
        if (showStarters) _Chips(items: _starters, onTap: onStarter),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.showSuggestions,
    required this.onSuggestion,
  });

  final ChatMessage message;
  final bool showSuggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _Bubble(
        isUser: true,
        child: Text(
          message.text,
          style: AppTextStyles.body.copyWith(color: AppColors.white, height: 1.4),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bubble(
          isUser: false,
          child: Text(message.text, style: AppTextStyles.body.copyWith(height: 1.4)),
        ),
        for (final ProductPick pick in message.picks) _PickCard(pick: pick),
        if (message.isKit && message.picks.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.s),
            child: ElevatedButton.icon(
              onPressed: () => ProductActions.addAllToCart(context, [
                for (final ProductPick pick in message.picks)
                  (product: pick.product, size: pick.size),
              ]),
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: Text(
                'Добавить комплект — ${Formatters.price(message.picksTotal)}',
              ),
            ),
          ),
        if (showSuggestions && message.suggestions.isNotEmpty)
          _Chips(items: message.suggestions, onTap: onSuggestion),
      ],
    );
  }
}

/// Товар в ответе помощника: фото, причина выбора, размер, цена, «+».
class _PickCard extends StatelessWidget {
  const _PickCard({required this.pick});

  final ProductPick pick;

  @override
  Widget build(BuildContext context) {
    final bool inCart =
        context.watch<CartState>().containsProduct(pick.product.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.s),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.product, arguments: pick.product.id),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImage(
                  imageUrl: pick.product.imageUrl,
                  width: 64,
                  height: 64,
                  borderRadius: AppSizes.radiusS,
                ),
                const SizedBox(width: AppSizes.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pick.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (pick.reason.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.xxs),
                        Text(
                          pick.reason,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(height: 1.35),
                        ),
                      ],
                      const SizedBox(height: AppSizes.xs),
                      Row(
                        children: [
                          Text(
                            Formatters.price(pick.product.price),
                            style: AppTextStyles.price,
                          ),
                          if (pick.size != null) ...[
                            const SizedBox(width: AppSizes.s),
                            _SizeTag(size: pick.size!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.s),
                Tooltip(
                  message: inCart ? 'Уже в корзине' : 'Добавить в корзину',
                  child: Material(
                    color: inCart ? AppColors.success : AppColors.black,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: inCart
                          ? () => AppMessages.showInfo(context, 'Товар уже в корзине')
                          : () => CartActions.addToCart(
                                context,
                                pick.product,
                                size: pick.size,
                              ),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          inCart ? Icons.check : Icons.add,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeTag extends StatelessWidget {
  const _SizeTag({required this.size});

  final String size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s, vertical: AppSizes.xxs),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        'размер $size',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.accentDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isUser, required this.child});

  final bool isUser;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const Radius round = Radius.circular(AppSizes.radiusL);
    const Radius sharp = Radius.circular(AppSizes.xs);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.s),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.l, vertical: AppSizes.m),
        decoration: BoxDecoration(
          color: isUser ? AppColors.black : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: round,
            topRight: round,
            bottomLeft: isUser ? round : sharp,
            bottomRight: isUser ? sharp : round,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const _Bubble(
      isUser: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSizes.s),
          Text('Подбираю…', style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.m),
      child: Wrap(
        spacing: AppSizes.s,
        runSpacing: AppSizes.s,
        children: [
          for (final String item in items)
            ActionChip(
              label: Text(item),
              labelStyle: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.accentDark,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.accentSoft,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              onPressed: () => onTap(item),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSizes.l, AppSizes.s, AppSizes.s, AppSizes.s),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                maxLength: 300,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                style: AppTextStyles.body,
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  hintText: 'Спроси про экипировку…',
                  hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.l,
                    vertical: AppSizes.m,
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s),
            IconButton.filled(
              tooltip: 'Отправить',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.border,
              ),
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.arrow_upward, color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
