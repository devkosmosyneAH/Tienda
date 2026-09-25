import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
export 'image_preview.dart';

class SharedTextField extends StatelessWidget {
  const SharedTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.helperText,
    this.style,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onEditingComplete,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.inputFormatters,
    this.useFilterStyle = false,
    this.alignLabelWithHint = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? prefix;
  final String? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? helperText;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final bool useFilterStyle;
  final bool alignLabelWithHint;

  InputDecoration get _decoration {
    final decoration = useFilterStyle || label == null
        ? filterFieldDecoration(hint: hint ?? '', prefixIcon: prefixIcon)
        : modernInput(
            label: label ?? '',
            hint: hint,
            prefix: prefix,
            suffix: suffix,
            prefixIcon: prefixIcon,
          );
    return decoration.copyWith(
      suffixIcon: suffixIcon,
      helperText: helperText,
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: _decoration,
      style: style,
      textAlign: textAlign,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      readOnly: readOnly,
      enabled: enabled,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
    );
  }
}

class SharedTextFormField extends StatelessWidget {
  const SharedTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.helperText,
    this.style,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.onEditingComplete,
    this.validator,
    this.onSaved,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.inputFormatters,
    this.useFilterStyle = false,
    this.alignLabelWithHint = false,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? prefix;
  final String? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? helperText;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final bool useFilterStyle;
  final bool alignLabelWithHint;

  InputDecoration _decoration() {
    final decoration = useFilterStyle || label == null
        ? filterFieldDecoration(hint: hint ?? '', prefixIcon: prefixIcon)
        : modernInput(
            label: label ?? '',
            hint: hint,
            prefix: prefix,
            suffix: suffix,
            prefixIcon: prefixIcon,
          );
    return decoration.copyWith(
      suffixIcon: suffixIcon,
      helperText: helperText,
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      decoration: _decoration(),
      style: style,
      textAlign: textAlign,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      validator: validator,
      onSaved: onSaved,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      readOnly: readOnly,
      enabled: enabled,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
    );
  }
}

InputDecoration filterFieldDecoration({
  required String hint,
  String? label,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: Colors.white,
    hoverColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}

InputDecoration modernInput({
  required String label,
  String? hint,
  String? prefix,
  String? suffix,
  Widget? prefixIcon,
}) {
  return filterFieldDecoration(
    hint: hint ?? label,
    label: label,
    prefixIcon: prefixIcon,
  ).copyWith(prefixText: prefix, suffixText: suffix);
}

Widget formSection({required String title, required List<Widget> children}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 12),
      ...children,
    ],
  );
}

Widget imagePlaceholder() {
  return Container(
    color: AppColors.lightWhite,
    child: Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 40,
        color: Colors.grey.shade300,
      ),
    ),
  );
}

// Shows a persistent progress-style SnackBar. Call `hideProgressNotification`
// to dismiss it when the operation completes.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
showProgressNotification(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(days: 365),
      backgroundColor: Colors.black87,
      content: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

void hideProgressNotification(BuildContext context) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
}
