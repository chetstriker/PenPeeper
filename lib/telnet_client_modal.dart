import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:penpeeper/theme_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class TelnetClientModal extends StatefulWidget {
  final String ipAddress;
  final List<int> telnetPorts;

  const TelnetClientModal({
    super.key,
    required this.ipAddress,
    required this.telnetPorts,
  });

  @override
  State<TelnetClientModal> createState() => _TelnetClientModalState();
}

class _TelnetClientModalState extends State<TelnetClientModal> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _output = '';
  int? _selectedPort;
  Socket? _socket;
  WebSocketChannel? _webSocket;
  bool _isConnected = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.telnetPorts.length == 1) {
      _selectedPort = widget.telnetPorts.first;
      _connect();
    }
  }

  Future<void> _connect() async {
    if (_selectedPort == null) return;

    if (kIsWeb) {
      try {
        final wsUrl = Uri.parse('ws://${Uri.base.host}:${Uri.base.port}/ws/telnet');
        _webSocket = WebSocketChannel.connect(wsUrl);
        
        _subscription = _webSocket!.stream.listen((message) {
          if (mounted) {
            final data = json.decode(message);
            setState(() {
              if (data['type'] == 'connected') {
                _isConnected = true;
                _output += '${data['message']}\n';
              } else if (data['type'] == 'data') {
                _output += data['data'];
              } else if (data['type'] == 'error') {
                _output += 'Error: ${data['message']}\n';
              } else if (data['type'] == 'disconnected') {
                _isConnected = false;
                _output += 'Disconnected\n';
              }
            });
            _scrollToBottom();
          }
        });
        
        _webSocket!.sink.add(json.encode({
          'command': 'connect',
          'host': widget.ipAddress,
          'port': _selectedPort,
        }));
      } catch (e) {
        if (mounted) {
          setState(() {
            _output += 'Connection failed: $e\n';
          });
        }
      }
    } else {
      try {
        _socket = await Socket.connect(widget.ipAddress, _selectedPort!);
        
        _subscription = _socket!.listen(
          (data) {
            if (mounted) {
              setState(() {
                _output += String.fromCharCodes(data);
              });
              _scrollToBottom();
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isConnected = false;
                _output += 'Connection error: $error\n';
              });
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isConnected = false;
                _output += 'Connection closed by remote host\n';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _isConnected = true;
            _output += 'Connected to ${widget.ipAddress}:$_selectedPort\n';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _output += 'Connection failed: $e\n';
          });
        }
      }
    }
  }

  void _sendCommand() {
    if (!_isConnected) return;
    
    final command = _commandController.text;
    try {
      if (kIsWeb) {
        _webSocket?.sink.add(json.encode({
          'command': 'send',
          'text': command,
        }));
      } else {
        _socket?.write('$command\r\n');
      }
      if (mounted && command.isNotEmpty) {
        setState(() {
          _output += '> $command\n';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _output += 'Send failed: $e\n';
        });
      }
    }
    _commandController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _disconnect() async {
    if (kIsWeb) {
      _webSocket?.sink.add(json.encode({'command': 'disconnect'}));
      await _webSocket?.sink.close();
    }
    await _subscription?.cancel();
    await _socket?.close();
    if (mounted) {
      setState(() {
        _isConnected = false;
        _output += '\nDisconnected\n';
      });
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _socket?.close();
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.scaffoldBackground,
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(AppTheme.terminalIcon, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Telnet Client - ${widget.ipAddress}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(AppTheme.closeIcon, color: AppTheme.textTertiary),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (!_isConnected && widget.telnetPorts.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Text('Port:', style: TextStyle(color: AppTheme.textTertiary)),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _selectedPort,
                      hint: const Text('Select port'),
                      dropdownColor: const Color(0xFF2B2B2B),
                      items: widget.telnetPorts.map((port) {
                        return DropdownMenuItem(
                          value: port,
                          child: Text('$port'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPort = value;
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _selectedPort != null ? _connect : null,
                      icon: Icon(AppTheme.linkIcon, size: 18),
                      label: const Text('Connect'),
                    ),
                  ],
                ),
              ),
            
            Expanded(
              child: GradientBorderContainer(
                borderConfig: AppTheme.terminalBorderGradient ?? const Color(0xFF30363D),
                borderRadius: 8,
                borderWidth: 1,
                backgroundColor: const Color(0xFF0D1117),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      _output,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        color: Color(0xFFE6EDF3),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    enabled: _isConnected,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter command...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isConnected ? _sendCommand : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Send', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isConnected ? _disconnect : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDA3633),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Close Connection', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
