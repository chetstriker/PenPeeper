import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/services/config_service.dart';

class MacOSPasswordPrompt {
  static Future<bool> promptIfNeeded(BuildContext context) async {
    print('=== MacOSPasswordPrompt.promptIfNeeded CALLED ===');
    print('Platform - isMacOS: ${ConfigService.isMacOS}, isLinux: ${ConfigService.isLinux}, isWeb: $kIsWeb');
    print('PrivilegedRunner.hasPassword: ${PrivilegedRunner.hasPassword}');

    // Prompt for password on macOS, Linux, and Web if not already set
    if ((ConfigService.isMacOS || ConfigService.isLinux || kIsWeb) && !PrivilegedRunner.hasPassword) {
      print('PASSWORD PROMPT REQUIRED - showing dialog');

      final passwordController = TextEditingController();
      final osName = kIsWeb ? 'server' : (ConfigService.isMacOS ? 'macOS' : 'Linux');
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Administrator Access Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Security scanning tools require administrator privileges.\n\n'
                'Your password will be stored in memory for this session only.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your $osName password',
                ),
                onSubmitted: (value) => Navigator.pop(context, true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (result == true && passwordController.text.isNotEmpty) {
        print('Password entered successfully - storing in PrivilegedRunner');
        PrivilegedRunner.setSessionPassword(passwordController.text);
        
        // Send password to server in web mode
        if (kIsWeb) {
          try {
            print('Sending password to server...');
            final response = await http.post(
              Uri.parse('${ApiDatabaseHelper.baseUrl}/set-session-password'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'password': passwordController.text}),
            );
            if (response.statusCode == 200) {
              print('Password sent to server successfully');
            } else {
              print('Failed to send password to server: ${response.statusCode}');
            }
          } catch (e) {
            print('Error sending password to server: $e');
          }
        }
        
        print('Password stored - length: ${passwordController.text.length} chars');
        print('===========================================');
        return true;
      }

      print('Password prompt cancelled or empty');
      print('===========================================');
      return false;
    }

    print('Skipping password prompt - already has password');
    print('===========================================');
    return true;
  }
}
