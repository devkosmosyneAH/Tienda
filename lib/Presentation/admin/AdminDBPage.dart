// ignore_for_file: file_names, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../Services/database_config.dart';
import '../Services/database_location_service.dart';
import '../Services/database_service.dart';

/// Metadatos de esquema usados únicamente por el asistente SQL de administración.
class _SqlTableInfo {
  const _SqlTableInfo({required this.name, required this.columns});

  final String name;
  final List<_SqlColumnInfo> columns;
}

class _SqlColumnInfo {
  const _SqlColumnInfo({
    required this.name,
    required this.type,
    required this.isPrimaryKey,
  });

  final String name;
  final String type;
  final bool isPrimaryKey;
}

class AdminDBPage extends StatefulWidget {
  const AdminDBPage({super.key});

  @override
  State<AdminDBPage> createState() => _AdminDBPageState();
}

class _AdminDBPageState extends State<AdminDBPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _queryResult = [];
  List<String> _queryHistory = [];
  static const String _queryHistoryFileName = 'sql_query_history.json';
  String _message = '';
  Color _messageColor = AppColors.blackOverlay;
  bool _isLoading = false;
  final ScrollController _verticalScroll = ScrollController();

  // Estado del asistente SQL: el esquema siempre se lee desde la DB conectada.
  List<_SqlTableInfo> _schemaTables = const [];
  String? _selectedTableName;
  Set<String> _selectedColumnNames = <String>{};
  bool _isLoadingSchema = false;

  String? _actualDbPath; // Ruta real obtenida del DatabaseLocationService

  // ✅ MÉTODO MEJORADO: Obtener la ruta real usando DatabaseLocationService
  Future<String> get dbPath async {
    if (_actualDbPath != null) return _actualDbPath!;

    _actualDbPath = await DatabaseLocationService.getDatabasePath();

    return _actualDbPath!;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
    _loadQueryHistory();
    _openDB();
  }

  Future<void> _openDB() async {
    setState(() => _isLoading = true);
    try {
      final path = await dbPath;

      debugPrint('Opening database via DatabaseService:');
      debugPrint(path);

      await DatabaseService.database;
      await _loadDatabaseSchema();
      setState(() {
        _message =
            '✅ Base de datos conectada correctamente (${_getCurrentPlatform()})';
        _messageColor = AppColors.darkGreen;
      });
    } catch (e) {
      setState(() {
        _message = '⛔ Error al conectar: $e';
        _messageColor = AppColors.primaryRed;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleDatabaseChanged() {
    if (!mounted) return;
    setState(() {
      _queryResult = [];
      _schemaTables = const [];
      _selectedTableName = null;
      _selectedColumnNames = <String>{};
      _message = '🔄 Base de datos actualizada. Recargando esquema...';
      _messageColor = AppColors.primaryBlue;
    });
    _loadDatabaseSchema();
  }

  Future<void> _runQuery() async {
    final sql = _queryController.text.trim();
    if (sql.isEmpty) return;

    if (_containsMultipleStatements(sql)) {
      _setSqlMessage(
        '⚠️ Ejecuta una sola sentencia a la vez para poder revisarla con seguridad.',
        AppColors.primaryRed,
      );
      return;
    }

    if (!_isReadOnlySql(sql) && !await _confirmDataChange(sql)) return;

    await _executeSql(sql);
  }

  Future<void> _executeSql(String sql) async {
    final normalizedSql = sql.trim().replaceFirst(RegExp(r';\s*$'), '');

    setState(() => _isLoading = true);

    try {
      final dbInstance = await DatabaseService.database;
      if (_isReadOnlySql(normalizedSql)) {
        final result = await dbInstance.rawQuery(normalizedSql);
        setState(() {
          _queryResult = result;
          _message = '✅ Consulta exitosa (${result.length} filas)';
          _messageColor = AppColors.darkGreen;
        });
      } else {
        int changes = 0;
        final command = _sqlCommand(normalizedSql);
        if (command == 'update') {
          changes = await dbInstance.rawUpdate(normalizedSql);
        } else if (command == 'delete') {
          changes = await dbInstance.rawDelete(normalizedSql);
        } else if (command == 'insert') {
          changes = await dbInstance.rawInsert(normalizedSql);
        } else {
          await dbInstance.execute(normalizedSql);
        }
        setState(() {
          _queryResult = [];
          if (command == 'update') {
            _message = '🔄 UPDATE realizado ($changes registros afectados)';
            _messageColor = AppColors.primaryBlue;
          } else if (command == 'delete') {
            if (changes == 0) {
              _message =
                  '🗑️ DELETE ejecutado, pero no se encontró ningún registro con esa condición.';
              _messageColor = AppColors.primaryBlue;
            } else {
              _message = '🗑️ DELETE realizado ($changes registros eliminados)';
              _messageColor = AppColors.primaryRed;
            }
          } else if (command == 'insert') {
            _message = '📥 INSERT realizado (ID del nuevo registro: $changes)';
            _messageColor = AppColors.darkGreen;
          } else {
            _message = '⚙️ Comando ejecutado correctamente';
            _messageColor = AppColors.primaryBlue;
          }
        });
      }
      _addQueryHistory(normalizedSql);
    } catch (e) {
      setState(() {
        _message = '⛔ Error SQL: ${_formatError(e.toString())}';
        _messageColor = AppColors.primaryRed;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _sqlCommand(String sql) {
    return RegExp(
          r'^\s*([a-zA-Z]+)',
        ).firstMatch(sql)?.group(1)?.toLowerCase() ??
        '';
  }

  void _addQueryHistory(String sql) {
    final normalized = sql.trim();
    if (normalized.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _queryHistory.remove(normalized);
      _queryHistory.insert(0, normalized);
      if (_queryHistory.length > 20) {
        _queryHistory.removeRange(20, _queryHistory.length);
      }
    });
    _saveQueryHistory();
  }

  Future<void> _loadQueryHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(join(directory.path, _queryHistoryFileName));
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List<dynamic>) {
        final history = decoded.whereType<String>().toList();
        if (mounted) {
          setState(() {
            _queryHistory = history;
          });
        }
      }
    } catch (_) {
      // Si falla al leer el historial, ignoramos para no bloquear la UI.
    }
  }

  Future<void> _saveQueryHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(join(directory.path, _queryHistoryFileName));
      await file.writeAsString(jsonEncode(_queryHistory));
    } catch (_) {
      // Ignorar errores de persistencia.
    }
  }

  bool _isReadOnlySql(String sql) {
    const readOnlyCommands = {'select', 'pragma', 'explain'};
    return readOnlyCommands.contains(_sqlCommand(sql));
  }

  bool _containsMultipleStatements(String sql) {
    final withoutTrailingSemicolon = sql.trim().replaceFirst(
      RegExp(r';\s*$'),
      '',
    );
    return withoutTrailingSemicolon.contains(';');
  }

  void _setSqlMessage(String message, Color color) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageColor = color;
    });
  }

  Future<bool> _confirmDataChange(String sql) async {
    final command = _sqlCommand(sql).toUpperCase();
    final isDeleteWithoutWhere =
        command == 'DELETE' &&
        !RegExp(r'\bWHERE\b', caseSensitive: false).hasMatch(sql);
    final warning = isDeleteWithoutWhere
        ? 'Esta sentencia eliminará todos los registros de la tabla.'
        : 'Esta acción modificará la base de datos y no se puede deshacer desde esta pantalla.';

    return await showDialog<bool>(
          // `dart:io` also exposes Context; el cast conserva el BuildContext
          // del State en esta pantalla que usa APIs de archivos.
          context: context as BuildContext,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              isDeleteWithoutWhere
                  ? Icons.warning_amber_rounded
                  : Icons.edit_note,
              color: isDeleteWithoutWhere
                  ? AppColors.primaryRed
                  : AppColors.primaryBlue,
            ),
            title: Text('Confirmar $command'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(warning),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      sql,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isDeleteWithoutWhere
                      ? AppColors.primaryRed
                      : AppColors.primaryBlue,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sí, ejecutar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _loadDatabaseSchema() async {
    if (!mounted) return;
    setState(() => _isLoadingSchema = true);
    try {
      final dbInstance = await DatabaseService.database;
      final rows = await dbInstance.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' ORDER BY name",
      );
      final tables = <_SqlTableInfo>[];
      for (final row in rows) {
        final name = row['name'] as String;
        final columns = await dbInstance.rawQuery(
          'PRAGMA table_info(${_quoteIdentifier(name)})',
        );
        tables.add(
          _SqlTableInfo(
            name: name,
            columns: columns
                .map(
                  (column) => _SqlColumnInfo(
                    name: column['name'] as String,
                    type: (column['type'] as String? ?? '').toUpperCase(),
                    isPrimaryKey: (column['pk'] as num? ?? 0) > 0,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _schemaTables = tables;
        final stillExists = tables.any(
          (table) => table.name == _selectedTableName,
        );
        _selectedTableName = stillExists
            ? _selectedTableName
            : (tables.isEmpty ? null : tables.first.name);
        _selectedColumnNames =
            _selectedTable?.columns.map((column) => column.name).toSet() ??
            <String>{};
      });
    } catch (e) {
      _setSqlMessage('⛔ No se pudo leer el esquema: $e', AppColors.primaryRed);
    } finally {
      if (mounted) setState(() => _isLoadingSchema = false);
    }
  }

  _SqlTableInfo? get _selectedTable {
    for (final table in _schemaTables) {
      if (table.name == _selectedTableName) return table;
    }
    return null;
  }

  String _quoteIdentifier(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  Future<void> _loadSelectedRecords() async {
    final table = _selectedTable;
    if (table == null) return;
    final selectedColumns = table.columns
        .where((column) => _selectedColumnNames.contains(column.name))
        .map((column) => _quoteIdentifier(column.name))
        .toList();
    final columns = selectedColumns.isEmpty ? '*' : selectedColumns.join(', ');
    final sql =
        'SELECT $columns FROM ${_quoteIdentifier(table.name)} LIMIT 100;';
    _queryController.text = sql;
    await _executeSql(sql);
  }

  void _fillSqlTemplate(String type) {
    final table = _selectedTable;
    if (table == null) {
      _setSqlMessage(
        'Selecciona una tabla antes de generar una sentencia.',
        AppColors.primaryRed,
      );
      return;
    }
    final primaryKeyColumns = table.columns
        .where((column) => column.isPrimaryKey)
        .map((column) => column.name)
        .toList(growable: false);
    final primaryKey = primaryKeyColumns.isEmpty
        ? null
        : primaryKeyColumns.first;
    final column = table.columns
        .firstWhere(
          (item) => !item.isPrimaryKey,
          orElse: () => table.columns.first,
        )
        .name;
    final quotedTable = _quoteIdentifier(table.name);
    final quotedColumn = _quoteIdentifier(column);
    final whereColumn = _quoteIdentifier(primaryKey ?? 'id');
    final selectedColumns = _selectedColumnNames.isEmpty
        ? '*'
        : table.columns
              .where((item) => _selectedColumnNames.contains(item.name))
              .map((item) => _quoteIdentifier(item.name))
              .join(', ');

    final sql = switch (type) {
      'select' => 'SELECT $selectedColumns FROM $quotedTable LIMIT 100;',
      'update' =>
        'UPDATE $quotedTable\nSET $quotedColumn = \'nuevo valor\'\nWHERE $whereColumn = 1;',
      'insert' =>
        'INSERT INTO $quotedTable ($quotedColumn)\nVALUES (\'valor\');',
      'delete' => 'DELETE FROM $quotedTable\nWHERE $whereColumn = 1;',
      _ => '',
    };
    _queryController.text = sql;
    _setSqlMessage(
      'Plantilla $type generada. Reemplaza los valores de ejemplo antes de ejecutar.',
      AppColors.primaryBlue,
    );
  }

  String _formatError(String error) {
    if (error.contains('FOREIGN KEY constraint failed')) {
      return 'No se puede eliminar porque hay registros relacionados que dependen de esta fila.';
    }

    final regex = RegExp(
      r'(near .*: syntax error)|(no such table: \w+)|(NOT NULL constraint failed: \w+\.\w+)',
    );
    final match = regex.firstMatch(error);
    return match?.group(0) ?? error;
  }

  Future<void> _copyToClipboard(String text, {String? successMessage}) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text(
              successMessage ?? '📋 Copiado al portapapeles',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.darkGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text(
              '⛔ Error al copiar: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryRed,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  String _generateResultsText() {
    if (_queryResult.isEmpty) {
      return 'No hay resultados para mostrar';
    }

    final columns = _queryResult.first.keys.toList();
    final StringBuffer buffer = StringBuffer();

    // Información de la consulta
    buffer.writeln('=== RESULTADOS DE CONSULTA SQL ===');
    buffer.writeln('Fecha: ${DateTime.now().toString()}');
    buffer.writeln('Plataforma: ${_getCurrentPlatform()}');
    buffer.writeln('Registros encontrados: ${_queryResult.length}');
    buffer.writeln('Consulta ejecutada: ${_queryController.text.trim()}');
    buffer.writeln('');

    // Encabezados
    buffer.writeln(columns.join('\t'));
    buffer.writeln('-' * (columns.length * 15)); // Línea separadora

    // Datos
    for (int i = 0; i < _queryResult.length; i++) {
      final row = _queryResult[i];
      final values = columns
          .map((col) => row[col]?.toString() ?? 'NULL')
          .toList();
      buffer.writeln('${i + 1}.\t${values.join('\t')}');
    }

    buffer.writeln('');
    buffer.writeln('=== FIN DE RESULTADOS ===');

    return buffer.toString();
  }

  String _generateCleanResultsText() {
    if (_queryResult.isEmpty) {
      return 'No hay resultados para mostrar';
    }

    final columns = _queryResult.first.keys.toList();
    final StringBuffer buffer = StringBuffer();

    // Solo encabezados y datos (formato CSV/TSV)
    buffer.writeln(columns.join('\t'));

    for (final row in _queryResult) {
      final values = columns.map((col) => row[col]?.toString() ?? '').toList();
      buffer.writeln(values.join('\t'));
    }

    return buffer.toString();
  }

  String _getCurrentPlatform() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Desconocida';
  }

  String _getPlatformIcon() {
    if (Platform.isAndroid) return '🤖';
    if (Platform.isIOS) return '🍎';
    if (Platform.isMacOS) return '💻';
    if (Platform.isWindows) return '🪟';
    if (Platform.isLinux) return '🐧';
    return '❓';
  }

  Future<void> _replaceDatabase() async {
    setState(() => _isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Selecciona el archivo de base de datos',
      );

      if (result != null && result.files.single.path != null) {
        final File selectedFile = File(result.files.single.path!);

        await DatabaseService.replaceDatabase(selectedFile);
        await _openDB();

        setState(() {
          _message =
              '✅ Base de datos reemplazada exitosamente desde: ${result.files.single.name}';
          _messageColor = AppColors.darkGreen;
        });
      } else {
        setState(() {
          _message = '⚠️ No se seleccionó ningún archivo';
          _messageColor = AppColors.primaryBlue;
        });
      }
    } catch (e) {
      setState(() {
        _message = '⛔ Error al reemplazar la base de datos: $e';
        _messageColor = AppColors.primaryRed;
      });
      // Intentar reabrir la conexión original
      try {
        await _openDB();
      } catch (reopenError) {
        setState(() {
          _message =
              '⛔ Error crítico: No se pudo reabrir la base de datos: $reopenError';
          _messageColor = AppColors.primaryRed;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyDatabaseFromAssets() async {
    setState(() => _isLoading = true);

    try {
      await DatabaseService.restoreFromAssets();
      await _openDB();

      setState(() {
        _message =
            '✅ Base de datos restaurada exitosamente desde assets del proyecto';
        _messageColor = AppColors.darkGreen;
      });
    } catch (e) {
      setState(() {
        _message = '⛔ Error al restaurar desde assets: $e';
        _messageColor = AppColors.primaryRed;
      });
      // Intentar reabrir la conexión original
      try {
        await _openDB();
      } catch (reopenError) {
        setState(() {
          _message =
              '⛔ Error crítico: No se pudo reabrir la base de datos: $reopenError';
          _messageColor = AppColors.primaryRed;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportDB() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final newFile = File(join(directory.path, DatabaseConfig.dbName));

      final path = await dbPath; // ✅ Await para obtener la ruta real

      String sourceDbPath;
      if (Platform.isAndroid || Platform.isIOS) {
        // Para móviles, obtener la ruta real de la base de datos
        final String dbDirectory = await getDatabasesPath();
        sourceDbPath = join(dbDirectory, DatabaseConfig.dbName);
      } else {
        // Para desktop, usar la ruta obtenida del LocationService
        sourceDbPath = path;
      }

      await File(sourceDbPath).copy(newFile.path);

      Share.shareXFiles([XFile(newFile.path)], text: 'Base de datos exportada');

      setState(() {
        _message = '📤 Base de datos exportada: ${newFile.path}';
        _messageColor = AppColors.darkGreen;
      });
    } catch (e) {
      setState(() {
        _message = '⛔ Error al exportar: $e';
        _messageColor = AppColors.primaryRed;
      });
    }
  }

  Future<void> _openDatabaseFolder() async {
    try {
      String realPath;
      if (Platform.isAndroid || Platform.isIOS) {
        final String dbDirectory = await getDatabasesPath();
        realPath = join(dbDirectory, DatabaseConfig.dbName);
      } else {
        realPath = await dbPath;
      }

      final String folderPath = File(realPath).parent.path;

      if (Platform.isAndroid || Platform.isIOS) {
        await _copyToClipboard(
          folderPath,
          successMessage:
              '📋 Ruta de carpeta copiada (en móvil no se puede abrir directamente)',
        );

        setState(() {
          _message =
              'ℹ️ En ${_getCurrentPlatform()} la carpeta no se puede abrir directamente. Ruta copiada al portapapeles.';
          _messageColor = AppColors.primaryBlue;
        });
        return;
      }

      ProcessResult result;
      if (Platform.isMacOS) {
        result = await Process.run('open', [folderPath]);
      } else if (Platform.isWindows) {
        result = await Process.run('explorer', [folderPath]);
      } else if (Platform.isLinux) {
        result = await Process.run('xdg-open', [folderPath]);
      } else {
        throw UnsupportedError('Plataforma no compatible para abrir carpetas');
      }

      if (result.exitCode == 0) {
        setState(() {
          _message = '📂 Carpeta abierta: $folderPath';
          _messageColor = AppColors.darkGreen;
        });
      } else {
        throw Exception(
          result.stderr.toString().isNotEmpty
              ? result.stderr.toString()
              : 'No se pudo abrir la carpeta',
        );
      }
    } catch (e) {
      setState(() {
        _message = '⛔ Error al abrir carpeta de la DB: $e';
        _messageColor = AppColors.primaryRed;
      });
    }
  }

  void _clearConsole() {
    setState(() {
      _queryResult = [];
      _message = 'No hay resultados para mostrar';
      _messageColor = AppColors.primaryBlue;
    });
    _queryController.clear();
  }

  Future<void> _exportToJsonLocally() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final folderName =
          'BazarNicole_JSON_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${docsDir.path}/$folderName');
      await exportDir.create(recursive: true);

      final dbInstance = await DatabaseService.database;

      // Obtener nombres de tablas
      final List<Map<String, dynamic>> tableRows = await dbInstance.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );
      final tables = tableRows.map((r) => r['name'] as String).toList();

      final List<String> exportedFiles = [];

      for (final table in tables) {
        final rows = await dbInstance.query(table);
        final jsonContent = JsonEncoder.withIndent('  ').convert(rows);
        final file = File('${exportDir.path}/$table.json');
        await file.writeAsString(jsonContent, flush: true);
        exportedFiles.add('$table.json');
      }

      // Compartir en móvil / abrir carpeta en desktop
      if (Platform.isAndroid || Platform.isIOS) {
        final xFiles = exportedFiles
            .map((name) => XFile('${exportDir.path}/$name'))
            .toList();
        await Share.shareXFiles(
          xFiles,
          text: 'Exportación JSON de BazarNicole',
        );
      } else {
        ProcessResult result;
        if (Platform.isMacOS) {
          result = await Process.run('open', [exportDir.path]);
        } else if (Platform.isWindows) {
          result = await Process.run('explorer', [exportDir.path]);
        } else {
          result = await Process.run('xdg-open', [exportDir.path]);
        }
        if (result.exitCode != 0) {
          throw Exception('No se pudo abrir la carpeta: ${result.stderr}');
        }
      }

      setState(() {
        _message =
            '✅ ${exportedFiles.length} archivos JSON exportados en:\n${exportDir.path}';
        _messageColor = AppColors.darkGreen;
      });
    } catch (e) {
      setState(() {
        _message = '⛔ Error al exportar JSON: $e';
        _messageColor = AppColors.primaryRed;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildResultConsole() {
    if (_queryResult.isEmpty) {
      return Center(
        child: Text(
          'No hay resultados para mostrar',
          style: TextStyle(
            color: AppColors.mediumGray,
            fontSize: 16,
            fontStyle: FontStyle.italic,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    final columns = _queryResult.first.keys.toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkGray.withOpacity(0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.blackOverlay.withOpacity(0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackOverlay.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 320,
        child: Scrollbar(
          thumbVisibility: true,
          controller: _verticalScroll,
          child: ListView(
            controller: _verticalScroll,
            shrinkWrap: true,
            children: [
              // Encabezados
              RichText(
                text: TextSpan(
                  children: [
                    for (int i = 0; i < columns.length; i++)
                      TextSpan(
                        text: (i > 0 ? '   ' : '') + columns[i].toUpperCase(),
                        style: TextStyle(
                          color: AppColors.lightWhite,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Separador
              Container(
                height: 2,
                color: AppColors.lightWhite.withOpacity(0.25),
                margin: const EdgeInsets.only(bottom: 8),
              ),
              // Filas
              for (final row in _queryResult)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        for (int i = 0; i < columns.length; i++)
                          TextSpan(
                            text:
                                (i > 0 ? '   ' : '') +
                                (row[columns[i]]?.toString() ?? 'NULL'),
                            style: TextStyle(
                              color: row[columns[i]] == null
                                  ? AppColors.lightRed
                                  : AppColors.lightGreen.withOpacity(0.95),
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplaceDBTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Información de la plataforma
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withOpacity(0.1),
                  AppColors.primaryBlue.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryBlue.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      _getPlatformIcon(),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plataforma Actual',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCurrentPlatform(),
                            style: TextStyle(
                              color: AppColors.blackOverlay,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.mediumGray.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ruta de la Base de Datos:',
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy,
                              color: AppColors.primaryBlue,
                              size: 16,
                            ),
                            onPressed: () async {
                              final String realPath = await dbPath;
                              _copyToClipboard(
                                realPath,
                                successMessage:
                                    '📋 Ruta de DB copiada al portapapeles',
                              );
                            },
                            tooltip: 'Copiar ruta',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.open_in_new,
                              color: AppColors.darkGreen,
                              size: 16,
                            ),
                            onPressed: _isLoading ? null : _openDatabaseFolder,
                            tooltip: 'OPEN - Abrir carpeta',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      ),
                      FutureBuilder<String>(
                        future: () async {
                          return await dbPath;
                        }(),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Cargando...',
                            style: TextStyle(
                              color: AppColors.blackOverlay,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Título de opciones
          Text(
            'OPCIONES DE REEMPLAZO',
            style: TextStyle(
              color: AppColors.blackOverlay,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Opción 1: Seleccionar archivo
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.folder_open,
                          color: AppColors.darkGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seleccionar archivo .db',
                          style: TextStyle(
                            color: AppColors.blackOverlay,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selecciona un archivo de base de datos (.db) desde tu dispositivo para reemplazar la actual.',
                    style: TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('SELECCIONAR ARCHIVO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _replaceDatabase,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Opción 2: Desde assets (futura implementación)
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.storage,
                          color: AppColors.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Desde Assets del Proyecto',
                          style: TextStyle(
                            color: AppColors.blackOverlay,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Restaurar desde la base de datos predefinida incluida en ${DatabaseConfig.assetDbPath} del proyecto.',
                    style: TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restore),
                      label: const Text('RESTAURAR DESDE ASSETS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: BorderSide(color: AppColors.primaryBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _copyDatabaseFromAssets,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Opción 3: Exportar a JSON localmente
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.data_object,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Exportar tablas a JSON',
                          style: TextStyle(
                            color: AppColors.blackOverlay,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Genera un archivo .json por cada tabla de la base de datos y los guarda en una carpeta local con fecha y hora.',
                    style: TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download_for_offline),
                      label: const Text('EXPORTAR A JSON'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _exportToJsonLocally,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Estado/Mensaje
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _messageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _messageColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _messageColor == AppColors.primaryRed
                      ? Icons.error_outline
                      : Icons.info_outline,
                  color: _messageColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _message.isEmpty
                        ? 'Selecciona una opción para reemplazar la base de datos'
                        : _message,
                    style: TextStyle(
                      color: _messageColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                if (_message.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.copy, color: _messageColor, size: 20),
                    onPressed: () => _copyToClipboard(
                      _message,
                      successMessage: '📋 Mensaje copiado al portapapeles',
                    ),
                    tooltip: 'Copiar mensaje',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
              ],
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
          ],

          // Espacio adicional al final para evitar que el contenido quede muy pegado
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSqlAssistant() {
    final table = _selectedTable;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schema_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Asistente SQL: esquema y registros',
                  style: TextStyle(
                    color: AppColors.blackOverlay,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoadingSchema ? null : _loadDatabaseSchema,
                tooltip: 'Actualizar tablas y columnas',
                icon: _isLoadingSchema
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedTableName,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tabla',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            hint: const Text('No hay tablas disponibles'),
            items: _schemaTables
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.name,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: _schemaTables.isEmpty
                ? null
                : (value) {
                    final selected = _schemaTables.firstWhere(
                      (item) => item.name == value,
                    );
                    setState(() {
                      _selectedTableName = value;
                      _selectedColumnNames = selected.columns
                          .map((column) => column.name)
                          .toSet();
                    });
                  },
          ),
          if (table != null) ...[
            const SizedBox(height: 10),
            Text(
              'Columnas a consultar',
              style: TextStyle(
                color: AppColors.mediumGray,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: table.columns.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, index) {
                  final column = table.columns[index];
                  final selected = _selectedColumnNames.contains(column.name);
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: column.isPrimaryKey
                        ? const Icon(Icons.key_rounded, size: 15)
                        : null,
                    label: Text('${column.name} ${column.type}'.trim()),
                    tooltip: '${column.name} · ${column.type}',
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          _selectedColumnNames.add(column.name);
                        } else {
                          _selectedColumnNames.remove(column.name);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadSelectedRecords,
                  icon: const Icon(Icons.table_rows_outlined, size: 18),
                  label: const Text('Cargar hasta 100 registros'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _fillSqlTemplate('select'),
                  icon: const Icon(Icons.manage_search_outlined, size: 18),
                  label: const Text('Generar SELECT'),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Text(
            'Ayuda rápida: genera una plantilla, reemplaza los valores de ejemplo y ejecútala. '
            'UPDATE, INSERT y DELETE siempre pedirán confirmación.',
            style: TextStyle(
              color: AppColors.mediumGray,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: table == null
                    ? null
                    : () => _fillSqlTemplate('update'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('UPDATE registro'),
              ),
              OutlinedButton.icon(
                onPressed: table == null
                    ? null
                    : () => _fillSqlTemplate('insert'),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('INSERT registro'),
              ),
              OutlinedButton.icon(
                onPressed: table == null
                    ? null
                    : () => _fillSqlTemplate('delete'),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('DELETE registro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSQLTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Información de la plataforma para SQL Tab
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.darkGreen.withOpacity(0.1),
                          AppColors.darkGreen.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.darkGreen.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.darkGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getPlatformIcon(),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getCurrentPlatform()} - Consultas SQL',
                                style: TextStyle(
                                  color: AppColors.darkGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FutureBuilder<String>(
                                future: dbPath,
                                builder: (context, snapshot) {
                                  final dbName = snapshot.hasData
                                      ? snapshot.data!
                                            .split('/')
                                            .last
                                            .split('\\')
                                            .last
                                      : 'Cargando...';
                                  return Text(
                                    'Base de datos: $dbName',
                                    style: TextStyle(
                                      color: AppColors.mediumGray,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSqlAssistant(),
                  const SizedBox(height: 16),

                  if (_queryHistory.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Historial de consultas',
                                style: TextStyle(
                                  color: AppColors.blackOverlay,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_queryHistory.length} guardadas',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 160,
                            child: ListView.separated(
                              itemCount: _queryHistory.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final query = _queryHistory[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    query,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 20),
                                        color: AppColors.primaryBlue,
                                        tooltip: 'Copiar consulta',
                                        onPressed: () => _copyToClipboard(
                                          query,
                                          successMessage: '📋 Consulta copiada',
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_circle_left,
                                          size: 20,
                                        ),
                                        color: AppColors.blackOverlay,
                                        tooltip: 'Cargar consulta en el editor',
                                        onPressed: () {
                                          setState(() {
                                            _queryController.text = query;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blackOverlay.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        labelText: 'Escribe tu consulta SQL aquí',
                        labelStyle: TextStyle(
                          color: AppColors.mediumGray,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.play_circle_fill),
                          color: AppColors.primaryBlue,
                          iconSize: 36,
                          onPressed: _runQuery,
                        ),
                      ),
                      style: TextStyle(
                        color: AppColors.darkGray,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 24),
                          label: const Text(
                            'EJECUTAR CONSULTA',
                            style: TextStyle(fontSize: 15, letterSpacing: 0.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackOverlay,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _runQuery,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cleaning_services, size: 22),
                        label: const Text('LIMPIAR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.mediumGray,
                          side: BorderSide(color: AppColors.mediumGray),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _clearConsole,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _messageColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _messageColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _messageColor == AppColors.primaryRed
                              ? Icons.error_outline
                              : Icons.info_outline,
                          color: _messageColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _messageColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (_message.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.copy,
                              color: _messageColor,
                              size: 20,
                            ),
                            onPressed: () => _copyToClipboard(
                              _message,
                              successMessage:
                                  '📋 Mensaje copiado al portapapeles',
                            ),
                            tooltip: 'Copiar mensaje',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'RESULTADOS:',
                        style: TextStyle(
                          color: AppColors.blackOverlay,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      if (_queryResult.isNotEmpty) ...[
                        Text(
                          '${_queryResult.length} registros',
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.copy,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                          tooltip: 'Copiar resultados',
                          onSelected: (String value) {
                            switch (value) {
                              case 'completo':
                                _copyToClipboard(
                                  _generateResultsText(),
                                  successMessage:
                                      '📋 Resultados completos copiados (${_queryResult.length} registros)',
                                );
                                break;
                              case 'limpio':
                                _copyToClipboard(
                                  _generateCleanResultsText(),
                                  successMessage:
                                      '📋 Datos limpios copiados (CSV format)',
                                );
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'completo',
                                  child: Row(
                                    children: [
                                      Icon(Icons.article_outlined),
                                      SizedBox(width: 8),
                                      Text('Reporte completo'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'limpio',
                                  child: Row(
                                    children: [
                                      Icon(Icons.table_chart_outlined),
                                      SizedBox(width: 8),
                                      Text('Solo datos (CSV)'),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryRed,
                            ),
                          ),
                        )
                      : _buildResultConsole(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    _queryController.dispose();
    _verticalScroll.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightPastel,
      appBar: AppBar(
        backgroundColor: AppColors.blackOverlay,
        title: const Text(
          '🛠 Panel de Administración de DB',
          style: TextStyle(color: AppColors.lightPastel),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.download,
              size: 26,
              color: AppColors.lightPastel,
            ),
            onPressed: _exportDB,
            tooltip: 'Exportar base de datos',
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.lightPastel),
          onPressed: () => Navigator.pushNamed(context, '/dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.lightPastel,
          indicatorWeight: 3,
          labelColor: AppColors.lightPastel,
          unselectedLabelColor: AppColors.lightPastel.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.terminal), text: 'Consultas SQL'),
            Tab(
              icon: Icon(Icons.swap_horizontal_circle),
              text: 'Reemplazar DB',
            ),
            Tab(icon: Icon(Icons.cloud_upload), text: 'Backup Drive'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSQLTab(), _buildReplaceDBTab()],
      ),
    );
  }
}
