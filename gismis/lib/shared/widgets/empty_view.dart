import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// A friendly empty state view with guidance.
/// Displays when no content exists with helpful suggestions.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.action,
    this.actionLabel,
  });

  /// Creates an empty view for search results.
  factory EmptyView.search({
    String? query,
    Key? key,
  }) {
    return EmptyView(
      key: key,
      title: '未找到结果',
      message: query != null ? '没有找到与"$query"相关的内容' : '尝试使用其他关键词搜索',
      icon: Icons.search_rounded,
    );
  }

  /// Creates an empty view for favorites.
  factory EmptyView.favorites({
    VoidCallback? onExplore,
    Key? key,
  }) {
    return EmptyView(
      key: key,
      title: '还没有收藏',
      message: '浏览番剧并点击收藏按钮，将喜欢的番剧添加到这里',
      icon: Icons.favorite_border_rounded,
      action: onExplore,
      actionLabel: '去发现',
    );
  }

  /// Creates an empty view for follows.
  factory EmptyView.follows({
    VoidCallback? onExplore,
    Key? key,
  }) {
    return EmptyView(
      key: key,
      title: '还没有追番',
      message: '关注你喜欢的番剧，追踪更新进度',
      icon: Icons.bookmark_border_rounded,
      action: onExplore,
      actionLabel: '去发现',
    );
  }

  /// Creates an empty view for schedule.
  factory EmptyView.schedule({
    Key? key,
  }) {
    return EmptyView(
      key: key,
      title: '今日无更新',
      message: '这一天没有番剧更新，去看看其他日期吧',
      icon: Icons.calendar_today_rounded,
    );
  }

  /// Creates an empty view for AI conversation.
  factory EmptyView.conversation({
    Key? key,
  }) {
    return EmptyView(
      key: key,
      title: '开始对话',
      message: '选择一个热门问题或输入你想了解的内容',
      icon: Icons.chat_bubble_outline_rounded,
    );
  }

  final String? title;
  final String? message;
  final IconData? icon;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            AppSpacing.verticalLg,

            // Title
            if (title != null)
              Text(
                title!,
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

            if (title != null && message != null) AppSpacing.verticalSm,

            // Message
            if (message != null)
              Text(
                message!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),

            // Action button
            if (action != null && actionLabel != null) ...[
              AppSpacing.verticalLg,
              ElevatedButton(
                onPressed: action,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact inline empty state for smaller spaces.
class InlineEmpty extends StatelessWidget {
  const InlineEmpty({
    required this.message,
    super.key,
    this.icon,
  });

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.inbox_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
          AppSpacing.horizontalSm,
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
