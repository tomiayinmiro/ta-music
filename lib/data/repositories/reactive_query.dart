import '../database/database_change_notifier.dart';

/// Turns a one-shot DAO query into a live stream: emits immediately, then
/// re-runs whenever [DatabaseChangeNotifier] reports a write to any table
/// in [tables]. The reactive-streams-over-sqflite pattern used by every
/// repository — see `database_change_notifier.dart` for why this exists
/// instead of a reactive query layer like drift.
Stream<T> watchQuery<T>(Set<String> tables, Future<T> Function() query) async* {
  yield await query();
  await for (final changed in DatabaseChangeNotifier.instance.changes) {
    if (changed.intersection(tables).isNotEmpty) {
      yield await query();
    }
  }
}
