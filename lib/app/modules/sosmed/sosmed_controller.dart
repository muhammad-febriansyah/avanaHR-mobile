import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../core/utils/image_compressor.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// The employee social wall: a paginated feed, posting, likes and comments.
///
/// Every list here comes from the server already scoped to the caller's tenant,
/// so nothing is filtered again on the client.
class SosmedController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final submitting = false.obs;
  final loadingCategories = false.obs;

  final posts = <SocialPostItem>[].obs;
  final categories = <SocialCategoryItem>[].obs;
  final leaders = <SocialLeaderItem>[].obs;

  /// null = "Semua"; otherwise the category being filtered on.
  final activeCategory = Rxn<int>();

  /// Why the last fetch failed, when it did. An empty wall and a wall that
  /// could not be loaded look identical otherwise, and telling somebody to be
  /// the first to post is the wrong thing to say when the server is down.
  final feedError = RxnString();
  final categoriesFailed = false.obs;

  /// How many cards sit side by side, one or two. Remembered across launches —
  /// a layout preference set once should not reset on every open.
  ///
  /// Three was tried and dropped: at a third of a phone's width the card's
  /// author line and category chip overflow.
  final columns = 2.obs;

  /// `latest` or `trending`.
  final sort = 'latest'.obs;
  final leaderRange = 'all'.obs;
  final loadingLeaders = false.obs;

  int _page = 1;
  bool _hasMore = true;

  static const _columnsKey = 'sosmed_columns';

  final GetStorage _box = GetStorage();

  @override
  void onInit() {
    super.onInit();
    // clamp, not just a default: anyone who already picked the old 3-column
    // layout would otherwise stay stuck on it.
    columns.value = ((_box.read(_columnsKey) as int?) ?? 2).clamp(1, 2);
    load();
  }

  void setColumns(int value) {
    columns.value = value.clamp(1, 2);
    _box.write(_columnsKey, columns.value);
  }

  Future<void> setSort(String value) async {
    if (sort.value == value) {
      return;
    }

    sort.value = value;
    await load();
  }

  Future<void> load() async {
    isLoading.value = true;
    _page = 1;
    _hasMore = true;

    // Each half keeps its own failure. Fetched together, one bad response used
    // to empty both, so a feed that would not load also left the composer with
    // no categories to pick from.
    await Future.wait([_loadCategories(), _loadFeed()]);

    isLoading.value = false;
  }

  /// The category list only changes when HR edits it, so it is fetched once and
  /// then left alone — except while it is empty, which is also what a failed
  /// fetch looks like, and is worth another try.
  Future<void> _loadCategories() async {
    if (categories.isNotEmpty) {
      return;
    }

    loadingCategories.value = true;

    try {
      categories.assignAll(await _api.socialCategories());
      categoriesFailed.value = false;
    } catch (_) {
      categories.clear();
      categoriesFailed.value = true;
    }

    loadingCategories.value = false;
  }

  Future<void> _loadFeed() async {
    try {
      final feed = await _api.socialFeed(
        page: 1,
        categoryId: activeCategory.value,
        sort: sort.value,
      );

      posts.assignAll(feed.items);
      _hasMore = feed.hasMore;
      feedError.value = null;
    } on DioException catch (e) {
      posts.clear();
      feedError.value = ApiClient.errorMessage(e);
    } catch (_) {
      posts.clear();
      feedError.value = 'Postingan gagal dimuat.';
    }
  }

  /// Next page, appended. No-op while one is already in flight or at the end.
  Future<void> loadMore() async {
    if (isLoadingMore.value || !_hasMore || isLoading.value) {
      return;
    }

    isLoadingMore.value = true;

    try {
      final feed = await _api.socialFeed(
        page: _page + 1,
        categoryId: activeCategory.value,
        sort: sort.value,
      );
      posts.addAll(feed.items);
      _page += 1;
      _hasMore = feed.hasMore;
    } catch (_) {
      // Keep what is already on screen; the user can pull to refresh.
    }

    isLoadingMore.value = false;
  }

  Future<void> filterBy(int? categoryId) async {
    if (activeCategory.value == categoryId) {
      return;
    }

    activeCategory.value = categoryId;
    await load();
  }

  Future<bool> createPost({
    required String body,
    int? categoryId,
    String? imagePath,
  }) async {
    submitting.value = true;

    try {
      // Shrink on the device: a raw camera shot easily exceeds the server's
      // 5 MB limit and would make the feed slow to scroll.
      final prepared = imagePath == null
          ? null
          : await ImageCompressor.compress(imagePath);

      final res = await _api.createSocialPost(
        body: body,
        categoryId: categoryId,
        imagePath: prepared,
      );
      submitting.value = false;

      if (res.statusCode == 201) {
        AppToast.success('Postingan terkirim');
        await load();
        return true;
      }

      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengirim postingan.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  /// Flip the heart straight away, then reconcile with what the server counted.
  /// A failed request rolls the optimistic change back.
  Future<void> toggleLike(SocialPostItem post) async {
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index < 0) {
      return;
    }

    final wasLiked = post.liked;
    final wasCount = post.likesCount;

    post.liked = !wasLiked;
    post.likesCount = wasLiked ? wasCount - 1 : wasCount + 1;
    posts.refresh();

    try {
      final result = await _api.toggleSocialLike(post.id);
      post.liked = result['liked'] == true;
      post.likesCount = (result['likes_count'] as num?)?.toInt() ?? wasCount;
      posts.refresh();
    } on DioException catch (e) {
      post.liked = wasLiked;
      post.likesCount = wasCount;
      posts.refresh();
      AppToast.error(ApiClient.errorMessage(e));
    }
  }

  Future<bool> deletePost(SocialPostItem post) async {
    try {
      await _api.deleteSocialPost(post.id);
      posts.removeWhere((p) => p.id == post.id);
      AppToast.success('Postingan dihapus');
      return true;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  /// Edit your own post. Likes and comments are untouched — the post keeps its
  /// id, so fixing a typo does not throw away the conversation under it.
  Future<SocialPostItem?> editPost({
    required SocialPostItem post,
    required String body,
    int? categoryId,
    String? imagePath,
    bool removeImage = false,
  }) async {
    submitting.value = true;

    try {
      final prepared = imagePath == null
          ? null
          : await ImageCompressor.compress(imagePath);

      final res = await _api.updateSocialPost(
        id: post.id,
        body: body,
        categoryId: categoryId,
        imagePath: prepared,
        removeImage: removeImage,
      );
      submitting.value = false;

      final updated = SocialPostItem.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map),
      );

      final index = posts.indexWhere((p) => p.id == post.id);
      if (index >= 0) {
        posts[index] = updated;
        posts.refresh();
      }

      AppToast.success('Postingan diperbarui');
      return updated;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return null;
    }
  }

  /// One post on its own, for the detail screen and notification deep links.
  Future<SocialPostItem?> fetchPost(int id) async {
    try {
      return await _api.socialPost(id);
    } catch (_) {
      return null;
    }
  }

  /// Flag a post for HR to review. Posts go live immediately, so this is how
  /// the wall polices itself between HR sweeps.
  Future<bool> reportPost(SocialPostItem post, String? reason) async {
    try {
      await _api.reportSocialPost(post.id, reason);
      AppToast.success('Laporan terkirim. Tim HR akan meninjau.');
      return true;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  Future<List<SocialCommentItem>> comments(int postId) async {
    try {
      return await _api.socialComments(postId);
    } catch (_) {
      return [];
    }
  }

  Future<SocialCommentItem?> addComment(
    SocialPostItem post,
    String body, {
    int? parentId,
  }) async {
    try {
      final res = await _api.createSocialComment(
        post.id,
        body,
        parentId: parentId,
      );
      post.commentsCount += 1;
      posts.refresh();

      return SocialCommentItem.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map),
      );
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return null;
    }
  }

  Future<bool> deleteComment(SocialPostItem post, int commentId) async {
    try {
      await _api.deleteSocialComment(commentId);
      if (post.commentsCount > 0) {
        post.commentsCount -= 1;
        posts.refresh();
      }
      return true;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  /// Whether the leaderboard is showing the full list rather than the top 20.
  final showAllLeaders = false.obs;

  Future<void> loadLeaderboard({String? range, bool? showAll}) async {
    if (range != null) {
      leaderRange.value = range;
    }

    if (showAll != null) {
      showAllLeaders.value = showAll;
    }

    loadingLeaders.value = true;

    try {
      leaders.assignAll(
        await _api.socialLeaderboard(
          range: leaderRange.value,
          limit: showAllLeaders.value ? 100 : 20,
        ),
      );
    } catch (_) {
      leaders.clear();
    }

    loadingLeaders.value = false;
  }
}
