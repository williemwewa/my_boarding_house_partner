import 'package:flutter/material.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

class CustomDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Function(String?) onChanged;
  final String? hint;
  final bool isRequired;
  final bool isEnabled;

  const CustomDropdown({Key? key, required this.label, required this.value, required this.items, required this.onChanged, this.hint, this.isRequired = false, this.isEnabled = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Row(children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)), if (isRequired) const Text(' *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red))]),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: isEnabled ? Colors.white : Colors.grey.shade100),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              hint: hint != null ? Text(hint!) : null,
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
              items:
                  items.map((String item) {
                    return DropdownMenuItem<String>(value: item, child: Text(item));
                  }).toList(),
              onChanged: isEnabled ? onChanged : null,
              style: const TextStyle(color: AppTheme.primaryColor, fontSize: 16),
              dropdownColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// A simple dropdown button with validation that can be used in forms
class FormDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;
  final String? hint;
  final bool isRequired;
  final bool isEnabled;

  const FormDropdown({Key? key, required this.label, required this.value, required this.items, required this.onChanged, this.validator, this.hint, this.isRequired = false, this.isEnabled = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Row(children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)), if (isRequired) const Text(' *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red))]),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items:
              items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
          onChanged: isEnabled ? onChanged : null,
          validator: validator,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 16),
          dropdownColor: Colors.white,
        ),
      ],
    );
  }
}
