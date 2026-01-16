/// Database command types for isolate communication
enum DatabaseCommandType {
  insert,
  update,
  delete,
  execute,
  transaction,
  shutdown,
}

/// Base command sent from UI isolate to DB isolate
class DatabaseCommand {
  final DatabaseCommandType type;
  final String? table;
  final Map<String, dynamic>? values;
  final String? where;
  final List<dynamic>? whereArgs;
  final String? sql;
  final List<dynamic>? arguments;
  final List<DatabaseCommand>? transactionCommands;
  final int requestId;

  DatabaseCommand({
    required this.type,
    this.table,
    this.values,
    this.where,
    this.whereArgs,
    this.sql,
    this.arguments,
    this.transactionCommands,
    required this.requestId,
  });

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'table': table,
        'values': values,
        'where': where,
        'whereArgs': whereArgs,
        'sql': sql,
        'arguments': arguments,
        'transactionCommands': transactionCommands?.map((c) => c.toJson()).toList(),
        'requestId': requestId,
      };

  factory DatabaseCommand.fromJson(Map<String, dynamic> json) {
    return DatabaseCommand(
      type: DatabaseCommandType.values[json['type'] as int],
      table: json['table'] as String?,
      values: json['values'] as Map<String, dynamic>?,
      where: json['where'] as String?,
      whereArgs: json['whereArgs'] as List<dynamic>?,
      sql: json['sql'] as String?,
      arguments: json['arguments'] as List<dynamic>?,
      transactionCommands: (json['transactionCommands'] as List<dynamic>?)
          ?.map((c) => DatabaseCommand.fromJson(c as Map<String, dynamic>))
          .toList(),
      requestId: json['requestId'] as int,
    );
  }
}

/// Response sent from DB isolate to UI isolate
class DatabaseResponse {
  final int requestId;
  final dynamic result;
  final String? error;
  final String? stackTrace;

  DatabaseResponse({
    required this.requestId,
    this.result,
    this.error,
    this.stackTrace,
  });

  bool get isSuccess => error == null;

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'result': result,
        'error': error,
        'stackTrace': stackTrace,
      };

  factory DatabaseResponse.fromJson(Map<String, dynamic> json) {
    return DatabaseResponse(
      requestId: json['requestId'] as int,
      result: json['result'],
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  factory DatabaseResponse.success(int requestId, dynamic result) {
    return DatabaseResponse(requestId: requestId, result: result);
  }

  factory DatabaseResponse.error(
    int requestId,
    String error, {
    String? stackTrace,
  }) {
    return DatabaseResponse(
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
