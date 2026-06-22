import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../services/torrent_search_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/skeleton.dart';
import '../widgets/toast.dart';
import 'torrent_detail_screen.dart';

enum _Mode { local, online }
enum _OnlineState { idle, searching, results, empty, error }

class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    if (_timer?.isActive ?? false) _timer!.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _debouncer = Debouncer(milliseconds: 500);
  _Mode _mode = _Mode.local;

  List<dynamic> _allTorrents = [];
  bool _localLoaded = false;

  _OnlineState _onlineState = _OnlineState.idle;
  List<Map<String, dynamic>> _results = [];
  int _lastPage = 1;
  bool _isLoadingMore = false;
  final _scrollCtrl = ScrollController();

  static const _suggestions = ['FC2-PPV', 'HEYZO', 'LUXU', 'MIUM', '200GANA', 'SIRO', 'SGKI', 'BEAF', 'HMDNV', '10 bit', '4K', 'VR'];

  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _scrollCtrl.addListener(_onScroll);
    _loadLocal();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focusNode.dispose();
    _shimmerCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_onlineState != _OnlineState.results || _isLoadingMore) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadLocal() async {
    try {
      final list = await QBitApi().getTorrents();
      if (!mounted) return;
      setState(() { _allTorrents = list; _localLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _localLoaded = true);
    }
  }

  List<dynamic> get _localResults {
    final q = _queryCtrl.text.trim().toLowerCase();
    final list = _allTorrents.where((t) {
      if (t is! Map) return false;
      if (q.isEmpty) return true;
      return (t['name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) =>
        ((b['added_on'] ?? 0) as int).compareTo((a['added_on'] ?? 0) as int));
    return list;
  }

  Future<void> _runOnlineSearch(String pattern) async {
    if (pattern.trim().isEmpty) {
      setState(() => _onlineState = _OnlineState.idle);
      return;
    }
    setState(() {
      _onlineState = _OnlineState.searching;
      _results = [];
      _lastPage = 1;
    });
    try {
      final items = await TorrentSearchService.instance.search(pattern.trim(), pages: 10, startPage: 1);
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() => _onlineState = _OnlineState.empty);
      } else {
        setState(() {
          _results = items.map(_toResultMap).toList();
          _lastPage = 10;
          _onlineState = _OnlineState.results;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _onlineState = _OnlineState.error);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final start = _lastPage + 1;
    try {
      final items = await TorrentSearchService.instance.search(
        _queryCtrl.text.trim(), pages: 15, startPage: start,
      );
      if (!mounted) return;
      final seen = _results.map((r) => r['fileUrl'] as String).toSet();
      for (final item in items) {
        if (!seen.contains(item.magnet)) {
          _results.add(_toResultMap(item));
        }
      }
      setState(() {
        _isLoadingMore = false;
        _lastPage = start + 15 - 1;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Map<String, dynamic> _toResultMap(ScrapedTorrent item) => {
    'fileName': item.title,
    'fileUrl': item.magnet,
    'code': item.code,
    'thumbnail': item.thumbnail ?? '',
    'sizeStr': item.size,
    'date': item.date,
    'pageUrl': item.pageUrl,
  };

  Future<void> _addMagnet(String url) async {
    if (url.isEmpty) { _toast('没有可用的下载链接', ok: false); return; }
    HapticFeedback.mediumImpact();
    final err = await QBitApi().addMagnet(url);
    if (!mounted) return;
    _toast(err ?? '已添加到下载队列', ok: err == null);
  }

  void _toast(String msg, {required bool ok}) =>
      Toast.show(context, msg, type: ok ? ToastType.success : ToastType.error);

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(child: _mode == _Mode.local ? _buildLocal() : _buildOnline()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Expanded(child: Text('发现', style: AppTypography.largeTitle())),
          CupertinoSlidingSegmentedControl<_Mode>(
            groupValue: _mode,
            children: {
              _Mode.local: _segLabel('本地'),
              _Mode.online: _segLabel('141PPV'),
            },
            onValueChanged: (v) {
              if (v == null) return;
              setState(() => _mode = v);
              if (v == _Mode.local) _loadLocal();
            },
          ),
        ],
      ),
    );
  }

  Widget _segLabel(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(t, style: AppTypography.body().copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: CupertinoSearchTextField(
        controller: _queryCtrl,
        focusNode: _focusNode,
        placeholder: _mode == _Mode.local ? '搜索我的任务' : '搜索番号或名称…',
        style: AppTypography.body(),
        placeholderStyle: AppTypography.body(color: AppColors.of(AppColors.tertiaryLabel)),
        backgroundColor: AppColors.of(AppColors.card),
        onChanged: (text) {
          if (_mode == _Mode.local) {
            setState(() {});
          } else {
            _debouncer.run(() => _runOnlineSearch(text));
          }
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  Local
  // ──────────────────────────────────────────────────────

  Widget _buildLocal() {
    if (!_localLoaded) {
      return _buildLocalSkeleton();
    }
    final list = _localResults;
    if (list.isEmpty) {
      return _emptyHint(
        _queryCtrl.text.trim().isEmpty ? '暂无任务' : '没有匹配「${_queryCtrl.text.trim()}」的任务',
      );
    }
    return CupertinoListSection.insetGrouped(
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: list.map((t) {
        final tt = t as Map;
        final info = _stateInfo((tt['state'] ?? '').toString());
        final progress = ((tt['progress'] ?? 0.0) as num).toDouble();
        return CupertinoListTile.notched(
          leading: Icon(info.icon, color: info.color, size: 22),
          title: Text(
            (tt['name'] ?? '').toString(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTypography.body().copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Row(
            children: [
              Text(_fmtSize((tt['total_size'] ?? 0) as num), style: AppTypography.caption()),
              const Text('  ·  ', style: TextStyle(color: AppColors.tertiaryLabel)),
              Text('${(progress * 100).toStringAsFixed(1)}%', style: AppTypography.caption()),
            ],
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () async {
            await Get.to(() => TorrentDetailScreen(torrent: Map<String, dynamic>.from(tt)));
            _loadLocal();
          },
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────────────────
  //  Online
  // ──────────────────────────────────────────────────────

  Widget _buildOnline() {
    switch (_onlineState) {
      case _OnlineState.idle:
        return _buildOnlineIdle();
      case _OnlineState.searching:
        return _buildOnlineSearching();
      case _OnlineState.results:
        return _buildOnlineResults();
      case _OnlineState.empty:
        return _emptyHint('未找到相关结果', icon: CupertinoIcons.search);
      case _OnlineState.error:
        return _emptyHint('网络请求失败', icon: CupertinoIcons.wifi_exclamationmark);
    }
  }

  Widget _buildOnlineIdle() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.flame, size: 18, color: AppColors.warning),
            const SizedBox(width: 6),
            Text('热门搜索', style: AppTypography.sectionHeader()),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _suggestions.map((s) => GestureDetector(
            onTap: () {
              _queryCtrl.text = s;
              _queryCtrl.selection = TextSelection.fromPosition(TextPosition(offset: s.length));
              _runOnlineSearch(s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.of(AppColors.card),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.of(AppColors.separator)),
              ),
              child: Text(s, style: AppTypography.body().copyWith(fontSize: 14)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Icon(CupertinoIcons.info, size: 16, color: AppColors.of(AppColors.tertiaryLabel)),
            const SizedBox(width: 6),
            Text('输入关键字自动匹配 141PPV', style: AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel))),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlineSearching() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const CupertinoActivityIndicator(radius: 7),
                const SizedBox(width: 8),
                Text('搜索中…', style: AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel))),
              ],
            ),
          ),
        ),
        _buildGridSkeleton(),
      ],
    );
  }

  Widget _buildOnlineResults() {
    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _SliverResultCount(
          count: _results.length,
          query: _queryCtrl.text.trim(),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCard(_results[index], index),
              childCount: _results.length,
            ),
          ),
        ),
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          )
        else
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Center(
                child: Text('继续上滑加载更多', style: TextStyle(color: AppColors.tertiaryLabel, fontSize: 13)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(Map r, int index) {
    final code = (r['code'] ?? '').toString();
    final sizeStr = (r['sizeStr'] ?? '').toString();
    final thumb = (r['thumbnail'] ?? '').toString();
    final date = (r['date'] ?? '').toString();

    return CupertinoContextMenu(
      actions: [
        CupertinoContextMenuAction(
          onPressed: () { Navigator.pop(context); _addMagnet(r['fileUrl']); },
          trailingIcon: CupertinoIcons.arrow_down_circle,
          isDefaultAction: true,
          child: const Text('添加到队列'),
        ),
        CupertinoContextMenuAction(
          onPressed: () { Navigator.pop(context); _showDetailSheet(r); },
          trailingIcon: CupertinoIcons.info_circle,
          child: const Text('查看详情'),
        ),
        CupertinoContextMenuAction(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: r['fileUrl']));
            Navigator.pop(context);
            _toast('磁力已复制', ok: true);
          },
          trailingIcon: CupertinoIcons.doc_on_doc,
          child: const Text('复制磁力'),
        ),
      ],
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 350 + index * 30),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        ),
        child: GestureDetector(
          onTap: () => _showDetailSheet(r),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.of(AppColors.card),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover
                if (thumb.isNotEmpty)
                  Image.network(thumb, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackCover(),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return _shimmerPlaceholder();
                    },
                  )
                else
                  _fallbackCover(),

                // Gradient overlay (bottom-to-top)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: 100,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),

                // Info
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          code.isNotEmpty ? code : '未知',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.w700, letterSpacing: 0.3,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sizeStr,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

                // Size badge (top-right)
                if (date.isNotEmpty)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        date.length >= 10 ? date.substring(0, 10) : date,
                        style: const TextStyle(color: Colors.white70, fontSize: 9),
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

  void _showDetailSheet(Map r) {
    final code = (r['code'] ?? '').toString();
    final sizeStr = (r['sizeStr'] ?? '').toString();
    final thumb = (r['thumbnail'] ?? '').toString();
    final date = (r['date'] ?? '').toString();
    final title = (r['fileName'] ?? '').toString();
    final magnet = (r['fileUrl'] ?? '').toString();
    final pageUrl = (r['pageUrl'] ?? '').toString();

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoPageScaffold(
        backgroundColor: AppColors.of(AppColors.groupedBg),
        navigationBar: CupertinoNavigationBar(
          middle: Text(code, style: const TextStyle(fontSize: 16)),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.arrow_down_circle, size: 22),
            onPressed: () {
              Navigator.pop(ctx);
              _addMagnet(magnet);
            },
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Hero image
                if (thumb.isNotEmpty)
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                    color: Colors.black,
                    child: GestureDetector(
                      onTap: () { Navigator.pop(ctx); _showFullImage(thumb); },
                      child: Image.network(thumb, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.white54, size: 48),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CupertinoActivityIndicator());
                        },
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(code, style: AppTypography.cardTitle()),
                      if (title.isNotEmpty && title != code) ...[
                        const SizedBox(height: 4),
                        Text(title, style: AppTypography.subtitle()),
                      ],
                      const SizedBox(height: 16),
                      _infoRow(CupertinoIcons.doc, '大小', sizeStr),
                      if (date.isNotEmpty) _infoRow(CupertinoIcons.calendar, '日期', date),
                      if (pageUrl.isNotEmpty) _infoRow(CupertinoIcons.link, '详情页', pageUrl),
                      const SizedBox(height: 24),
                      CupertinoButton.filled(
                        onPressed: magnet.isEmpty ? null : () { Navigator.pop(ctx); _addMagnet(magnet); },
                        child: const Text('添加到下载队列'),
                      ),
                      const SizedBox(height: 8),
                      CupertinoButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: magnet));
                          _toast('磁力已复制', ok: true);
                        },
                        child: const Text('复制磁力链接'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.of(AppColors.tertiaryLabel)),
          const SizedBox(width: 8),
          Text('$label  ', style: AppTypography.caption(color: AppColors.of(AppColors.tertiaryLabel))),
          Expanded(
            child: Text(value, style: AppTypography.body().copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String url) {
    if (url.isEmpty) return;
    Navigator.push(context, CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black,
          child: Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.white54, size: 64),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const CupertinoActivityIndicator();
                },
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _fallbackCover() => Container(
    color: AppColors.of(AppColors.separator),
    child: const Center(child: Icon(CupertinoIcons.film, color: AppColors.placeholder, size: 28)),
  );

  Widget _shimmerPlaceholder() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final t = (_shimmerCtrl.value * 2).clamp(0.0, 1.0);
        final progress = t > 1 ? 2 - t : t;
        return Container(
          color: Color.lerp(AppColors.skeletonBase, AppColors.skeletonHighlight, progress),
        );
      },
    );
  }

  Widget _buildGridSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Container(
            decoration: BoxDecoration(
              color: AppColors.of(AppColors.card),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const SkeletonBar(width: double.infinity, height: double.infinity),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildLocalSkeleton() {
    return CupertinoListSection.insetGrouped(
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: List.generate(6, (_) => const CupertinoListTile(
        leading: SkeletonBar(width: 22, height: 22, borderRadius: BorderRadius.all(Radius.circular(11))),
        title: SkeletonBar(width: 200, height: 14),
        subtitle: SkeletonBar(width: 100, height: 12),
        trailing: CupertinoListTileChevron(),
      )),
    );
  }

  String _fmtSize(num? bytes) {
    final b = (bytes ?? 0).toDouble();
    if (b < 0) return '未知';
    if (b == 0) return '0 B';
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(2)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(2)} MB';
    return '${(b / 1073741824).toStringAsFixed(2)} GB';
  }

  ({Color color, IconData icon}) _stateInfo(String state) {
    if (['downloading', 'metaDL', 'forcedDL', 'stalledDL'].contains(state)) {
      return (color: AppColors.accent, icon: CupertinoIcons.arrow_down_circle_fill);
    }
    if (['uploading', 'forcedUP', 'stalledUP'].contains(state)) {
      return (color: AppColors.success, icon: CupertinoIcons.arrow_up_circle_fill);
    }
    if (state.startsWith('paused') || state.startsWith('stopped')) {
      return (color: AppColors.of(AppColors.secondaryLabel), icon: CupertinoIcons.pause_circle_fill);
    }
    if (state.startsWith('checking')) {
      return (color: AppColors.warning, icon: CupertinoIcons.arrow_2_circlepath_circle_fill);
    }
    if (state == 'missingFiles' || state == 'error') {
      return (color: AppColors.danger, icon: CupertinoIcons.exclamationmark_triangle_fill);
    }
    return (color: AppColors.of(AppColors.tertiaryLabel), icon: CupertinoIcons.circle);
  }

  Widget _emptyHint(String text, {IconData icon = CupertinoIcons.tray}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.of(AppColors.placeholder)),
          const SizedBox(height: 16),
          Text(text, style: AppTypography.subtitle(color: AppColors.of(AppColors.tertiaryLabel))),
        ],
      ),
    );
  }
}

class _SliverResultCount extends StatelessWidget {
  final int count;
  final String query;
  const _SliverResultCount({required this.count, required this.query});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Text(
              '找到 $count 条「$query」的结果',
              style: AppTypography.caption(color: AppColors.of(AppColors.secondaryLabel)),
            ),
          ],
        ),
      ),
    );
  }
}
