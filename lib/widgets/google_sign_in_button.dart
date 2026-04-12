import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Google 品牌规范：白底、#dadce0 边框、#3c4043 Medium 字重；Hover 略深底 + 轻阴影。
/// 圆角、高度、水平内边距与 [authFilledButtonStyle] 对齐橙色主按钮。
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  static const Color _border = Color(0xFFdadce0);
  static const Color _text = Color(0xFF3c4043);
  static const Color _hoverSurface = Color(0xFFF8F9FA);

  static const double authButtonRadius = 20;
  static const EdgeInsets authButtonPadding = EdgeInsets.symmetric(
    vertical: 16,
    horizontal: 24,
  );
  static const Size authButtonMinimumSize = Size(double.infinity, 56);

  static RoundedRectangleBorder authButtonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(authButtonRadius),
  );

  /// 登录页主按钮使用本样式，与 Google 按钮视觉统一。
  static ButtonStyle authFilledButtonStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      minimumSize: authButtonMinimumSize,
      padding: authButtonPadding,
      shape: authButtonShape,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    );
  }

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    return MouseRegion(
      onEnter: (_) {
        if (enabled) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: _hover && enabled ? GoogleSignInButton._hoverSurface : Colors.white,
          elevation: _hover && enabled ? 2 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoogleSignInButton.authButtonRadius),
            side: const BorderSide(color: GoogleSignInButton._border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            borderRadius: BorderRadius.circular(GoogleSignInButton.authButtonRadius),
            child: Padding(
              padding: GoogleSignInButton.authButtonPadding,
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/branding/google_g_logo.svg',
                            width: 20,
                            height: 20,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              height: 1.2,
                              color: GoogleSignInButton._text,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
