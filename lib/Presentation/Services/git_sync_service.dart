// ignore_for_file: avoid_print

import 'dart:io';

/// Resultado de una operación git.
class GitOperationResult {
  final bool success;
  final String stdout;
  final String stderr;
  final int exitCode;
  final String command;

  const GitOperationResult({
    required this.success,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.command,
  });

  @override
  String toString() =>
      '[Git] $command → exit=$exitCode '
      '${success ? "✅" : "❌"}'
      '${stderr.isNotEmpty ? "\nstderr: $stderr" : ""}';
}

/// Entrada del log de sincronización git.
class GitSyncLogEntry {
  final DateTime timestamp;
  final String operation;
  final bool success;
  final String? error;

  const GitSyncLogEntry({
    required this.timestamp,
    required this.operation,
    required this.success,
    this.error,
  });

  @override
  String toString() {
    final status = success ? '✅' : '❌';
    final ts = timestamp.toLocal().toIso8601String();
    return '$ts $status $operation${error != null ? " — $error" : ""}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Servicio git — ejecuta comandos git desde Flutter Desktop
// ─────────────────────────────────────────────────────────────────────────────

/// Ejecuta comandos git nativos mediante [Process.run].
/// Solo disponible en Flutter Desktop (macOS, Windows, Linux).
///
/// Flujo estándar de publicación:
///   1. [status]  → detectar si hay cambios
///   2. [addAll]  → git add .
///   3. [commit]  → git commit -m "catalog update:
///   < timestamp >"
///   4. [push]    → git push
///
/// Recuperación ante errores:
///   • Si [push] falla por divergencia → [pull] + reintento automático.
///   • Máximo [maxRetries] intentos de push.
class GitSyncService {
  final String repoPath;
  final int maxRetries;

  // Log interno de operaciones de esta sesión.
  final List<GitSyncLogEntry> _log = [];

  /// [repoPath] debe apuntar a la raíz del repositorio GitHub Pages
  /// (donde existe la carpeta .git/).
  GitSyncService({required this.repoPath, this.maxRetries = 3});

  // ── API pública ────────────────────────────────────────────────────────────

  /// Verifica si hay archivos modificados. Retorna true cuando hay cambios.
  Future<bool> hasChanges() async {
    final result = await _run('git', ['status', '--porcelain']);
    return result.success && result.stdout.trim().isNotEmpty;
  }

  /// git status completo (para depuración).
  Future<GitOperationResult> status() => _run('git', ['status']);

  /// git add .
  Future<GitOperationResult> addAll() => _run('git', ['add', '.']);

  /// git commit -m "< message>".
  Future<GitOperationResult> commit(String message) =>
      _run('git', ['commit', '-m', message]);

  /// git push con reintentos y recuperación por divergencia.
  Future<GitOperationResult> push() async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await _run('git', ['push']);

      if (result.success) return result;

      print('[GitSyncService] Push falló (intento $attempt/$maxRetries):'
          ' ${result.stderr}');

      // Recuperación: divergencia detectada → pull --rebase y reintentar.
      if (_isDivergenceError(result.stderr)) {
        print('[GitSyncService] Detectada divergencia → git pull --rebase');
        final pullResult = await _run('git', ['pull', '--rebase']);
        if (!pullResult.success) {
          _addLog('pull --rebase', false, pullResult.stderr);
          return pullResult;
        }
        _addLog('pull --rebase', true);
        continue;
      }

      // Error no recuperable.
      if (attempt == maxRetries) return result;

      // Espera exponencial entre reintentos.
      await Future.delayed(Duration(seconds: 2 * attempt));
    }

    return GitOperationResult(
      success: false,
      stdout: '',
      stderr: 'Máximo de reintentos ($maxRetries) alcanzado.',
      exitCode: -1,
      command: 'git push',
    );
  }

  /// Flujo completo: add → commit → push.
  /// Retorna el [GitOperationResult] de la operación fallida, o el push si todo OK.
  Future<GitOperationResult> publishCatalog({String? commitMessage}) async {
    final message = commitMessage ??
        'catalog update: ${DateTime.now().toUtc().toIso8601String()}';

    // 1. ¿Hay cambios?
    final changes = await hasChanges();
    if (!changes) {
      print('[GitSyncService] Sin cambios que publicar.');
      _addLog('publishCatalog', true);
      return const GitOperationResult(
        success: true,
        stdout: 'Sin cambios.',
        stderr: '',
        exitCode: 0,
        command: 'git status',
      );
    }

    // 2. git add .
    final addResult = await addAll();
    if (!addResult.success) {
      _addLog('git add', false, addResult.stderr);
      return addResult;
    }
    _addLog('git add', true);

    // 3. git commit
    final commitResult = await commit(message);
    if (!commitResult.success) {
      // "nothing to commit" no es un error real.
      if (commitResult.stdout.contains('nothing to commit') ||
          commitResult.stderr.contains('nothing to commit')) {
        print('[GitSyncService] Nothing to commit — omitiendo push.');
        _addLog('git commit', true);
        return commitResult;
      }
      _addLog('git commit', false, commitResult.stderr);
      return commitResult;
    }
    _addLog('git commit', true);

    // 4. git push
    final pushResult = await push();
    _addLog('git push', pushResult.success, pushResult.stderr);
    return pushResult;
  }

  /// Historial de operaciones de esta instancia.
  List<GitSyncLogEntry> get log => List.unmodifiable(_log);

  /// Muestra el log por consola (útil para depuración).
  void printLog() {
    print('\n─── Git Sync Log ──────────────────────────');
    for (final entry in _log) {
      print(entry.toString());
    }
    print('───────────────────────────────────────────\n');
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  Future<GitOperationResult> _run(
    String executable,
    List<String> arguments,
  ) async {
    final command = '$executable ${arguments.join(' ')}';
    print('[GitSyncService] Ejecutando: $command (en $repoPath)');

    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: repoPath,
        runInShell: Platform.isWindows,
      );

      final out = result.stdout as String? ?? '';
      final err = result.stderr as String? ?? '';
      final exitCode = result.exitCode;
      final success = exitCode == 0;

      if (!success) {
        print('[GitSyncService] ❌ exit=$exitCode\nstderr: $err');
      }

      return GitOperationResult(
        success: success,
        stdout: out,
        stderr: err,
        exitCode: exitCode,
        command: command,
      );
    } on ProcessException catch (e) {
      final msg = 'ProcessException: ${e.message}';
      print('[GitSyncService] ❌ $msg');
      return GitOperationResult(
        success: false,
        stdout: '',
        stderr: msg,
        exitCode: -1,
        command: command,
      );
    } catch (e) {
      final msg = e.toString();
      print('[GitSyncService] ❌ Error inesperado: $msg');
      return GitOperationResult(
        success: false,
        stdout: '',
        stderr: msg,
        exitCode: -1,
        command: command,
      );
    }
  }

  bool _isDivergenceError(String stderr) =>
      stderr.contains('fetch first') ||
      stderr.contains('non-fast-forward') ||
      stderr.contains('rejected') ||
      stderr.contains('diverged');

  void _addLog(String operation, bool success, [String? error]) {
    _log.add(GitSyncLogEntry(
      timestamp: DateTime.now(),
      operation: operation,
      success: success,
      error: error?.isNotEmpty == true ? error : null,
    ));
  }
}
