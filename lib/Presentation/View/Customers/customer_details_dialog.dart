import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class CustomerDetailsDialog extends StatelessWidget {
  const CustomerDetailsDialog({super.key, required this.customer});

  final Map<String, dynamic> customer;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.lightGray,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Column(
          children: [
            _CustomerDetailsHeader(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: _CustomerDetailsContent(customer: customer),
              ),
            ),
            _CustomerDetailsFooter(onClose: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _CustomerDetailsHeader extends StatelessWidget {
  const _CustomerDetailsHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.blackOverlay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.whiteOverlay.withAlpha(28),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.whiteOverlay.withAlpha(80)),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 36,
              color: AppColors.whiteOverlay,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos del cliente',
                  style: TextStyle(
                    color: AppColors.whiteOverlay,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Información registrada',
                  style: TextStyle(color: AppColors.greyOverlay, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.whiteOverlay),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetailsContent extends StatelessWidget {
  const _CustomerDetailsContent({required this.customer});

  final Map<String, dynamic> customer;

  String _value(String key) => customer[key]?.toString() ?? 'Sin información';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Información personal'),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 520;
            final width = twoColumns
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _detailCard(
                  width: width,
                  icon: Icons.person_outline_rounded,
                  label: 'Nombre',
                  value: _value('name'),
                ),
                _detailCard(
                  width: width,
                  icon: Icons.badge_outlined,
                  label: 'Apellidos',
                  value: _value('apellidos'),
                ),
                _detailCard(
                  width: width,
                  icon: Icons.assignment_ind_outlined,
                  label: 'Cédula',
                  value: _value('cedula'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _sectionTitle('Contacto'),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 520
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _detailCard(
                  width: width,
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: _value('phone'),
                ),
                _detailCard(
                  width: width,
                  icon: Icons.email_outlined,
                  label: 'Correo',
                  value: _value('email'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _sectionTitle('Ubicación'),
        _detailCard(
          icon: Icons.location_on_outlined,
          label: 'Dirección',
          value: _value('address'),
          fullWidth: true,
        ),
        const SizedBox(height: 12),
        _detailCard(
          icon: Icons.bookmark_border,
          label: 'Referencias',
          value: _value('referencias'),
          fullWidth: true,
        ),
        const SizedBox(height: 24),
        _sectionTitle('Información adicional'),
        _detailCard(
          icon: Icons.notes_outlined,
          label: 'Notas',
          value: _value('notes'),
          fullWidth: true,
          minLines: 3,
        ),
        const SizedBox(height: 24),
        _uuidCard(_value('uid')),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primaryLogo,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String label,
    required String value,
    double? width,
    bool fullWidth = false,
    int minLines = 1,
  }) {
    final card = Container(
      width: fullWidth ? double.infinity : width,
      constraints: BoxConstraints(minHeight: minLines > 1 ? 92 : 76),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightSlateGrey.withAlpha(150)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.blackOverlay),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: minLines > 1 ? null : 2,
                  overflow: minLines > 1
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryLogo,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return card;
  }

  Widget _uuidCard(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackOverlay,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greyOverlay.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.fingerprint,
            color: AppColors.whiteOverlay,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Código (UUID)',
                  style: TextStyle(
                    color: AppColors.greyOverlay,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: AppColors.whiteOverlay,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetailsFooter extends StatelessWidget {
  const _CustomerDetailsFooter({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        border: Border(
          top: BorderSide(color: AppColors.lightSlateGrey.withAlpha(150)),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: SizedBox(
        height: 46,
        width: double.infinity,
        child: FilledButton(
          onPressed: onClose,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blackOverlay,
            foregroundColor: AppColors.whiteOverlay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cerrar'),
        ),
      ),
    );
  }
}
