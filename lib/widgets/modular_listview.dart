import 'package:flutter/material.dart';
import 'package:aaram_bd/api_service.dart';

class ModularListView extends StatefulWidget {
  final ApiService apiService;
  final String sortBy;
  final int pageSize;
  final int resetTrigger;
  final int? catId;
  final Widget Function(BuildContext, dynamic) itemBuilder;

  const ModularListView({
    required this.apiService,
    required this.sortBy,
    required this.pageSize,
    required this.itemBuilder,
    this.resetTrigger = 0,
    this.catId,
    Key? key,
  }) : super(key: key);

  @override
  _ModularListViewState createState() => _ModularListViewState();
}

class _ModularListViewState extends State<ModularListView> {
  List<dynamic> _posts = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMoreData = true;
  late ScrollController _scrollController;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _fetchPosts();
  }

  @override
  void didUpdateWidget(ModularListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetTrigger != oldWidget.resetTrigger ||
        widget.catId != oldWidget.catId ||
        widget.sortBy != oldWidget.sortBy) {
      _posts.clear();
      _page = 1;
      _hasMoreData = true;
      _initialLoadDone = false;
      _fetchPosts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    if (_isLoading || !_hasMoreData || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final newPosts = await widget.apiService.fetchPosts(
        page: _page,
        pageSize: widget.pageSize,
        sortBy: widget.sortBy,
        catId: widget.catId?.toString(),
        context: context,
      );

      if (!mounted) return;

      setState(() {
        _posts.addAll(newPosts);
        _hasMoreData = newPosts.length == widget.pageSize;
        _page++;
        _initialLoadDone = true;
      });
    } catch (e) {
      debugPrint("Error in fetchPosts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _fetchPosts();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _page = 1;
      _hasMoreData = true;
      _initialLoadDone = false;
    });
    await _fetchPosts();
  }

  Widget _buildNoDataFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: _NoDataInteractive(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoadDone && _posts.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF1A56DB),
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_buildNoDataFound()],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1A56DB),
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB))),
            );
          }
          return widget.itemBuilder(context, _posts[index]);
        },
      ),
    );
  }
}

class _NoDataInteractive extends StatefulWidget {
  @override
  __NoDataInteractiveState createState() => __NoDataInteractiveState();
}

class __NoDataInteractiveState extends State<_NoDataInteractive>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _shakeText = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _shakeText = true);
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() => _shakeText = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child:
                Icon(Icons.inbox_outlined, size: 80, color: Color(0xFF1A56DB)),
          ),
          const SizedBox(height: 20),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _shakeText ? Colors.redAccent : Colors.black87,
            ),
            child: const Text('No posts found'),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your filters or check back later.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
