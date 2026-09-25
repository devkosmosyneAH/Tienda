import 'package:tienda/Presentation/Controller/users_controller.dart';
import 'package:tienda/Presentation/Model/user_model.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Vista dedicada a gestionar únicamente usuarios con rol "cajero".
/// Permite crear, editar, activar/desactivar cajeros sin entrar al módulo
/// completo de usuarios (que es solo para admin).
class CajerosView extends StatefulWidget {
  const CajerosView({super.key});

  @override
  State<CajerosView> createState() => _CajerosViewState();
}

class _CajerosViewState extends State<CajerosView> {
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
      appBar: AppBar(
        backgroundColor: AppColors.primaryLogo,
        foregroundColor: Colors.white,
        title: const Text(
          'Cajeros',
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

          final cajeros = ctrl.users
              .where((u) => u.role == UserRoles.cajero)
              .toList();

          if (cajeros.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.point_of_sale_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay cajeros registrados',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCajeroDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLogo,
                      foregroundColor: AppColors.threeColor,
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Agregar cajero'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cajeros.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _CajeroCard(user: cajeros[i])
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
        onPressed: () => _showCajeroDialog(context),
        backgroundColor: AppColors.primaryLogo,
        foregroundColor: AppColors.threeColor,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo cajero'),
      ),
    );
  }

  void _showCajeroDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _CajeroFormDialog());
  }
}

// ─── Card del cajero ─────────────────────────────────────────────────────────

class _CajeroCard extends StatelessWidget {
  final UserModel user;
  const _CajeroCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<UsersController>();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: user.isActive
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.isActive ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  fontSize: 11,
                  color: user.isActive ? Colors.green[700] : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            switch (action) {
              case 'edit':
                showDialog(
                  context: context,
                  builder: (_) => _CajeroFormDialog(user: user),
                );
                break;
              case 'toggle':
                final err = await ctrl.toggleActive(user);
                if (err != null && context.mounted) {
                  _showError(context, err);
                }
                break;
              case 'password':
                if (context.mounted) _showPasswordDialog(context, user, ctrl);
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
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showPasswordDialog(
    BuildContext context,
    UserModel user,
    UsersController ctrl,
  ) {
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
              if (err != null && context.mounted) {
                _showError(context, err);
              } else if (context.mounted) {
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
}

// ─── Formulario crear / editar cajero ────────────────────────────────────────

class _CajeroFormDialog extends StatefulWidget {
  final UserModel? user;
  const _CajeroFormDialog({this.user});

  @override
  State<_CajeroFormDialog> createState() => _CajeroFormDialogState();
}

class _CajeroFormDialogState extends State<_CajeroFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  bool _saving = false;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user?.name ?? '');
    _lastnameCtrl = TextEditingController(text: widget.user?.lastname ?? '');
    _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    _passCtrl = TextEditingController();
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
      title: Text(_isEditing ? 'Editar cajero' : 'Nuevo cajero'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SharedTextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                label: 'Nombre *',
                prefixIcon: const Icon(Icons.person_outline),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              SharedTextFormField(
                controller: _lastnameCtrl,
                textCapitalization: TextCapitalization.words,
                label: 'Apellido',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              const SizedBox(height: 12),
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
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                SharedTextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  label: 'Contraseña *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  validator: (v) => (v == null || v.trim().length < 4)
                      ? 'Mínimo 4 caracteres'
                      : null,
                ),
              ],
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
          // el rol permanece 'cajero'
        ),
      );
    } else {
      err = await ctrl.createUser(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        lastname: _lastnameCtrl.text.trim(),
        role: UserRoles.cajero,
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
            _isEditing ? 'Cajero actualizado' : 'Cajero creado exitosamente',
          ),
        ),
      );
    }
  }
}
