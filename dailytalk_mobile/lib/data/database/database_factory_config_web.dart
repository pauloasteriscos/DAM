import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Configuração da base de dados para Flutter Web.
///
/// No Web, o sqflite não inicializa automaticamente a factory.
/// Por isso, indicamos explicitamente a implementação Web baseada em WASM.
Future<void> configureDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}