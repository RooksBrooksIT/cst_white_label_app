import 'package:flutter/material.dart';

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
  final String? hintText;

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
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !showPassword,
          keyboardType: keyboardType,
          onChanged: onChanged,
          focusNode: focusNode,
          readOnly: readOnly,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1E293B),
          ),
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
