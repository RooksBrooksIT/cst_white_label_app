import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassTextField extends StatefulWidget {
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
  final bool enabled;
  final String? hintText;
  final int? maxLines;
  final List<dynamic>? inputFormatters;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final String? prefixText;

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
    this.enabled = true,
    this.hintText,
    this.maxLines = 1,
    this.inputFormatters,
    this.suffixIcon,
    this.onTap,
    this.prefixText,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _internalShowPassword = false;

  @override
  void initState() {
    super.initState();
    _internalShowPassword = widget.showPassword;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use external state if onTogglePassword is provided, otherwise use internal state
    final bool effectiveShowPassword = widget.onTogglePassword != null
        ? widget.showPassword
        : _internalShowPassword;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword && !effectiveShowPassword,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          focusNode: widget.focusNode ?? widget.node,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          onTap: widget.onTap,
          inputFormatters: widget.inputFormatters?.cast<TextInputFormatter>(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: widget.enabled ? null : theme.disabledColor,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Enter your ${widget.label}',
            prefixIcon: Icon(
              widget.icon,
              size: 20,
              color: widget.enabled ? null : theme.disabledColor,
            ),
            prefixText: widget.prefixText,
            suffixIcon: widget.suffixIcon ?? (widget.isPassword
                ? IconButton(
                    icon: Icon(
                      effectiveShowPassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                    ),
                    onPressed: widget.enabled
                        ? () {
                            if (widget.onTogglePassword != null) {
                              widget.onTogglePassword!();
                            } else {
                              setState(() {
                                _internalShowPassword = !_internalShowPassword;
                              });
                            }
                          }
                        : null,
                  )
                : null),
          ),
          validator: widget.validator,
        ),
      ],
    );
  }
}
