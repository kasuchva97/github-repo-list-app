import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/error_messages.dart';
import '../../../core/widgets/status_view.dart';
import '../application/search_controller.dart';
import '../application/search_state.dart';
import 'widgets/repository_tile.dart';

/// Search tab: a search box and the result list with infinite scroll.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Restore the text if the screen is rebuilt while a query is active.
    _textController.text = ref.read(repositorySearchProvider).query;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  RepositorySearchController get _search =>
      ref.read(repositorySearchProvider.notifier);

  void _clear() {
    _textController.clear();
    _search.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Jump back to the top whenever a new query starts.
    ref.listen(repositorySearchProvider.select((s) => s.query), (prev, next) {
      if (prev != next && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    final state = ref.watch(repositorySearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _SearchField(
              controller: _textController,
              onChanged: _search.onQueryChanged,
              onSubmitted: _search.search,
              onClear: _clear,
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_viewKey(state)),
          child: _buildBody(state),
        ),
      ),
    );
  }

  String _viewKey(SearchState state) {
    if (state.isIdle) return 'home';
    if (state.isLoading) return 'loading';
    if (state.error != null) return 'error';
    if (state.isEmpty) return 'empty';
    return 'results';
  }

  Widget _buildBody(SearchState state) {
    if (state.isIdle) {
      return const StatusView(
        key: Key('search-home'),
        icon: Icons.travel_explore,
        title: 'Search GitHub repositories',
        message:
            'Type a keyword above, such as "flutter" or "riverpod", '
            'and tap the star to save repositories to your favorites.',
      );
    }
    if (state.isLoading) {
      return const Center(
        key: Key('search-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (state.error case final error?) {
      return StatusView(
        key: const Key('search-error'),
        icon: Icons.cloud_off,
        title: 'Could not load repositories',
        message: userMessageFor(error),
        action: FilledButton.icon(
          onPressed: _search.retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (state.isEmpty) {
      return StatusView(
        key: const Key('search-empty'),
        icon: Icons.search_off,
        title: 'No repositories found',
        message:
            'Nothing matches "${state.query}". '
            'Check the spelling or try a broader keyword.',
      );
    }
    return _ResultList(state: state, scrollController: _scrollController);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('search-field'),
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      maxLength: 256, // GitHub rejects longer search queries.
      decoration: InputDecoration(
        hintText: 'Search repositories',
        prefixIcon: const Icon(Icons.search),
        counterText: '',
        filled: true,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        // Rebuilds only the suffix when the text changes.
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

class _ResultList extends ConsumerWidget {
  const _ResultList({required this.state, required this.scrollController});

  final SearchState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(repositorySearchProvider.notifier);
    final items = state.items;

    return RefreshIndicator(
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await controller.refresh();
        } on Object catch (e) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(userMessageFor(e))));
        }
      },
      child: Scrollbar(
        controller: scrollController,
        child: ListView.separated(
          key: const Key('search-results'),
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            if (index < items.length) {
              return RepositoryTile(
                key: ValueKey(items[index].id),
                repository: items[index],
              );
            }
            return _ListFooter(state: state, controller: controller);
          },
        ),
      ),
    );
  }
}

/// Last row of the list: loads the next page, shows progress, a retry
/// button after a failure, or an end-of-results note.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.controller});

  final SearchState state;
  final RepositorySearchController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError case final error?) {
      return Padding(
        key: const Key('load-more-error'),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(userMessageFor(error), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.hasMore) {
      // Being built means the footer is within the list's cache extent,
      // i.e. the user is about to reach the end. This also covers a first
      // page too short to scroll, where scroll listeners would never fire.
      return _LoadMoreTrigger(
        // A new key per page guarantees the trigger fires once per page.
        key: ValueKey('load-more-${state.nextPage}'),
        onVisible: controller.loadMore,
      );
    }
    final theme = Theme.of(context);
    return Padding(
      key: const Key('end-of-results'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        '${state.items.length} of ${state.totalCount} repositories'
        '${state.totalCount > state.items.length ? ' (GitHub shows at most 1,000)' : ''}',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger({super.key, required this.onVisible});

  final VoidCallback onVisible;

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    // Providers must not be modified during build, so defer to after the
    // frame. The controller ignores the call if a load is already running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('load-more-indicator'),
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
