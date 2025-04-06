import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final String? prefixText;
  final bool autofocus;
  final EdgeInsetsGeometry? contentPadding;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  const FormInputField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.suffixIcon,
    this.prefixText,
    this.autofocus = false,
    this.contentPadding,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: labelText, hintText: hintText, prefixText: prefixText, suffixIcon: suffixIcon, border: const OutlineInputBorder(), contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      focusNode: focusNode,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 16),
    );
  }
}
