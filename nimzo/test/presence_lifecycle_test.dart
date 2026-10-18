import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/presence_service.dart';

void main() {
  testWidgets(
      'background state follows a pending heartbeat and disposal stops repeats',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final calls = <bool>[];
    final first = Completer<void>();
    final heartbeat = PresenceHeartbeat((online) {
      calls.add(online);
      return calls.length == 1 ? first.future : Future.value();
    });
    await tester.pump();
    expect(calls, [true]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls, [true]);
    first.complete();
    await tester.pump();
    expect(calls, [true, false]);
    heartbeat.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 61));
    expect(calls, [true, false]);
  });
}
