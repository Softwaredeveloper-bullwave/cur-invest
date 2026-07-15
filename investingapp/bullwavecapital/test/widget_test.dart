import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bullwave_invest/core/api/token_storage.dart';
import 'package:bullwave_invest/features/profile/presentation/provider/app_provider.dart';
import 'package:bullwave_invest/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.init();
    final appProvider = await AppProvider.create();

    await tester.pumpWidget(BullWaveApp(appProvider: appProvider));
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
