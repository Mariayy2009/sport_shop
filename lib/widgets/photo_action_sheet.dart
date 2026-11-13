import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/theme/app_text_styles.dart';

/// Что пользователь выбрал в меню фотографии.
enum PhotoAction { camera, gallery, delete }

/// Нижнее меню: «Сделать фото / Выбрать из галереи / Удалить».
class PhotoActionSheet extends StatelessWidget {
  const PhotoActionSheet({super.key, required this.title, required this.canDelete});

  final String title;
  final bool canDelete;

  static Future<PhotoAction?> show(
    BuildContext context, {
    required String title,
    bool canDelete = false,
  }) {
    return showModalBottomSheet<PhotoAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (_) => PhotoActionSheet(title: title, canDelete: canDelete),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.l, 0, AppSizes.l, AppSizes.s),
            child: Text(title, style: AppTextStyles.sectionTitle),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Сделать фото'),
            onTap: () => Navigator.of(context).pop(PhotoAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.of(context).pop(PhotoAction.gallery),
          ),
          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Удалить фото', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.of(context).pop(PhotoAction.delete),
            ),
          const SizedBox(height: AppSizes.s),
        ],
      ),
    );
  }
}
