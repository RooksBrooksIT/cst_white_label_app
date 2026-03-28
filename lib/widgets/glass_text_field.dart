import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool showPassword;
  final VoidCallback? onTogglePassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final FocusNode? focusNode;
  final FocusNode? node; // Alias for focusNode
  final bool readOnly;
  final String? hintText;
  final int? maxLines;
  final List<dynamic>? inputFormatters;

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
    this.node,
    this.readOnly = false,
    this.hintText,
    this.maxLines = 1,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !showPassword,
          keyboardType: keyboardType,
          onChanged: onChanged,
          focusNode: focusNode ?? node,
          readOnly: readOnly,
          maxLines: maxLines,
          inputFormatters: inputFormatters?.cast<TextInputFormatter>(),
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter your $label',
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 20,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
