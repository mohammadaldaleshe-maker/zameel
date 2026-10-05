import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/services/preview_task_queue.dart';

void main() {
  test('front preview gets priority and decoding stays bounded', () async {
    final queue = PreviewTaskQueue();
    final release = Completer<void>();
    final order = <String>[];
    Future<void> task(String label) async {
      order.add(label);
      await release.future;
    }

    final a = queue.add(() => task('neighbour'));
    final b = queue.add(() => task('other'));
    final c = queue.add(() => task('front'), priority: true);
    await Future<void>.delayed(Duration.zero);
    expect(order, ['front', 'neighbour']);
    release.complete();
    await Future.wait([a, b, c]);
    expect(order, ['front', 'neighbour', 'other']);
  });
  test('failed preview releases its slot for the next task', () async {
    final queue = PreviewTaskQueue(parallelism: 1);
    final fail = queue.add(() async => throw StateError('decode failed'));
    var completed = false;
    final next = queue.add(() async {
      completed = true;
    });
    await expectLater(fail, throwsStateError);
    await next;
    expect(completed, isTrue);
  });
}
