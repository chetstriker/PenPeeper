import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketHandler {
  static void handleTelnet(WebSocketChannel webSocket) async {
    Socket? telnetSocket;
    StreamSubscription? telnetSubscription;
    
    webSocket.stream.listen((message) async {
      try {
        final data = json.decode(message);
        final command = data['command'];
        
        if (command == 'connect') {
          final host = data['host'];
          final port = data['port'];
          
          try {
            telnetSocket = await Socket.connect(host, port);
            webSocket.sink.add(json.encode({'type': 'connected', 'message': 'Connected to $host:$port'}));
            
            telnetSubscription = telnetSocket!.listen((data) {
              webSocket.sink.add(json.encode({'type': 'data', 'data': String.fromCharCodes(data)}));
            }, onError: (error) {
              webSocket.sink.add(json.encode({'type': 'error', 'message': error.toString()}));
            });
          } catch (e) {
            webSocket.sink.add(json.encode({'type': 'error', 'message': 'Connection failed: $e'}));
          }
        } else if (command == 'send') {
          final text = data['text'];
          telnetSocket?.write('$text\r\n');
        } else if (command == 'disconnect') {
          await telnetSubscription?.cancel();
          await telnetSocket?.close();
          webSocket.sink.add(json.encode({'type': 'disconnected'}));
        }
      } catch (e) {
        webSocket.sink.add(json.encode({'type': 'error', 'message': e.toString()}));
      }
    }, onDone: () async {
      await telnetSubscription?.cancel();
      await telnetSocket?.close();
    });
  }
}
