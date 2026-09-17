import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/profile_form_fields.dart';
import 'wp_components.dart';

/// The height, weight and unit-system controls, shared by the sign-up profile
/// step and the edit-profile screen.
///
/// Both screens showed the identical block, and it now has to change shape
/// with the unit system — one centimetres box, or a feet box beside an inches
/// box. Keeping that in one widget means the two screens cannot disagree about
/// which fields exist.
class BodyMetricsFields extends StatelessWidget {
  final ProfileFormFields fields;

  const BodyMetricsFields({super.key, required this.fields});

  /// Digits plus a single decimal point. The boxes previously accepted any
  /// text at all and left the validator to sort it out afterwards.
  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  static const _decimalKeyboard =
      TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Keyed on the unit system so switching tears this block down instead
        // of recycling it. Both layouts open with
        // Row[Expanded(WpField), SizedBox, Expanded(WpField)], so without a key
        // Flutter matches by index and hands the metric height field's
        // FormFieldState to the imperial feet field — carrying over
        // _hasInteractedByUser and a stale value, which rendered an error under
        // a box whose contents were perfectly correct.
        KeyedSubtree(
          key: ValueKey(fields.unitSystem),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields.isImperial ? _imperial() : _metric(),
          ),
        ),
        const SizedBox(height: 20),
        WpDropdownField(
          label: 'system units',
          value: fields.units,
          options: const {
            'metric': 'Metric (kg, cm)',
            'imperial': 'Imperial (lb, ft/in)',
          },
          onChanged: fields.setUnits,
        ),
      ],
    );
  }

  List<Widget> _metric() => [
        // crossAxisAlignment.start is load-bearing: a wrapped error message
        // under one field must not shove the other one down.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: WpField(
                label: 'height (cm)',
                controller: fields.heightCtrl,
                keyboardType: _decimalKeyboard,
                inputFormatters: [_decimal],
                validator: fields.validateHeight,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: WpField(
                label: 'weight (kg)',
                controller: fields.weightCtrl,
                keyboardType: _decimalKeyboard,
                inputFormatters: [_decimal],
                validator: fields.validateWeight,
              ),
            ),
          ],
        ),
      ];

  /// Feet and inches share a row; weight then takes the full width of its own.
  /// Three boxes across would leave each about a third of a phone screen, too
  /// narrow for "Weight must be between 45–661 lb" to wrap into.
  List<Widget> _imperial() => [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: WpField(
                label: 'height (ft)',
                controller: fields.heightFeetCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: fields.validateHeightFeet,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: WpField(
                label: 'height (in)',
                controller: fields.heightInchesCtrl,
                keyboardType: _decimalKeyboard,
                inputFormatters: [_decimal],
                validator: fields.validateHeightInches,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        WpField(
          label: 'weight (lb)',
          controller: fields.weightCtrl,
          keyboardType: _decimalKeyboard,
          inputFormatters: [_decimal],
          validator: fields.validateWeight,
        ),
      ];
}
