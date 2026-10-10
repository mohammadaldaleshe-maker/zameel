import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/widgets/bottom_system_inset.dart';

void main() {
  for (final bottom in [0.0, 24.0, 48.0]) {
    for (final keyboard in [0.0, 300.0]) {
      testWidgets('navigation $bottom keyboard $keyboard reserves bottom once',
          (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final padding = keyboard == 0 ? bottom : 0.0;
        const marker = Key('composer');
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: EdgeInsets.only(bottom: padding),
                    viewPadding: EdgeInsets.only(bottom: bottom),
                    viewInsets: EdgeInsets.only(bottom: keyboard)),
                child: BottomSystemInset(child: child!)),
            home: Scaffold(
                body: Column(children: [
              const Expanded(child: SizedBox()),
              SafeArea(top: false, child: Container(key: marker, height: 48))
            ]))));
        expect(tester.getBottomLeft(find.byKey(marker)).dy,
            closeTo(800 - keyboard - padding, .01));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
