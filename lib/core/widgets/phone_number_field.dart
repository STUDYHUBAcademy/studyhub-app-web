import 'package:flutter/material.dart';

const _countryCodes = {'966': '🇸🇦', '20': '🇪🇬'};

/// A phone number input with an explicit country-code picker (Saudi/Egypt),
/// since guessing the country from a locally-formatted "0..." number is
/// unreliable — both countries share that leading-zero format. Reports the
/// composed international number (country code + local digits, no leading
/// zero, no "+") via [onChanged], or null while the local number is empty.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.onChanged,
    this.label = 'رقم الواتساب',
    this.initialCountryCode = '966',
  });

  final ValueChanged<String?> onChanged;
  final String label;
  final String initialCountryCode;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late String _countryCode = widget.initialCountryCode;
  final _numberController = TextEditingController();

  void _notify() {
    final digits = _numberController.text.replaceAll(RegExp(r'[^\d]'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    widget.onChanged(local.isEmpty ? null : '$_countryCode$local');
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: DropdownButtonFormField<String>(
            initialValue: _countryCode,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: _countryCodes.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      '${e.value} +${e.key}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _countryCode = v ?? _countryCode);
              _notify();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: widget.label),
            onChanged: (_) => _notify(),
          ),
        ),
      ],
    );
  }
}
