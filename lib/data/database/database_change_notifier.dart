import 'dart:async';

/// Lightweight in-process pub/sub for "these tables changed" events.
///
/// sqflite has no built-in reactive/streaming query support (unlike drift),
/// which this stack doesn't use. DAOs call [notify] with the table(s) a
/// write touched; repositories turn that into `Stream<List<T>>` by
/// re-running their query whenever a relevant table fires. Scoped per Dart
/// isolate — the library scanner runs in its own isolate and forwards its
/// changes back to the main isolate explicitly (see `library_scanner.dart`)
/// rather than relying on this notifier being shared, which it isn't.
class DatabaseChangeNotifier {
  DatabaseChangeNotifier._();

  static final DatabaseChangeNotifier instance = DatabaseChangeNotifier._();

  final _controller = StreamController<Set<String>>.broadcast();

  Stream<Set<String>> get changes => _controller.stream;

  void notify(Set<String> tables) => _controller.add(tables);
}
