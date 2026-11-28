import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/legal/legal_documents.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/main_tab.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';

/// Текст документа: соглашение, политика конфиденциальности или
/// правила для продавцов.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  /// Список документов — из профиля.
  static Future<void> showList(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final LegalDoc doc in LegalDoc.values)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(doc.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(AppRoutes.legal, arguments: doc);
                  },
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: doc.title,
      navTab: MainTab.profile,
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text('Редакция ${LegalDoc.version}', style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.m),
          for (final (String heading, List<String> paragraphs) in doc.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.m),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSizes.xs),
                    for (final String p in paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.xs),
                        child: Text(p, style: AppTextStyles.body.copyWith(height: 1.4)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
