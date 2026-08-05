import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class CustomLoginAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomLoginAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        gradient: LinearGradient(
          colors: [AppColors.primaryLogo, AppColors.primaryLogo],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            offset: Offset(-10, 10),
            color: Color.fromARGB(80, 0, 0, 0),
            blurRadius: 10,
          ),
          BoxShadow(
            offset: Offset(-10, -10),
            color: Color.fromARGB(150, 255, 255, 255),
            blurRadius: 10,
          ),
        ],
      ),
      child: AppBar(
        title: const Text(
          'Inicio de Sesión',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xfff4f4f4),
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
