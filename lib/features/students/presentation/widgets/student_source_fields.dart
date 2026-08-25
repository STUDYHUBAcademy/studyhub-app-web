import 'package:flutter/material.dart';

const studentSourceLabels = {
  'direct': 'مباشر',
  'haraj': 'حراج',
  'marketer': 'مسوق',
};

/// Captures how a student found the academy, and — for a marketer
/// referral — their name and negotiated commission percentage. Manages its
/// own controllers so it can be dropped into any dialog's field list without
/// the parent tracking extra TextEditingControllers. Pass the `initial*`
/// params to pre-fill when editing an existing student.
class StudentSourceFields extends StatefulWidget {
  const StudentSourceFields({
    super.key,
    required this.onChanged,
    this.initialSource = 'direct',
    this.initialMarketerName,
    this.initialCommissionPct,
  });

  /// Called whenever the source/marketer/commission changes. commissionPct
  /// is auto-1 for 'haraj', whatever's typed for 'marketer', null for 'direct'.
  final void Function(
    String source,
    String? marketerName,
    double? commissionPct,
  )
  onChanged;

  final String initialSource;
  final String? initialMarketerName;
  final double? initialCommissionPct;

  @override
  State<StudentSourceFields> createState() => _StudentSourceFieldsState();
}

class _StudentSourceFieldsState extends State<StudentSourceFields> {
  late String _source = widget.initialSource;
  late final _marketerNameController = TextEditingController(
    text: widget.initialMarketerName ?? '',
  );
  late final _pctController = TextEditingController(
    text:
        widget.initialSource == 'marketer' &&
            widget.initialCommissionPct != null
        ? _fmtPct(widget.initialCommissionPct!)
        : '10',
  );

  static String _fmtPct(double v) =>
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
    _pctController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      _source,
      _source == 'marketer' ? _marketerNameController.text.trim() : null,
      _source == 'haraj'
          ? 1
          : (_source == 'marketer'
                ? double.tryParse(_pctController.text)
                : null),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          TextField(
            controller: _marketerNameController,
            decoration: const InputDecoration(labelText: 'اسم المسوق'),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pctController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'نسبة عمولة المسوق %'),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}
