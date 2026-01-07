import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const dbPath = r'C:\Users\nut19\AppData\Roaming\com.enki.wordmomo\WordMomo\accounts\3fcffc5a-50b6-42e2-9609-ab4abe6a4135\data.db';
  final db = await openDatabase(dbPath, readOnly: true);

  final tables = await db.rawQuery("SELECT name, sql FROM sqlite_master WHERE type='table'");
  
  final buffer = StringBuffer();
  buffer.writeln('--- DATABASE SCHEMA DUMP ---');
  for (var table in tables) {
    buffer.writeln('\nTable: ${table['name']}');
    buffer.writeln('SQL: ${table['sql']}');
  }
  
  final outputFile = File(r'D:\nixiang_app\WordMomo_Clone\original_schema.txt');
  await outputFile.writeAsString(buffer.toString());
  debugPrint('Schema dumped to ${outputFile.path}');
  
  await db.close();
}
