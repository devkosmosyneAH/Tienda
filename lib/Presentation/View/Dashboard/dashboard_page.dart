import 'package:tienda/Presentation/Services/auth_service.dart';
import 'package:tienda/Presentation/Controller/cash_controller.dart';
import 'package:tienda/Presentation/View/Auth/app_routes.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/cash_stores_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  int _selectedIndex = 0;

  final Map<String, String> _cardRoutes = {
    'Ventas': AppRoutes.pos,
    'Compras': AppRoutes.purchases,
    'Inventario': AppRoutes.inventory,
    'Productos': AppRoutes.products,
    'Categorías': AppRoutes.categories,
    'Clientes': AppRoutes.customers,
    'Caja': AppRoutes.cash,
    'Reportes': AppRoutes.reports,
    'Usuarios': AppRoutes.users,
    'Proveedores': AppRoutes.suppliers,
    'Admin DB': AppRoutes.adminDb,
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashController>().initialize();
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn || user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  List<Widget> _buildCardsForRole(String role) {
    final allowed = AppRoutes.allowedRoutesByRole[role] ?? [AppRoutes.login];
    final List<Widget> cards = [];

    _cardRoutes.forEach((title, route) {
      if (allowed.contains(route)) {
        cards.add(
          _DashboardCard(
            title: title,
            icon: _getIconForTitle(title),
            onTap: () => Navigator.pushNamed(context, route),
          ),
        );
      }
    });

    if (cards.isEmpty) {
      cards.add(
        Center(child: Text('No tienes accesos asignados para tu rol ($role)')),
      );
    }

    return cards;
  }

  PreferredSizeWidget _buildAppBar(CashController cashController) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        clipBehavior: Clip.hardEdge,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.blackOverlay,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: AppBar(
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: AppColors.whiteOverlay),
            title: Column(
              children: [
                const Text(
                  'Panel de Control',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteOverlay,
                    fontSize: 18,
                  ),
                ),
                if (_currentUser != null)
                  Text(
                    'Bienvenido, ${_currentUser!['name'] ?? _currentUser!['nombreCompleto'] ?? 'Usuario'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: AppColors.whiteOverlay,
                    ),
                  ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CashStoresStatus(
                  controller: cashController,
                  isMobile: isMobile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_currentUser?['name'] ?? 'Usuario'),
            accountEmail: Text(_currentUser?['email'] ?? 'email@correo.com'),
            otherAccountsPictures: [
              Chip(
                label: Text(
                  _currentUser?['role'] ?? 'user',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.black26,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
            decoration: const BoxDecoration(color: AppColors.blackOverlay),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Panel de Control'),
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Perfil'),
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = _currentUser?['role'] ?? 'user';
    final cards = _buildCardsForRole(role);

    return Consumer<CashController>(
      builder: (context, cashController, _) {
        return Scaffold(
          backgroundColor: AppColors.lightGray,
          appBar: _buildAppBar(cashController),
          drawer: _buildDrawer(),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) => cards[index]
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 60 * index),
                        duration: 350.ms,
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        delay: Duration(milliseconds: 60 * index),
                        duration: 350.ms,
                        curve: Curves.easeOut,
                      ),
                ),
              ),
              Center(child: Text('Perfil: ${_currentUser?['name'] ?? ''}')),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForTitle(String titulo) {
    switch (titulo) {
      case 'Ventas':
        return Icons.point_of_sale;
      case 'Compras':
        return Icons.shopping_bag_outlined;
      case 'Productos':
        return Icons.inventory_2_outlined;
      case 'Categorías':
        return Icons.category_outlined;
      case 'Inventario':
        return Icons.storefront_outlined;
      case 'Clientes':
        return Icons.groups_2_outlined;
      case 'Caja':
        return Icons.account_balance_wallet_outlined;
      case 'Reportes':
        return Icons.bar_chart_outlined;
      case 'Usuarios':
        return Icons.manage_accounts_outlined;
      case 'Proveedores':
        return Icons.local_shipping_outlined;
      case 'Admin DB':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.help_outline;
    }
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.whiteOverlay,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppColors.primaryLogo)
                  .animate(onPlay: (c) => c.forward())
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
