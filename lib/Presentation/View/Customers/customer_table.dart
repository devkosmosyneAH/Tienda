import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class CustomerTable extends StatelessWidget {
  const CustomerTable({
    super.key,
    required this.customers,
    required this.selectedCustomer,
    required this.onCustomerTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? selectedCustomer;
  final ValueChanged<Map<String, dynamic>> onCustomerTap;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: customers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return _CustomerCompactRow(
                customer: customer,
                isSelected: selectedCustomer?['id'] == customer['id'],
                onTap: () => onCustomerTap(customer),
                onEdit: () => onEdit(customer),
                onDelete: () => onDelete(customer),
              );
            },
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              const _CustomerTableHeader(),
              Expanded(
                child: ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 2, color: AppColors.blackOverlay),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _CustomerTableRow(
                      customer: customer,
                      isSelected: selectedCustomer?['id'] == customer['id'],
                      onTap: () => onCustomerTap(customer),
                      onEdit: () => onEdit(customer),
                      onDelete: () => onDelete(customer),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerTableHeader extends StatelessWidget {
  const _CustomerTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppColors.whiteOverlay.withValues(alpha: .9),
      child: const Row(
        children: [
          Expanded(flex: 3, child: _HeaderLabel('Cliente')),
          Expanded(flex: 2, child: _HeaderLabel('Teléfono')),
          Expanded(flex: 3, child: _HeaderLabel('Correo')),
          Expanded(flex: 2, child: _HeaderLabel('Notas')),
          SizedBox(width: 112, child: _HeaderLabel('Acciones')),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.mediumGray,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CustomerTableRow extends StatelessWidget {
  const _CustomerTableRow({
    required this.customer,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> customer;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.whiteOverlay,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: _CustomerIdentity(customer: customer)),
              Expanded(
                flex: 2,
                child: _TableValue(customer['phone']?.toString()),
              ),
              Expanded(
                flex: 3,
                child: _TableValue(customer['email']?.toString()),
              ),
              Expanded(
                flex: 2,
                child: _TableValue(customer['notes']?.toString()),
              ),
              SizedBox(
                width: 112,
                child: _CustomerActions(onEdit: onEdit, onDelete: onDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerCompactRow extends StatelessWidget {
  const _CustomerCompactRow({
    required this.customer,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> customer;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.whiteOverlay : AppColors.lightWhite,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: _CustomerIdentity(customer: customer)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TableValue(customer['phone']?.toString()),
                    _TableValue(customer['email']?.toString()),
                  ],
                ),
              ),
              _CustomerActions(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerIdentity extends StatelessWidget {
  const _CustomerIdentity({required this.customer});

  final Map<String, dynamic> customer;

  @override
  Widget build(BuildContext context) {
    final name = customer['name']?.toString() ?? 'Sin nombre';
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.lightBlue,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primaryLogo,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryLogo,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TableValue extends StatelessWidget {
  const _TableValue(this.value);

  final String? value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.trim().isNotEmpty == true
        ? value!.trim()
        : 'Sin información';
    return Text(
      displayValue,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.mediumGray, fontSize: 11),
    );
  }
}

class _CustomerActions extends StatelessWidget {
  const _CustomerActions({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Editar cliente',
          visualDensity: VisualDensity.compact,
          onPressed: onEdit,
          icon: const Icon(
            Icons.edit_outlined,
            size: 18,
            color: AppColors.primaryBlue,
          ),
        ),
        IconButton(
          tooltip: 'Eliminar cliente',
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
            color: AppColors.primaryRed,
          ),
        ),
      ],
    );
  }
}
