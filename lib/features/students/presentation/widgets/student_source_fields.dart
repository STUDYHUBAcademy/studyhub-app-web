import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../marketers/domain/entities/marketer.dart';
import '../../../marketers/presentation/providers/marketers_providers.dart';

const studentSourceLabels = {
  'direct': 'مباشر',
  'haraj': 'حراج',
  'marketer': 'مسوق',
};

/// Captures how a student found the academy, and — for a marketer
/// referral — which marketer and their negotiated commission (a flat
/// amount, not a percentage). Manages its own controllers so it can be
/// dropped into any dialog's field list without the parent tracking extra
/// TextEditingControllers. Pass the `initial*` params to pre-fill when
/// editing an existing student/enrollment/session.
class StudentSourceFields extends ConsumerStatefulWidget {
  const StudentSourceFields({
    super.key,
    required this.onChanged,
    this.initialSource = 'direct',
    this.initialMarketerName,
    this.initialCommissionPct,
    this.initialCommissionAmount,
  });

  /// Called whenever the source/marketer/commission changes. commissionPct
  /// is auto-1 for 'haraj', always null for 'marketer'. commissionAmount is
  /// whatever's typed for 'marketer', always null otherwise.
  final void Function(
    String source,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  )
  onChanged;

  final String initialSource;
  final String? initialMarketerName;
  final double? initialCommissionPct;
  final double? initialCommissionAmount;

  @override
  ConsumerState<StudentSourceFields> createState() =>
      _StudentSourceFieldsState();
}

class _StudentSourceFieldsState extends ConsumerState<StudentSourceFields> {
  late String _source = widget.initialSource;
  late final _marketerNameController = TextEditingController(
    text: widget.initialMarketerName ?? '',
  );
  late final _amountController = TextEditingController(
    text: widget.initialCommissionAmount != null
        ? _fmtAmount(widget.initialCommissionAmount!)
        : '',
  );

  static String _fmtAmount(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    // Report the initial value immediately so an edit dialog can save
    // even if the owner never touches this field.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _marketerNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      _source,
      _source == 'marketer' ? _marketerNameController.text.trim() : null,
      _source == 'haraj' ? 1 : null,
      _source == 'marketer' ? double.tryParse(_amountController.text) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketers = ref.watch(marketersProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _source,
          decoration: const InputDecoration(labelText: 'مصدر الطالب'),
          items: studentSourceLabels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            setState(() => _source = v ?? 'direct');
            _emit();
          },
        ),
        if (_source == 'marketer') ...[
          const SizedBox(height: 12),
          Autocomplete<Marketer>(
            displayStringForOption: (m) => m.name,
            initialValue: TextEditingValue(text: _marketerNameController.text),
            optionsBuilder: (value) {
              if (value.text.isEmpty) return marketers;
              final q = value.text.toLowerCase();
              return marketers.where((m) => m.name.toLowerCase().contains(q));
            },
            onSelected: (m) {
              _marketerNameController.text = m.name;
              if (m.defaultCommissionAmount != null) {
                _amountController.text = _fmtAmount(m.defaultCommissionAmount!);
              }
              _emit();
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              controller.text = _marketerNameController.text;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'اسم المسوق (بحث أو اسم جديد)',
                ),
                onChanged: (v) {
                  _marketerNameController.text = v;
                  _emit();
                },
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'عمولة المسوق (مبلغ)'),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}
