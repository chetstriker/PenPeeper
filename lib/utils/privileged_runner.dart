import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class PrivilegedRunner {
  static String? _sessionPassword;

  static void setSessionPassword(String password) {
    _sessionPassword = password;
  }

  static void clearSessionPassword() {
    _sessionPassword = null;
  }

  static bool get hasPassword => _sessionPassword != null;

  static String? get sessionPassword => _sessionPassword;

  static Future<ProcessResult> run(String command, List<String> args) async {
    if (_sessionPassword == null) {
      throw Exception("Password not set! Prompt user first.");
    }

    final fullCommand = 'sudo -S $command ${args.join(" ")}';
    debugPrint('>>> PrivilegedRunner: Executing elevated command: $fullCommand');
    debugPrint('>>> PrivilegedRunner: Has password: ${_sessionPassword != null}');
    debugPrint('>>> PrivilegedRunner: Password length: ${_sessionPassword?.length ?? 0} chars');
    debugPrint('>>> PrivilegedRunner: Current working directory: ${Directory.current.path}');

    // CRITICAL FIX: Set working directory to a safe location instead of root (/)
    // When launched from Finder, the CWD is / which can cause sudo issues
    // Use the app's executable directory (where the app is running from)
    final workingDir = Directory.current.path == '/'
        ? path.dirname(Platform.resolvedExecutable)
        : Directory.current.path;
    debugPrint('>>> PrivilegedRunner: Using working directory: $workingDir');
    debugPrint('>>> PrivilegedRunner: Platform.resolvedExecutable: ${Platform.resolvedExecutable}');

    // CRITICAL FIX: Set up proper PATH environment
    // When launched from Finder/desktop launchers, PATH doesn't include Homebrew or other tools
    final currentPath = Platform.environment['PATH'] ?? '';

    // Add platform-specific paths
    String additionalPaths;
    if (Platform.isMacOS) {
      // macOS Homebrew paths (Apple Silicon and Intel)
      additionalPaths = '/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin';
    } else if (Platform.isLinux) {
      // Linux Homebrew (Linuxbrew) and standard paths
      additionalPaths = '/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:/usr/local/sbin';
    } else {
      // Fallback for other platforms
      additionalPaths = '/usr/local/bin:/usr/local/sbin';
    }

    final fullPath = '$additionalPaths:$currentPath';

    debugPrint('>>> PrivilegedRunner: Current PATH: $currentPath');
    debugPrint('>>> PrivilegedRunner: Enhanced PATH: $fullPath');

    final process = await Process.start(
      'sudo',
      ['-S', command, ...args],
      workingDirectory: workingDir,
      environment: {
        ...Platform.environment,
        'PATH': fullPath,
      },
    );
    debugPrint('>>> PrivilegedRunner: Process started successfully');

    // Start consuming streams immediately to prevent deadlocks
    final stdoutFuture = process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
    final stderrFuture = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();

    debugPrint('>>> PrivilegedRunner: Writing password to stdin...');
    try {
      process.stdin.writeln(_sessionPassword);
      await process.stdin.flush();
      debugPrint('>>> PrivilegedRunner: Password written and flushed to stdin');
    } catch (e) {
      debugPrint('>>> PrivilegedRunner: ERROR writing password to stdin: $e');
      // Ignore stdin errors (e.g. process exited quickly)
    } finally {
      await process.stdin.close();
      debugPrint('>>> PrivilegedRunner: Stdin closed');
    }

    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    final exitCode = await process.exitCode;

    debugPrint('>>> PrivilegedRunner: Command completed');
    debugPrint('>>> PrivilegedRunner: Exit code: $exitCode');
    debugPrint('>>> PrivilegedRunner: Stdout length: ${stdout.length} chars');
    debugPrint('>>> PrivilegedRunner: Stderr length: ${stderr.length} chars');
    if (stdout.isNotEmpty && stdout.length < 2000) {
      debugPrint('>>> PrivilegedRunner: Stdout content: $stdout');
    }
    if (exitCode != 0) {
      debugPrint('>>> PrivilegedRunner: ERROR - Command failed!');
      debugPrint('>>> PrivilegedRunner: Stderr content: $stderr');
      debugPrint('>>> PrivilegedRunner: Possible issue: sudo may not have a TTY or stdin is not working');
    }

    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }

  static Future<Process> start(String command, List<String> args) async {
    if (_sessionPassword == null) {
      throw Exception("Password not set! Prompt user first.");
    }

    debugPrint('>>> PrivilegedRunner.start(): Starting elevated process');
    debugPrint('>>> PrivilegedRunner.start(): Current working directory: ${Directory.current.path}');

    // CRITICAL FIX: Set working directory to a safe location instead of root (/)
    // When launched from Finder, the CWD is / which can cause sudo issues
    // Use the app's executable directory (where the app is running from)
    final workingDir = Directory.current.path == '/'
        ? path.dirname(Platform.resolvedExecutable)
        : Directory.current.path;
    debugPrint('>>> PrivilegedRunner.start(): Using working directory: $workingDir');
    debugPrint('>>> PrivilegedRunner.start(): Platform.resolvedExecutable: ${Platform.resolvedExecutable}');

    // CRITICAL FIX: Set up proper PATH environment
    // When launched from Finder/desktop launchers, PATH doesn't include Homebrew or other tools
    final currentPath = Platform.environment['PATH'] ?? '';

    // Add platform-specific paths
    String additionalPaths;
    if (Platform.isMacOS) {
      // macOS Homebrew paths (Apple Silicon and Intel)
      additionalPaths = '/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin';
    } else if (Platform.isLinux) {
      // Linux Homebrew (Linuxbrew) and standard paths
      additionalPaths = '/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:/usr/local/sbin';
    } else {
      // Fallback for other platforms
      additionalPaths = '/usr/local/bin:/usr/local/sbin';
    }

    final fullPath = '$additionalPaths:$currentPath';

    final process = await Process.start(
      'sudo',
      ['-S', command, ...args],
      workingDirectory: workingDir,
      environment: {
        ...Platform.environment,
        'PATH': fullPath,
      },
    );

    debugPrint('>>> PrivilegedRunner.start(): Process started, writing password to stdin');
    try {
      process.stdin.writeln(_sessionPassword);
      await process.stdin.flush();
      debugPrint('>>> PrivilegedRunner.start(): Password written and flushed successfully');
    } catch (e) {
      debugPrint('>>> PrivilegedRunner.start(): ERROR writing password: $e');
      // Ignore stdin errors
    }
    // Note: stdin is NOT closed here - the caller is responsible for closing it
    // This allows the caller to send additional input if needed

    return process;
  }
}
