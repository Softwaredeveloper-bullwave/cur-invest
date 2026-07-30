import 'package:bullwave_invest/core/theme/app_theme_extension.dart';
import 'package:bullwave_invest/core/widgets/otp_box.dart';
import 'package:bullwave_invest/features/authentication/presentation/widgets/premium_auth_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OTP digits use high-contrast dark auth colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PremiumAuthShell(child: Center(child: ModernOtpInput())),
      ),
    );

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();

    final firstDigit = tester.widget<Text>(find.text('1'));
    expect(firstDigit.style?.color, AppThemeExtension.dark.textPrimary);
  });
}
