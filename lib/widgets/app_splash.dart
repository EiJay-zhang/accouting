import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppSplash extends StatefulWidget {
  final Widget child;

  const AppSplash({super.key, required this.child});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward().whenComplete(() {
        if (mounted) setState(() => _visible = false);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _SplashCanvas(progress: _controller.value),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashCanvas extends StatelessWidget {
  final double progress;

  const _SplashCanvas({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enter = Curves.easeOutCubic.transform((progress / 0.38).clamp(0.0, 1.0));
    final ring = Curves.easeOut.transform(((progress - 0.2) / 0.46).clamp(0.0, 1.0));
    final leave = Curves.easeInCubic.transform(((progress - 0.68) / 0.32).clamp(0.0, 1.0));

    return Opacity(
      opacity: 1 - leave,
      child: ColoredBox(
        color: colors.bgPrimary,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: (1 - ring) * 0.45,
                      child: Transform.scale(
                        scale: 0.72 + ring * 0.55,
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.addBtnBg, width: 2),
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: enter,
                      child: Transform.scale(
                        scale: 0.9 + enter * 0.1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/brand/app_icon_512.png',
                            width: 88,
                            height: 88,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
              Opacity(
                opacity: enter,
                child: Transform.translate(
                  offset: Offset(0, (1 - enter) * 10),
                  child: Text(
                    '记账',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
