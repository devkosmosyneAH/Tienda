import 'package:tienda/Presentation/Controller/users_controller.dart';
import 'package:tienda/Presentation/Model/user_model.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersController>().loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryLogo,
        foregroundColor: Colors.white,
        title: const Text(
          'Usuarios y Roles',
          style: TextStyle(color: AppColors.threeColor),
        ),
        iconTheme: const IconThemeData(color: AppColors.threeColor),
      ),
      body: Consumer<UsersController>(
        builder: (context, ctrl, _) {
          if (ctrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.error != null) {
            return Center(child: Text(ctrl.error!));
          }
          if (ctrl.users.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _UserCard(user: ctrl.users[i])
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 40 * (i % 20)),
                  duration: 300.ms,
                )
                .slideX(
                  begin: 0.1,
                  end: 0,
                  delay: Duration(milliseconds: 40 * (i % 20)),
                  duration: 300.ms,
                  curve: Curves.easeOut,
                ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(context),
        backgroundColor: AppColors.primaryLogo,
        foregroundColor: AppColors.threeColor,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
    );
  }

  void _showUserDialog(BuildContext context, {UserModel? user}) {
    showDialog(
      context: context,
      builder: (_) => _UserFormDialog(user: user),
    );
  }
}

// ─── Card de usuario ─────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<UsersController>();
    final roleColor = _roleColor(user.role);

    return Card(
      color: AppColors.whiteOverlay,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (!user.isActive)
              const Chip(
                label: Text('Inactivo', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(color: Colors.white),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                UserRoles.label(user.role),
                style: TextStyle(
                  fontSize: 11,
                  color: roleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            switch (action) {
              case 'edit':
                showDialog(
                  context: context,
                  builder: (_) => _UserFormDialog(user: user),
                );
                break;
              case 'toggle':
                final err = await ctrl.toggleActive(user);
                if (err != null && context.mounted) {
                  _showError(context, err);
                }
                break;
              case 'password':
                if (context.mounted) _showPasswordDialog(context, user);
                break;
              case 'delete':
                if (context.mounted) _confirmDelete(context, user);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(user.isActive ? 'Desactivar' : 'Activar'),
            ),
            const PopupMenuItem(
              value: 'password',
              child: Text('Cambiar contraseña'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.deepPurple;
      case 'cajero':
        return Colors.teal;
      case 'bodega':
        return Colors.orange;
      case 'reportes':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showPasswordDialog(BuildContext context, UserModel user) {
    final ctrl = context.read<UsersController>();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cambiar contraseña\n${user.fullName}'),
        content: Form(
          key: formKey,
          child: SharedTextFormField(
            controller: passCtrl,
            obscureText: true,
            label: 'Nueva contraseña',
            validator: (v) => (v == null || v.trim().length < 4)
                ? 'Mínimo 4 caracteres'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final err = await ctrl.changePassword(
                user.id!,
                passCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (err != null) {
                _showError(context, err);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contraseña actualizada')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, UserModel user) {
    final ctrl = context.read<UsersController>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
        content: Text(
          'Se eliminará a ${user.fullName}. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final err = await ctrl.deleteUser(user);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (err != null && context.mounted) {
                _showError(context, err);
              }
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Formulario crear / editar usuario ───────────────────────────────────────

class _UserFormDialog extends StatefulWidget {
  final UserModel? user;
  const _UserFormDialog({this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late String _selectedRole;
  bool _saving = false;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user?.name ?? '');
    _lastnameCtrl = TextEditingController(text: widget.user?.lastname ?? '');
    _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    _passCtrl = TextEditingController();
    // Normalizar roles antiguos ('admin') a los valores actuales
    final rawRole = widget.user?.role ?? UserRoles.cajero;
    _selectedRole = UserRoles.all.contains(rawRole)
        ? rawRole
        : (rawRole == 'admin' ? UserRoles.administrador : UserRoles.cajero);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<UsersController>();

    return AlertDialog(
      title: Text(_isEditing ? 'Editar usuario' : 'Nuevo usuario'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nombre
              SharedTextFormField(
                controller: _nameCtrl,
                label: 'Nombre *',
                prefixIcon: const Icon(Icons.person_outline),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              // Apellido
              SharedTextFormField(
                controller: _lastnameCtrl,
                label: 'Apellido',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              const SizedBox(height: 12),
              // Email — solo editable al crear
              SharedTextFormField(
                controller: _emailCtrl,
                enabled: !_isEditing,
                keyboardType: TextInputType.emailAddress,
                label: 'Correo *',
                prefixIcon: const Icon(Icons.email_outlined),
                helperText: _isEditing
                    ? 'El correo no se puede cambiar'
                    : null,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                    return 'Correo inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Contraseña — solo al crear
              if (!_isEditing)
                SharedTextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  label: 'Contraseña *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  validator: (v) => (v == null || v.trim().length < 4)
                      ? 'Mínimo 4 caracteres'
                      : null,
                ),
              if (!_isEditing) const SizedBox(height: 12),
              // Rol
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: UserRoles.all
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          '${UserRoles.label(r)} — ${UserRoles.description(r)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : () => _submit(ctrl),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLogo,
            foregroundColor: AppColors.threeColor,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Future<void> _submit(UsersController ctrl) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    String? err;
    if (_isEditing) {
      err = await ctrl.updateUser(
        widget.user!.copyWith(
          name: _nameCtrl.text.trim(),
          lastname: _lastnameCtrl.text.trim(),
          role: _selectedRole,
        ),
      );
    } else {
      err = await ctrl.createUser(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        lastname: _lastnameCtrl.text.trim(),
        role: _selectedRole,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Usuario actualizado' : 'Usuario creado exitosamente',
          ),
        ),
      );
    }
  }
}
