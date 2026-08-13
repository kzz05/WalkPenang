import 'package:flutter/material.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/theme/discovery_colors.dart';

/// Screen 02 — "Filter by category".
///
/// The mockup shows category checkboxes only; the sections below it cover the
/// dietary, price and distance rules T-FD01.2 also calls for. Edits happen on
/// a draft copy, so dismissing the sheet really cancels.
class CategoryFilterSheet extends StatefulWidget {
  const CategoryFilterSheet({super.key, required this.initial});

  final SearchFilters initial;

  /// Returns the edited filters, or null if the user dismissed the sheet.
  static Future<SearchFilters?> show(
      BuildContext context,
      SearchFilters initial,
      ) {
    return showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          CategoryFilterSheet(initial: initial),
    );
  }

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  late SearchFilters _draft = widget.initial;
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Filter by category',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DiscoveryColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose one or more categories to narrow results.',
                style: text.bodySmall?.copyWith(color: DiscoveryColors.inkMuted),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ...PlaceCategory.values.map(_buildCategoryRow),
                      const SizedBox(height: 8),
                      _buildOpenNowRow(),
                      const SizedBox(height: 8),
                      _buildAdvancedToggle(text),
                      if (_showAdvanced) ...<Widget>[
                        const SizedBox(height: 8),
                        _buildDietary(text),
                        const SizedBox(height: 20),
                        _buildPrice(text),
                        const SizedBox(height: 12),
                        _buildDistance(text),
                        const SizedBox(height: 20),
                        _buildSort(text),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(
                            () => _draft = SearchFilters(keyword: _draft.keyword),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: DiscoveryColors.ink,
                        side: const BorderSide(color: DiscoveryColors.creamDeep),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const Text('Apply filters'),
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

  Widget _buildCategoryRow(PlaceCategory category) {
    final bool selected = _draft.categories.contains(category);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? DiscoveryColors.creamDeep : DiscoveryColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (bool? value) {
          final Set<PlaceCategory> next =
          Set<PlaceCategory>.of(_draft.categories);
          if (value ?? false) {
            next.add(category);
          } else {
            next.remove(category);
          }
          setState(() => _draft = _draft.copyWith(categories: next));
        },
        title: Text(
          category.sheetLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: DiscoveryColors.ink,
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: DiscoveryColors.tan,
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildOpenNowRow() {
    return SwitchListTile(
      value: _draft.openNowOnly,
      onChanged: (bool value) =>
          setState(() => _draft = _draft.copyWith(openNowOnly: value)),
      title: const Text(
        'Open now only',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: DiscoveryColors.ink,
        ),
      ),
      activeThumbColor: DiscoveryColors.tan,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildAdvancedToggle(TextTheme text) {
    return TextButton.icon(
      onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
      style: TextButton.styleFrom(
        foregroundColor: DiscoveryColors.tanDark,
        padding: EdgeInsets.zero,
      ),
      icon: Icon(
        _showAdvanced ? Icons.expand_less : Icons.expand_more,
        size: 20,
      ),
      label: Text(_showAdvanced ? 'Fewer options' : 'More options'),
    );
  }

  Widget _buildDietary(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Dietary', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DietaryPreference.values.map((DietaryPreference d) {
            return FilterChip(
              label: Text(d.label),
              selected: _draft.dietary.contains(d),
              showCheckmark: false,
              onSelected: (bool selected) {
                final Set<DietaryPreference> next =
                Set<DietaryPreference>.of(_draft.dietary);
                if (selected) {
                  next.add(d);
                } else {
                  next.remove(d);
                }
                setState(() => _draft = _draft.copyWith(dietary: next));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrice(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Price', style: text.titleSmall),
        RangeSlider(
          values: RangeValues(
            _draft.minPriceLevel.value.toDouble(),
            _draft.maxPriceLevel.value.toDouble(),
          ),
          min: 1,
          max: 3,
          divisions: 2,
          activeColor: DiscoveryColors.tan,
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
      ],
    );
  }

  Widget _buildDistance(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Within ${_draft.maxDistanceKm.toStringAsFixed(0)} km',
          style: text.titleSmall,
        ),
        Slider(
          value: _draft.maxDistanceKm,
          min: 1,
          max: kMaxDistanceKm,
          divisions: 24,
          activeColor: DiscoveryColors.tan,
          label: '${_draft.maxDistanceKm.toStringAsFixed(0)} km',
          onChanged: (double value) =>
              setState(() => _draft = _draft.copyWith(maxDistanceKm: value)),
        ),
      ],
    );
  }

  Widget _buildSort(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Sort by', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SortOption.values.map((SortOption option) {
            return ChoiceChip(
              label: Text(option.label),
              selected: _draft.sortBy == option,
              showCheckmark: false,
              onSelected: (_) =>
                  setState(() => _draft = _draft.copyWith(sortBy: option)),
            );
          }).toList(),
        ),
      ],
    );
  }

  PriceLevel _levelFrom(double value) {
    return PriceLevel.values.firstWhere(
          (PriceLevel level) => level.value == value.round(),
      orElse: () => PriceLevel.budget,
    );
  }
}
