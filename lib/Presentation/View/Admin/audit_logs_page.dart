import 'dart:convert';

import 'package:flutter/material.dart';

import '../../Model/audit_log_model.dart';
import '../../Services/audit_service.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final _searchController = TextEditingController();
  List<AuditLogModel> _logs = const [];
  bool? _success;
  String? _action;
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await AuditService.query(
      search: _searchController.text,
      action: _action,
      success: _success,
      limit: 50,
      offset: _page * 50,
    );
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    return date == null ? value : date.toString().substring(0, 19);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoria del sistema'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar', prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) { _page = 0; _load(); },
                  ),
                ),
                DropdownButton<String?>(
                  value: _action,
                  hint: const Text('Accion'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...AuditAction.values.map((value) => DropdownMenuItem(
                      value: value.value, child: Text(value.value),
                    )),
                  ],
                  onChanged: (value) { setState(() => _action = value); _page = 0; _load(); },
                ),
                DropdownButton<bool?>(
                  value: _success,
                  hint: const Text('Resultado'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: true, child: Text('Exito')),
                    DropdownMenuItem(value: false, child: Text('Error')),
                  ],
                  onChanged: (value) { setState(() => _success = value); _page = 0; _load(); },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildTable()),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _page == 0 ? null : () { setState(() => _page--); _load(); },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Pagina ${_page + 1}'),
                IconButton(
                  onPressed: _logs.length < 50 ? null : () { setState(() => _page++); _load(); },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_logs.isEmpty) return const Center(child: Text('No hay registros'));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Fecha')), DataColumn(label: Text('Usuario')),
            DataColumn(label: Text('Accion')), DataColumn(label: Text('Modulo')),
            DataColumn(label: Text('Entidad')), DataColumn(label: Text('ID')),
            DataColumn(label: Text('Resultado')),
          ],
          rows: _logs.map((log) => DataRow(
            onSelectChanged: (_) => _showDetails(log),
            cells: [
              DataCell(Text(_date(log.createdAt))),
              DataCell(Text(log.userName ?? log.userEmail ?? 'Sistema')),
              DataCell(Text(log.action)), DataCell(Text(log.module ?? '-')),
              DataCell(Text(log.entity ?? '-')), DataCell(Text(log.entityId ?? '-')),
              DataCell(Text(log.success ? 'SUCCESS' : 'ERROR')),
            ],
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _showDetails(AuditLogModel log) async {
    String pretty(dynamic value) => value == null
        ? '-'
        : const JsonEncoder.withIndent('  ').convert(value);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${log.action} #${log.id ?? ''}'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: SelectableText([
              'Usuario: ${log.userName ?? '-'} (${log.userEmail ?? '-'})',
              'Rol: ${log.userRole ?? '-'}',
              'Fecha: ${_date(log.createdAt)}',
              'Modulo: ${log.module ?? '-'} | Pagina: ${log.page ?? '-'}',
              'Controlador: ${log.controller ?? '-'} | Servicio: ${log.service ?? '-'}',
              'Entidad: ${log.entity ?? '-'} | ID: ${log.entityId ?? '-'}',
              'Plataforma: ${log.platform ?? '-'}',
              'Resultado: ${log.success ? 'SUCCESS' : 'ERROR'}',
              'Descripcion: ${log.description ?? '-'}',
              '\nDATOS ANTERIORES\n${pretty(log.oldData)}',
              '\nDATOS NUEVOS\n${pretty(log.newData)}',
              if (!log.success) '\nERROR\n${log.errorMessage ?? '-'}',
            ].join('\n')),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }
}