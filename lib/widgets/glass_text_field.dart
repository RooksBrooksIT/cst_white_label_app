import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool showPassword;
  final VoidCallback? onTogglePassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  final Function(String)? onChanged;
  final FocusNode? focusNode;
  final bool readOnly;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.showPassword = false,
    this.onTogglePassword,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !showPassword,
      keyboardType: keyboardType,
      onChanged: onChanged,
      focusNode: focusNode,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: Responsive.fontSize(context, 15),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                ),
                onPressed: onTogglePassword,
              )
            : null,
      ),
      validator: validator,
    );
  }
}
