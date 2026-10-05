import 'dart:async';

/// Two decoder jobs at most; the front card is prepared before neighbours.
class PreviewTaskQueue {
  PreviewTaskQueue({this.parallelism = 2});
  final int parallelism;
  int _running = 0;
  bool _scheduled = false;
  final _pending = <({
    bool priority,
    Future<void> Function() task,
    Completer<void> completion
  })>[];

  Future<void> add(Future<void> Function() task, {bool priority = false}) {
    final completion = Completer<void>();
    final job = (priority: priority, task: task, completion: completion);
    if (priority) {
      final index = _pending.indexWhere((item) => !item.priority);
      _pending.insert(index < 0 ? _pending.length : index, job);
    } else {
      _pending.add(job);
    }
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(() {
        _scheduled = false;
        _drain();
      });
    }
    return completion.future;
  }

  void _drain() {
    while (_running < parallelism && _pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      _running++;
      Future<void>.sync(job.task).then((_) {
        job.completion.complete();
      }, onError: (Object error, StackTrace stack) {
        job.completion.completeError(error, stack);
      }).whenComplete(() {
        _running--;
        _drain();
      });
    }
  }
}
