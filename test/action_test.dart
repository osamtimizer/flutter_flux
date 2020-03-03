// Copyright 2015 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@TestOn('vm')
import 'dart:async';

import 'package:flutter_flux/src/action.dart';
import 'package:test/test.dart';

void main() {
  group('Action', () {
    FluxAction<String> action;

    setUp(() {
      action = new FluxAction<String>();
    });

    test('should only be equivalent to itself', () {
      final FluxAction<Null> _action = new FluxAction<Null>();
      final FluxAction<Null> _action2 = new FluxAction<Null>();
      expect(_action == _action, isTrue);
      expect(_action == _action2, isFalse);
    });

    test('should support dispatch without a payload', () async {
      final Completer<Null> c = new Completer<Null>();
      final FluxAction<String> _action = new FluxAction<String>();

      _action.listen((String payload) {
        expect(payload, equals(null));
        c.complete();
      });

      _action();
      return c.future;
    });

    test('should support dispatch with a payload', () async {
      final Completer<Null> c = new Completer<Null>();
      action.listen((String payload) {
        expect(payload, equals('990 guerrero'));
        c.complete();
      });

      action('990 guerrero');
      return c.future;
    });

    test('should dispatch by default when called', () async {
      final Completer<Null> c = new Completer<Null>();
      action.listen((String payload) {
        expect(payload, equals('990 guerrero'));
        c.complete();
      });

      action('990 guerrero');
      return c.future;
    });

    group('dispatch', () {
      test(
          'should invoke and complete synchronous listeners in future event in '
          'event queue', () async {
        final FluxAction<Null> action = new FluxAction<Null>();
        bool listenerCompleted = false;
        action.listen((Null _) {
          listenerCompleted = true;
        });

        // No immediate invocation.
        action();
        expect(listenerCompleted, isFalse);

        // Invoked during the next scheduled event in the queue.
        await new Future<Null>(() {});
        expect(listenerCompleted, isTrue);
      });

      test(
          'should invoke asynchronous listeners in future event and complete '
          'in another future event', () async {
        final FluxAction<Null> action = new FluxAction<Null>();
        bool listenerInvoked = false;
        bool listenerCompleted = false;
        action.listen((Null _) async {
          listenerInvoked = true;
          await new Future<Null>(() {
            listenerCompleted = true;
          });
        });

        // No immediate invocation.
        action();
        expect(listenerInvoked, isFalse);

        // Invoked during next scheduled event in the queue.
        await new Future<Null>(() {});
        expect(listenerInvoked, isTrue);
        expect(listenerCompleted, isFalse);

        // Completed in next next scheduled event.
        await new Future<Null>(() {});
        expect(listenerCompleted, isTrue);
      });

      test('should complete future after listeners complete', () async {
        final FluxAction<Null> action = new FluxAction<Null>();
        bool asyncListenerCompleted = false;
        action.listen((Null _) async {
          await new Future<Null>.delayed(new Duration(milliseconds: 100), () {
            asyncListenerCompleted = true;
          });
        });

        final Future<List<dynamic>> future = action.call();
        expect(asyncListenerCompleted, isFalse);

        await future;
        expect(asyncListenerCompleted, isTrue);
      });

      test('should surface errors in listeners', () {
        FluxAction<int> action = new FluxAction<int>();
        action.listen((int _) => throw new UnimplementedError());
        expect(action(0), throwsUnimplementedError);
      });
    });

    group('listen', () {
      test('should stop listening when subscription is canceled', () async {
        FluxAction<Null> action = new FluxAction<Null>();
        bool listened = false;
        ActionSubscription subscription = action.listen((Null _) => listened = true);

        await action();
        expect(listened, isTrue);

        listened = false;
        subscription.cancel();
        await action();
        expect(listened, isFalse);
      });

      test('should stop listening when listeners are cleared', () async {
        final FluxAction<Null> action = new FluxAction<Null>();
        bool listened = false;
        action.listen((Null _) => listened = true);

        await action();
        expect(listened, isTrue);

        listened = false;
        action.clearListeners();
        await action();
        expect(listened, isFalse);
      });
    });

    group('benchmarks', () {
      test('should dispatch actions faster than streams :(', () async {
        const int sampleSize = 1000;
        final Stopwatch stopwatch = new Stopwatch();

        final FluxAction<Null> awaitableAction = new FluxAction<Null>();
        awaitableAction.listen((Null _) {});
        awaitableAction.listen((Null _) async {});
        stopwatch.start();
        for (int i = 0; i < sampleSize; i++) {
          await awaitableAction();
        }
        stopwatch.stop();
        double averageActionDispatchTime =
            stopwatch.elapsedMicroseconds / sampleSize / 1000.0;

        stopwatch.reset();

        Completer<Null> syncCompleter;
        Completer<Null> asyncCompleter;
        FluxAction<Null> action = new FluxAction<Null>();
        action.listen((Null _) => syncCompleter.complete());
        action.listen((Null _) async {
          asyncCompleter.complete();
        });
        stopwatch.start();
        for (int i = 0; i < sampleSize; i++) {
          final Completer<Null> syncCompleter = new Completer<Null>();
          final Completer<Null> asyncCompleter = new Completer<Null>();
          action();
          await Future.wait(
              <Future<Null>>[syncCompleter.future, asyncCompleter.future]);
        }
        stopwatch.stop();
        final double averageStreamDispatchTime =
            stopwatch.elapsedMicroseconds / sampleSize / 1000.0;

        print('awaitable action (ms): $averageActionDispatchTime; '
            'stream-based action (ms): $averageStreamDispatchTime');
      }, skip: true);
    });
  });
}
