import 'package:flutter/material.dart';

class LogoImage extends StatefulWidget {
  const LogoImage({super.key});

  @override
  State<LogoImage> createState() => _LogoImageState();
}

class _LogoImageState extends State<LogoImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                offset: Offset(-10, 10),
                color: Color.fromARGB(80, 0, 0, 0),
                blurRadius: 10,
              ),
              BoxShadow(
                offset: Offset(10, -10),
                color: Color.fromARGB(150, 255, 255, 255),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Image.asset(
              'assets/image/logobazasr.png',
              fit: BoxFit.cover,
              height: 180,
              errorBuilder: (context, error, stackTrace) {
                return Image.network(
                  'https://storage.googleapis.com/repogalleryautorepuesto/AutoRepoLogo.png',
                  fit: BoxFit.cover,
                  height: 180,
                  errorBuilder: (context, networkError, networkStackTrace) {
                    return const Icon(Icons.error, size: 50, color: Colors.red);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}