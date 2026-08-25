import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bullwave_invest/features/crypto/presentation/provider/crypto_market_provider.dart';
import 'package:bullwave_invest/features/crypto/presentation/screens/market_interest_screen.dart';

void main() {
  testWidgets('MarketInterestScreen builds', (WidgetTester tester) async {
    final provider = CryptoMarketProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<CryptoMarketProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: MarketInterestScreen(),
        ),
      ),
    );

    expect(find.text('Choose your market'), findsOneWidget);
    expect(find.text('🇮🇳 Indian Market'), findsOneWidget);
    expect(find.text('₿ Crypto Market'), findsOneWidget);
    expect(find.text('Continue to Indian Market'), findsOneWidget);
  });
}
