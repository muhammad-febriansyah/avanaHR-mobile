import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/models/ess_models.dart';
import '../sosmed_view.dart' show hexColor;

/// One post on the wall: author, category chip, body, optional photo, and the
/// like / comment row.
class PostCard extends StatelessWidget {
  final SocialPostItem post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  /// Opens the action sheet: delete on your own post, report on anyone else's.
  final VoidCallback onMenu;

  /// Opens the detail screen — the whole card is a tap target for it.
  final VoidCallback onOpen;

  /// Set when the card shares its row with others: everything shrinks and the
  /// body is clamped, because a two-column card is roughly half as wide.
  final bool compact;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onMenu,
    required this.onOpen,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(),
                SizedBox(width: compact ? 8.w : 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (compact ? 12.5 : 13.5).sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        [
                          RelativeTime.format(post.createdAt),
                          if (post.edited) 'diedit',
                        ].where((part) => part.isNotEmpty).join(' · '),
                        style: TextStyle(
                          fontSize: (compact ? 10 : 11).sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (post.tagged.isNotEmpty)
                        Text(
                          'bersama ${post.tagged.map((p) => p.name).join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: (compact ? 10 : 11).sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onMenu,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Icon(
                      Iconsax.more,
                      size: 18.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),

            if (post.category != null) ...[
              SizedBox(height: 10.h),
              _categoryChip(),
            ],

            SizedBox(height: 10.h),
            Text(
              post.body,
              // Clamped in a lane so one long post cannot stretch its column
              // far past the others; the detail screen shows all of it.
              maxLines: compact ? 4 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontSize: (compact ? 12.5 : 13.5).sp,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),

            if (post.imageUrl != null) ...[
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  width: double.infinity,
                  height: (compact ? 120 : 190).h,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],

            SizedBox(height: 12.h),
            Row(
              children: [
                _action(
                  icon: post.liked ? Iconsax.heart5 : Iconsax.heart,
                  label: '${post.likesCount}',
                  color: post.liked
                      ? AppColors.destructive
                      : AppColors.textMuted,
                  onTap: onLike,
                ),
                SizedBox(width: compact ? 12.w : 18.w),
                _action(
                  icon: Iconsax.message_text,
                  label: '${post.commentsCount}',
                  color: AppColors.textMuted,
                  onTap: onComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip() {
    final accent = hexColor(post.categoryColor);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.w : 10.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99.r),
      ),
      child: Text(
        post.category!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: (compact ? 10 : 11).sp,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    if (post.authorPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99.r),
        child: CachedNetworkImage(
          imageUrl: post.authorPhoto!,
          width: (compact ? 30 : 38).w,
          height: (compact ? 30 : 38).w,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _initials(),
        ),
      );
    }

    return _initials();
  }

  Widget _initials() {
    return Container(
      width: (compact ? 30 : 38).w,
      height: (compact ? 30 : 38).w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        post.author.isEmpty ? '?' : post.author.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
