import 'dart:async';

import 'package:flutter/material.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/views/widgets/category_filter_sheet.dart';

/// T-FD01.1 — keyword field plus the All/Food/Heritage/Nature chip row from
/// screen 01, and the entry point to the filter sheet (screen 02).
///
/// Keyword changes are debounced so a search isn't fired on every keystroke.
/// Chip taps report immediately, since a tap is already a deliberate action.
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.onChanged,
    this.initialFilters = const SearchFilters(),
    this.hintText = 'Search food and attractions...',
    this.debounceDuration = const Duration(milliseconds: 350),
  });

  final ValueChanged<SearchFilters> onChanged;
  final SearchFilters initialFilters;
  final String hintText;
  final Duration debounceDuration;

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late final TextEditingController _controller;
  late SearchFilters _filters;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _controller = TextEditingController(text: _filters.keyword);
  }

  @override
  void didUpdateWidget(SearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep in step when the parent changes filters (e.g. the empty state's
    // "Clear filters" button).
    if (widget.initialFilters != oldWidget.initialFilters &&
        widget.initialFilters != _filters) {
      _filters = widget.initialFilters;
      if (_controller.text != _filters.keyword) {
        _controller.text = _filters.keyword;
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _emit(SearchFilters next, {bool debounced = false}) {
    setState(() => _filters = next);
    _debounce?.cancel();
    if (debounced) {
      _debounce = Timer(widget.debounceDuration, () => widget.onChanged(next));
    } else {
      widget.onChanged(next);
    }
  }

  void _selectCategory(PlaceCategory? category) {
    // Null is the "All" chip — an empty set means no narrowing.
    _emit(
      _filters.copyWith(
        categories: category == null
            ? <PlaceCategory>{}
            : <PlaceCategory>{category},
      ),
    );
  }

  Future<void> _openSheet() async {
    final SearchFilters? result =
    await CategoryFilterSheet.show(context, _filters);
    if (result != null) _emit(result);
  }

  @override
  Widget build(BuildContext context) {
    // The chip row shows the first three categories, as in the mockup; the
    // rest live in the sheet.
    const List<PlaceCategory> chipCategories = <PlaceCategory>[
      PlaceCategory.food,
      PlaceCategory.heritage,
      PlaceCategory.nature,
    ];
    final int sheetOnlyCount = _filters.activeCount -
        (_filters.keyword.isEmpty ? 0 : 1) -
        _filters.categories.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    return TextField(
                      controller: _controller,
                      onChanged: (String text) => _emit(
                        _filters.copyWith(keyword: text.trim()),
                        debounced: true,
                      ),
                      onSubmitted: (String text) =>
                          _emit(_filters.copyWith(keyword: text.trim())),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.muted,
                        ),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _controller.clear();
                            _emit(_filters.copyWith(keyword: ''));
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: sheetOnlyCount > 0,
                backgroundColor: AppColors.primaryDeep,
                label: Text('$sheetOnlyCount'),
                child: Material(
                  color: AppColors.card,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _openSheet,
                    icon: const Icon(Icons.tune, size: 20),
                    color: AppColors.onPrimary,
                    tooltip: 'Filter by category',
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              _Chip(
                label: 'All',
                selected: _filters.categories.isEmpty,
                onTap: () => _selectCategory(null),
              ),
              ...chipCategories.map((PlaceCategory category) {
                return _Chip(
                  label: category.chipLabel,
                  selected: _filters.categories.contains(category),
                  onTap: () => _selectCategory(category),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
