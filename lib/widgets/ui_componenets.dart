import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

/// Collection of reusable UI components for the app

/// Custom dropdown selector widget
class SelectDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Function(String?) onChanged;
  final bool isRequired;
  final String? errorText;

  const SelectDropdown({Key? key, required this.label, required this.value, required this.items, required this.onChanged, this.isRequired = false, this.errorText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Row(children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)), if (isRequired) const Text(' *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red))]),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(border: Border.all(color: errorText != null ? Colors.red : Colors.grey.shade300, width: errorText != null ? 2 : 1), borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                style: const TextStyle(fontSize: 16, color: AppTheme.primaryColor),
                onChanged: onChanged,
                items:
                    items.map<DropdownMenuItem<String>>((String item) {
                      return DropdownMenuItem<String>(value: item, child: Text(item));
                    }).toList(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[const SizedBox(height: 4), Text(errorText!, style: const TextStyle(fontSize: 12, color: Colors.red))],
      ],
    );
  }
}

/// Custom text field with label and validation
class LabeledTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool isRequired;
  final String? errorText;
  final int? maxLines;
  final int? maxLength;
  final Function(String)? onChanged;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  const LabeledTextField({
    Key? key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.isRequired = false,
    this.errorText,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Row(children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)), if (isRequired) const Text(' *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red))]),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            errorText: errorText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 2)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 2)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

/// Stats card for displaying stats with icon, value and label
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({Key? key, required this.title, required this.value, required this.icon, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 24, color: color)),
                const Spacer(),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

/// List item card with leading icon and action buttons
class ActionListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final VoidCallback? onActionPressed;
  final String? actionButtonLabel;
  final IconData? actionButtonIcon;
  final Color? actionButtonColor;

  const ActionListItem({Key? key, required this.title, this.subtitle, required this.icon, this.iconColor = AppTheme.primaryColor, this.onTap, this.onActionPressed, this.actionButtonLabel, this.actionButtonIcon, this.actionButtonColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 24, color: iconColor)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600))],
                  ],
                ),
              ),
              if (onActionPressed != null && actionButtonLabel != null) ...[
                OutlinedButton.icon(
                  onPressed: onActionPressed,
                  icon: Icon(actionButtonIcon ?? Icons.arrow_forward, size: 16),
                  label: Text(actionButtonLabel!),
                  style: OutlinedButton.styleFrom(foregroundColor: actionButtonColor ?? AppTheme.primaryColor, side: BorderSide(color: actionButtonColor ?? AppTheme.primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge for various statuses in the app
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool isOutlined;

  const StatusBadge({Key? key, required this.text, required this.color, this.icon, this.isOutlined = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isOutlined ? Colors.transparent : color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(isOutlined ? 1.0 : 0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// Section header with title and optional action button
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const SectionHeader({Key? key, required this.title, this.onActionPressed, this.actionLabel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: 40, height: 3, color: AppTheme.primaryColor)]),
        if (onActionPressed != null && actionLabel != null)
          TextButton(onPressed: onActionPressed, child: Row(children: [Text(actionLabel!, style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)), const SizedBox(width: 4), const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primaryColor)])),
      ],
    );
  }
}

/// Loading overlay for showing loading state with custom message
class LoadingOverlay extends StatelessWidget {
  final String message;

  const LoadingOverlay({Key? key, this.message = 'Loading...'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.5),
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))])),
        ),
      ),
    );
  }
}
