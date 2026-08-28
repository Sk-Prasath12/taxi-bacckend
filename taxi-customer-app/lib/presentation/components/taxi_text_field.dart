import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TaxiTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final bool obscureText;
  final IconData? suffixIcon;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final VoidCallback? onSuffixTap;

  const TaxiTextField({
    super.key,
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.obscureText = false,
    this.suffixIcon,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.onSuffixTap,
  });

  @override
  State<TaxiTextField> createState() => _TaxiTextFieldState();
}

class _TaxiTextFieldState extends State<TaxiTextField> {
  late bool _hidePassword;

  @override
  void initState() {
    super.initState();
    _hidePassword = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant TaxiTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.obscureText) {
      _hidePassword = false;
    } else if (!oldWidget.obscureText && widget.obscureText) {
      _hidePassword = true;
    }
  }

  Widget? _buildSuffixIcon() {
    if (widget.onSuffixTap != null && widget.suffixIcon != null) {
      return IconButton(
        onPressed: widget.onSuffixTap,
        icon: Icon(widget.suffixIcon, color: AppTheme.textSecondary),
      );
    }
    if (widget.obscureText) {
      return IconButton(
        onPressed: () => setState(() => _hidePassword = !_hidePassword),
        tooltip: _hidePassword ? 'Show password' : 'Hide password',
        icon: Icon(
          _hidePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppTheme.primary,
        ),
      );
    }
    if (widget.suffixIcon != null) {
      return IconButton(
        onPressed: widget.onSuffixTap,
        icon: Icon(widget.suffixIcon, color: AppTheme.textSecondary),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.obscureText && _hidePassword,
      keyboardType: widget.keyboardType,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        filled: true,
        fillColor: AppTheme.surfaceLight,
        prefixIcon: Icon(widget.prefixIcon, color: AppTheme.primary),
        suffixIcon: _buildSuffixIcon(),
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }
}
