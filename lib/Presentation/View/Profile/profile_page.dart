import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/cash_controller.dart';
import 'package:tienda/Presentation/Controller/license_provider.dart';
import 'package:tienda/Presentation/Controller/profile_controller.dart';
import 'package:tienda/Presentation/Model/audit_log_model.dart';
import 'package:tienda/Presentation/Model/sri_store_config_model.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';
import 'package:tienda/Presentation/Services/license_service.dart';
import 'package:tienda/Presentation/Services/sri_config_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/View/Auth/app_routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.onProfileUpdated,
    required this.onLogout,
  });

  final VoidCallback onProfileUpdated;
  final Future<bool> Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileController _controller = ProfileController();
  final AuthService _authService = AuthService();
  Future<SriStoreConfig?>? _businessConfigFuture;
  int? _businessConfigStoreId;
  int? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<SriStoreConfig?> _loadBusinessConfig(int storeId) {
    if (_businessConfigStoreId != storeId || _businessConfigFuture == null) {
      _businessConfigStoreId = storeId;
      _businessConfigFuture = SriConfigService.getConfig(storeId);
    }
    return _businessConfigFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.loading && _controller.user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.user == null) {
          return _buildLoadError();
        }

        final user = _controller.user!;
        final permissions = ProfilePermissions.forRole(user.role);
        final cashController = context.watch<CashController>();
        final contentWidth = MediaQuery.sizeOf(context).width - 32;
        final isWide = contentWidth >= 860;
        final cardWidth = isWide ? (contentWidth - 16) / 2 : contentWidth;

        return RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildProfileHeader(user),
              if (!_controller.canEditProfile) ...[
                const SizedBox(height: 12),
                _buildSessionOnlyNotice(),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildPersonalInfoCard(user),
                  ),
                  SizedBox(width: cardWidth, child: _buildSecurityCard()),
                  SizedBox(width: cardWidth, child: _buildAccountCard(user)),
                  SizedBox(
                    width: cardWidth,
                    child: _buildBusinessCard(
                      cashController,
                      isAdministrator: permissions.canViewBusinessDetails,
                    ),
                  ),
                  if (_controller.activityAvailable)
                    SizedBox(
                      width: cardWidth,
                      child: _buildActivityCard(_controller.recentActivity),
                    ),
                  SizedBox(width: cardWidth, child: _buildLicenseCard()),
                  if (permissions.hasAdministration)
                    SizedBox(
                      width: isWide ? contentWidth : cardWidth,
                      child: _buildAdministrationCard(permissions: permissions),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: OutlinedButton.icon(
                    onPressed: _confirmLogout,
                    label: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: const Text('Cerrar sesión'),
                    ),
                    icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: const Icon(Icons.logout),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dustyRose,
                      side: const BorderSide(color: AppColors.dustyRose),
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            _controller.error ?? 'No se pudo cargar el perfil.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _buildSessionOnlyNotice() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.paleCream,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.paleMauve),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: AppColors.plumGray),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Se muestran los datos de la sesión, pero la cuenta no está disponible en la base de datos abierta. '
            'El perfil está en solo lectura; cierra sesión y vuelve a ingresar para actualizarlo.',
          ),
        ),
      ],
    ),
  );

  Widget _buildProfileHeader(ProfileUserData user) {
    final initials = _initials(user);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final identity = Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.paleMauve,
                  foregroundColor: AppColors.plumGray,
                  child: initials.isEmpty
                      ? const Icon(Icons.person_outline, size: 34)
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isEmpty ? 'Perfil' : user.fullName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final badges = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RoleBadge(role: _friendlyRole(user.role)),
                _StatusBadge(isActive: user.isActive),
              ],
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 18), badges],
                  )
                : Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 16),
                      badges,
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(ProfileUserData user) => _SectionCard(
    title: 'Información personal',
    icon: Icons.person_outline,
    trailing: IconButton(
      tooltip: 'Editar información',
      onPressed: _controller.canEditProfile ? () => _editProfile(user) : null,
      icon: const Icon(Icons.edit_outlined),
    ),
    child: Column(
      children: [
        _InfoRow(label: 'Nombre', value: _valueOrDash(user.name)),
        _InfoRow(label: 'Apellido', value: _valueOrDash(user.lastname)),
        _InfoRow(label: 'Correo electrónico', value: user.email),
        _InfoRow(label: 'Rol', value: _friendlyRole(user.role)),
        _InfoRow(
          label: 'Estado de cuenta',
          value: user.isActive ? 'Activa' : 'Inactiva',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _controller.canEditProfile
                ? () => _editProfile(user)
                : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar información'),
          ),
        ),
      ],
    ),
  );

  Widget _buildSecurityCard() => _SectionCard(
    title: 'Seguridad',
    icon: Icons.shield_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contraseña'),
        const SizedBox(height: 4),
        Text(
          'Actualiza la contraseña de acceso a esta cuenta.',
          style: TextStyle(color: AppColors.mediumGray),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _controller.canEditProfile ? _changePassword : null,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Cambiar contraseña'),
            ),
            TextButton.icon(
              onPressed: _showSecurityInfo,
              icon: const Icon(Icons.info_outline),
              label: const Text('Información de seguridad'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildAccountCard(ProfileUserData user) => _SectionCard(
    title: 'Información de la cuenta',
    icon: Icons.badge_outlined,
    child: Column(
      children: [
        _InfoRow(label: 'Rol', value: _friendlyRole(user.role)),
        _InfoRow(label: 'Estado', value: user.isActive ? 'Activa' : 'Inactiva'),
        _InfoRow(label: 'Correo', value: user.email),
        _InfoRow(label: 'Creada', value: _formatDate(user.createdAt)),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_outlined),
            title: const Text('Información técnica'),
            children: [
              _InfoRow(label: 'UID', value: user.uid, selectable: true),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildBusinessCard(
    CashController cashController, {
    required bool isAdministrator,
  }) {
    final stores = cashController.stores;
    if (stores.isEmpty) {
      return _SectionCard(
        title: 'Información del negocio',
        icon: Icons.storefront_outlined,
        child: Text(
          cashController.isLoading
              ? 'Cargando información del negocio…'
              : 'No hay información de tiendas disponible.',
          style: TextStyle(color: AppColors.mediumGray),
        ),
      );
    }

    final validIds = stores.map((store) => (store['id'] as num).toInt());
    if (_selectedStoreId == null || !validIds.contains(_selectedStoreId)) {
      _selectedStoreId = cashController.selectedStoreId ?? validIds.first;
    }
    final storeId = _selectedStoreId!;
    final store = stores.firstWhere(
      (item) => (item['id'] as num).toInt() == storeId,
    );

    return _SectionCard(
      title: 'Información del negocio',
      icon: Icons.storefront_outlined,
      trailing: isAdministrator
          ? IconButton(
              tooltip: 'Administrar configuración',
              onPressed: () => _openRoute(AppRoutes.sriConfig),
              icon: const Icon(Icons.settings_outlined),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stores.length > 1)
            DropdownButtonFormField<int>(
              initialValue: storeId,
              decoration: const InputDecoration(labelText: 'Local'),
              items: [
                for (final item in stores)
                  DropdownMenuItem<int>(
                    value: (item['id'] as num).toInt(),
                    child: Text(item['name']?.toString() ?? 'Local'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedStoreId = value;
                  _businessConfigFuture = null;
                });
              },
            )
          else
            _InfoRow(
              label: isAdministrator ? 'Nombre comercial' : 'Local',
              value: store['name']?.toString() ?? '—',
            ),
          if (isAdministrator)
            FutureBuilder<SriStoreConfig?>(
              future: _loadBusinessConfig(storeId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No se pudo cargar la información tributaria.',
                      style: TextStyle(color: AppColors.dustyRose),
                    ),
                  );
                }
                final config = snapshot.data;
                if (config == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aún no hay información tributaria configurada para este local.',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                  );
                }
                return Column(
                  children: [
                    _InfoRow(label: 'RUC', value: _valueOrDash(config.ruc)),
                    _InfoRow(
                      label: 'Razón social',
                      value: _valueOrDash(config.razonSocial),
                    ),
                    _InfoRow(
                      label: 'Nombre comercial',
                      value: _valueOrDash(config.nombreComercial),
                    ),
                    _InfoRow(
                      label: 'Dirección',
                      value: _valueOrDash(config.direccionMatriz),
                    ),
                    _InfoRow(
                      label: 'Facturación electrónica',
                      value: config.sriEnabled ? 'Habilitada' : 'Deshabilitada',
                    ),
                  ],
                );
              },
            )
          else if (stores.length > 1) ...[
            const SizedBox(height: 10),
            Text(
              '${stores.length} locales disponibles',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          ],
          if (isAdministrator) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openRoute(AppRoutes.sriConfig),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Administrar configuración'),
              ),
            ),
          ],
          if (!isAdministrator)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Información básica, solo lectura.',
                style: TextStyle(color: AppColors.mediumGray),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(List<AuditLogModel> activity) => _SectionCard(
    title: 'Mi actividad',
    icon: Icons.history,
    child: activity.isEmpty
        ? Text(
            'Aún no hay actividad registrada para esta cuenta.',
            style: TextStyle(color: AppColors.mediumGray),
          )
        : Column(
            children: [for (final item in activity) _ActivityRow(item: item)],
          ),
  );

  Widget _buildLicenseCard() => Consumer<LicenseProvider>(
    builder: (context, provider, _) {
      if (provider.loading) {
        return const _SectionCard(
          title: 'Licencia',
          icon: Icons.verified_outlined,
          child: LinearProgressIndicator(),
        );
      }
      final snapshot = provider.snapshot;
      if (snapshot == null) {
        return const _SectionCard(
          title: 'Licencia',
          icon: Icons.verified_outlined,
          child: Text('No hay información de licencia disponible.'),
        );
      }

      final label = switch (snapshot.status) {
        LicenseStatus.DEMO_ACTIVA ||
        LicenseStatus.DEMO_POR_VENCER => 'Periodo de prueba',
        LicenseStatus.DEMO_VENCIDA => 'Prueba vencida',
        LicenseStatus.LICENCIA_ACTIVA =>
          snapshot.expiresAt == null
              ? 'Licencia permanente'
              : 'Licencia activa',
        LicenseStatus.LICENCIA_EXPIRADA => 'Licencia expirada',
        LicenseStatus.LICENCIA_REVOCADA => 'Licencia revocada',
        LicenseStatus.LICENCIA_INVALIDA => 'Licencia no válida',
      };
      final isActive =
          snapshot.status == LicenseStatus.DEMO_ACTIVA ||
          snapshot.status == LicenseStatus.DEMO_POR_VENCER ||
          snapshot.status == LicenseStatus.LICENCIA_ACTIVA;

      return _SectionCard(
        title: 'Licencia',
        icon: Icons.verified_outlined,
        trailing: IconButton(
          tooltip: 'Ver licencia',
          onPressed: () => _openRoute(AppRoutes.license),
          icon: const Icon(Icons.open_in_new),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.error_outline,
                  color: isActive ? AppColors.plumGray : AppColors.dustyRose,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
              ],
            ),
            if (snapshot.status == LicenseStatus.DEMO_ACTIVA ||
                snapshot.status == LicenseStatus.DEMO_POR_VENCER)
              _InfoRow(
                label: 'Días restantes',
                value: provider.remainingDays.toString(),
              ),
            if (snapshot.expiresAt != null)
              _InfoRow(
                label: 'Vencimiento',
                value: _formatDate(
                  snapshot.expiresAt!.toLocal().toIso8601String(),
                ),
              ),
            if (snapshot.status == LicenseStatus.LICENCIA_ACTIVA &&
                snapshot.expiresAt == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No requiere renovación por vencimiento.'),
              ),
          ],
        ),
      );
    },
  );

  Widget _buildAdministrationCard({required ProfilePermissions permissions}) =>
      _SectionCard(
        title: permissions.canManageSystemSettings
            ? 'Administración'
            : 'Configuración',
        icon: Icons.admin_panel_settings_outlined,
        child: Column(
          children: [
            if (permissions.canManageUsers)
              _AdminAction(
                icon: Icons.groups_outlined,
                title: 'Gestión de usuarios',
                onTap: () => _openRoute(AppRoutes.users),
              ),
            if (permissions.canManageSystemSettings)
              _AdminAction(
                icon: Icons.settings_outlined,
                title: 'Configuración del sistema',
                onTap: () => _openRoute(AppRoutes.adminDb),
              ),
            if (permissions.canViewAudit)
              _AdminAction(
                icon: Icons.receipt_long_outlined,
                title: 'Actividad / Auditoría',
                onTap: () => _openRoute(AppRoutes.auditLogs),
              ),
            _AdminAction(
              icon: Icons.storefront_outlined,
              title: 'Información del negocio',
              onTap: () => _openRoute(AppRoutes.sriConfig),
            ),
            _AdminAction(
              icon: Icons.lock_outline,
              title: 'Seguridad',
              onTap: _controller.canEditProfile ? _changePassword : null,
            ),
          ],
        ),
      );

  Future<void> _editProfile(ProfileUserData user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _EditProfileDialog(user: user, onSave: _controller.updateProfile),
    );
    if (saved == true && mounted) {
      widget.onProfileUpdated();
      _showMessage('Información personal actualizada.');
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(onSave: _controller.changePassword),
    );
    if (changed == true && mounted) {
      _showMessage('Contraseña actualizada.');
    }
  }

  Future<void> _showSecurityInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Información de seguridad'),
      content: const Text(
        'La autenticación de esta instalación utiliza la sesión local de la aplicación. '
        'El sistema no ofrece cierre remoto de sesiones en otros dispositivos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await widget.onLogout();
    if (!success && mounted) _showMessage('No se pudo cerrar la sesión.');
  }

  Future<void> _openRoute(String route) async {
    try {
      final session = await _authService.getCurrentUser();
      final uid = session?['uid']?.toString().trim() ?? '';
      if (uid.isEmpty) {
        if (mounted) _showMessage('La sesión ya no está activa.');
        return;
      }

      final current = await _authService.getUserByUid(uid);
      final role = current?['role']?.toString() ?? '';
      final isActive = (current?['is_active'] as num?)?.toInt() != 0;
      final permitted =
          isActive && AppRoutes.getRoutesForRole(role).contains(route);
      if (!permitted) {
        if (mounted) _showMessage('No tienes permisos para esta opción.');
        return;
      }
      if (mounted) await Navigator.pushNamed(context, route);
    } catch (_) {
      if (mounted) _showMessage('No se pudo verificar tu cuenta. Reintenta.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyRole(String role) => ProfilePermissions.roleLabel(role);

  String _initials(ProfileUserData user) {
    final parts = user.fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String _valueOrDash(String value) => value.trim().isEmpty ? '—' : value;

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '—';
    return DateFormat('d MMM yyyy, HH:mm', 'es').format(date.toLocal());
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.plumGray),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 136,
          child: Text(label, style: TextStyle(color: AppColors.mediumGray)),
        ),
        Expanded(
          child: selectable
              ? SelectableText(value)
              : Text(value, softWrap: true),
        ),
      ],
    ),
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.paleMauve,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      role,
      style: const TextStyle(
        color: AppColors.plumGray,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.plumGray : AppColors.dustyRose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isActive ? AppColors.mutedCream : AppColors.blush,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Cuenta activa' : 'Cuenta inactiva',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final AuditLogModel item;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(item.createdAt);
    final subtitleParts = <String>[
      if (item.module?.isNotEmpty == true) item.module!,
      if (item.platform?.isNotEmpty == true) item.platform!,
      if (date != null) DateFormat('d MMM, HH:mm', 'es').format(date.toLocal()),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.success ? Icons.check_circle_outline : Icons.error_outline,
        color: item.success ? AppColors.plumGray : AppColors.dustyRose,
      ),
      title: Text(_actionLabel(item.action)),
      subtitle: Text(subtitleParts.join(' · ')),
      dense: true,
    );
  }

  String _actionLabel(String action) => switch (action.toUpperCase()) {
    'LOGIN_SUCCESS' => 'Inicio de sesión',
    'LOGIN_FAILED' => 'Intento de acceso no completado',
    'LOGOUT' => 'Cierre de sesión',
    'UPDATE_USER' => 'Información personal actualizada',
    'CHANGE_PASSWORD' => 'Contraseña actualizada',
    _ => action.replaceAll('_', ' ').toLowerCase(),
  };
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user, required this.onSave});

  final ProfileUserData user;
  final Future<String?> Function({
    required String name,
    required String lastname,
    required String email,
  })
  onSave;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.name,
  );
  late final TextEditingController _lastnameController = TextEditingController(
    text: widget.user.lastname,
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.user.email,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(
      name: _nameController.text,
      lastname: _lastnameController.text,
      email: _emailController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar información'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa tu nombre.'
                    : null,
              ),
              TextFormField(
                controller: _lastnameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa tu apellido.'
                    : null,
              ),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                      ? null
                      : 'Ingresa un correo válido.';
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppColors.dustyRose)),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Guardar'),
      ),
    ],
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.onSave});

  final Future<String?> Function({
    required String currentPassword,
    required String newPassword,
  })
  onSave;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  InputDecoration _passwordDecoration(String label) => InputDecoration(
    labelText: label,
    suffixIcon: IconButton(
      tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cambiar contraseña'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: _obscure,
                decoration: _passwordDecoration('Contraseña actual'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingresa la contraseña actual.'
                    : null,
              ),
              TextFormField(
                controller: _newController,
                obscureText: _obscure,
                decoration: _passwordDecoration('Nueva contraseña'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa una contraseña nueva.';
                  }
                  if (value.length < 8) {
                    return 'Usa al menos 8 caracteres.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                decoration: _passwordDecoration('Confirmar nueva contraseña'),
                validator: (value) => value != _newController.text
                    ? 'Las contraseñas no coinciden.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppColors.dustyRose)),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Actualizar contraseña'),
      ),
    ],
  );
}
