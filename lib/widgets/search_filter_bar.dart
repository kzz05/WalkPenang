import 'dart:async';

import 'package:flutter/material.dart';

import 'package:walk_penang/models/place.dart';
import 'package:walk_penang/models/search_filters.dart';

/// Default category chips. Swap for whatever the backend returns.
const List<String> kDiscoveryCategories = <String>[
  'Halal',
  'Heritage',
  'Cafe',
  'Street Food',
  'Nature',
  'Museum',
  'Night Market',
];

/// T-FD01.1 — keyword field, category chips, and the entry point to the
/// advanced filter sheet.
///
/// Keyword changes are debounced so a search isn't fired on every keystroke.
/// Chip taps report immediately, since a tap is already a deliberate action.
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.onChanged,
    this.categories = kDiscoveryCategories,
    this.initialFilters = const SearchFilters(),
    this.hintText = 'Search food, cafes, heritage sites',
    this.debounceDuration = const Duration(milliseconds: 350),
  });

  final ValueChanged<SearchFilters> onChanged;
  final List<String> categories;
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

  void _onKeywordChanged(String value) {
    _emit(_filters.copyWith(keyword: value.trim()), debounced: true);
  }

  void _toggleCategory(String category, bool selected) {
    final Set<String> next = Set<String>.of(_filters.categories);
    if (selected) {
      next.add(category);
    } else {
      next.remove(category);
    }
    _emit(_filters.copyWith(categories: next));
  }

  void _clearAll() {
    _controller.clear();
    FocusScope.of(context).unfocus();
    _emit(const SearchFilters());
  }

  Future<void> _openFilterSheet() async {
    final SearchFilters? result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          _AdvancedFilterSheet(initial: _filters),
    );
    if (result != null) _emit(result);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int advancedCount = _filters.dietary.length +
        (_filters.maxDistanceKm < kMaxDistanceKm ? 1 : 0) +
        (_filters.minPriceLevel != PriceLevel.budget ||
            _filters.maxPriceLevel != PriceLevel.premium
            ? 1
            : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder:
                      (BuildContext context, TextEditingValue value, _) {
                    return TextField(
                      controller: _controller,
                      onChanged: _onKeywordChanged,
                      onSubmitted: (String text) {
                        _emit(_filters.copyWith(keyword: text.trim()));
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _controller.clear();
                            _emit(_filters.copyWith(keyword: ''));
                          },
                        ),
                        filled: true,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: advancedCount > 0,
                label: Text('$advancedCount'),
                child: IconButton.filledTonal(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune),
                  tooltip: 'More filters',
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final String category = widget.categories[index];
              final bool selected = _filters.categories.contains(category);
              return Center(
                child: FilterChip(
                  label: Text(category),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (bool value) => _toggleCategory(category, value),
                ),
              );
            },
          ),
        ),
        if (!_filters.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Clear filters (${_filters.activeCount})'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dietary, price and distance controls (T-FD01.2), edited on a draft copy so
/// Cancel really cancels.
class _AdvancedFilterSheet extends StatefulWidget {
  const _AdvancedFilterSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late SearchFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Refine results', style: text.titleLarge),
              const SizedBox(height: 20),

              Text('Dietary', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DietaryPreference.values.map((DietaryPreference d) {
                  return FilterChip(
                    label: Text(d.label),
                    selected: _draft.dietary.contains(d),
                    onSelected: (bool selected) {
                      final Set<DietaryPreference> next =
                      Set<DietaryPreference>.of(_draft.dietary);
                      selected ? next.add(d) : next.remove(d);
                      setState(() => _draft = _draft.copyWith(dietary: next));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Text('Price', style: text.titleSmall),
              const SizedBox(height: 8),
              RangeSlider(
                values: RangeValues(
                  _draft.minPriceLevel.value.toDouble(),
                  _draft.maxPriceLevel.value.toDouble(),
                ),
                min: 1,
                max: 3,
                divisions: 2,
                labels: RangeLabels(
                  _draft.minPriceLevel.label,
                  _draft.maxPriceLevel.label,
                ),
                onChanged: (RangeValues values) {
                  setState(() {
                    _draft = _draft.copyWith(
                      minPriceLevel: _levelFrom(values.start),
                      maxPriceLevel: _levelFrom(values.end),
                    );
                  });
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Within ${_draft.maxDistanceKm.toStringAsFixed(0)} km',
                style: text.titleSmall,
              ),
              Slider(
                value: _draft.maxDistanceKm,
                min: 1,
                max: kMaxDistanceKm,
                divisions: 24,
                label: '${_draft.maxDistanceKm.toStringAsFixed(0)} km',
                onChanged: (double value) {
                  setState(() => _draft = _draft.copyWith(maxDistanceKm: value));
                },
              ),
              const SizedBox(height: 16),

              Text('Sort by', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: SortOption.values.map((SortOption option) {
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: _draft.sortBy == option,
                    onSelected: (_) {
                      setState(() => _draft = _draft.copyWith(sortBy: option));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(
                            () => _draft = SearchFilters(keyword: _draft.keyword),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const Text('Show results'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PriceLevel _levelFrom(double value) {
    return PriceLevel.values.firstWhere(
          (PriceLevel level) => level.value == value.round(),
      orElse: () => PriceLevel.budget,
    );
  }
}
