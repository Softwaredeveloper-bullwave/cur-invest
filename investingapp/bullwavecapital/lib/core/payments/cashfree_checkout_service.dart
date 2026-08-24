import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentcomponents/cfpaymentcomponent.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

import '../../features/kyc/data/payment_repository.dart';
import '../../features/kyc/domain/kyc_models.dart';

enum CashfreeCheckoutStatus {
  success,
  failed,
  cancelled,
  unavailable,
  redirected,
}

class CashfreeCheckoutResult {
  final CashfreeCheckoutStatus status;
  final String orderId;
  final String message;
  final double balance;

  const CashfreeCheckoutResult({
    required this.status,
    required this.orderId,
    this.message = '',
    this.balance = 0,
  });
}

/// Cashfree PG checkout for wallet deposits.
class CashfreeCheckoutService {
  CashfreeCheckoutService._();

  static final CashfreeCheckoutService instance = CashfreeCheckoutService._();
  final _payments = PaymentRepository();
  final _gateway = CFPaymentGatewayService();

  /// True when Cashfree accepts a redirect return URL (production requires HTTPS).
  static bool get canUseRedirectReturnUrl =>
      !kIsWeb || Uri.base.scheme == 'https';

  Future<CashfreeCheckoutResult> startCheckout(
    PaymentSessionModel session,
  ) async {
    if (session.devMode && session.success) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.success,
        orderId: session.orderId,
        message: session.message,
      );
    }

    if (session.paymentSessionId.isEmpty || session.orderId.isEmpty) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.failed,
        orderId: session.orderId,
        message: 'Cashfree payment session was not created.',
      );
    }

    if (kIsWeb) {
      if (canUseRedirectReturnUrl) {
        return _startWebRedirectCheckout(session);
      }
      return _startWebDropCheckout(session);
    }

    return _startNativeCheckout(session);
  }

  Future<CashfreeCheckoutResult> confirmOrder(String orderId) {
    return _confirmAndCredit(orderId);
  }

  Future<CashfreeCheckoutResult> _startWebRedirectCheckout(
    PaymentSessionModel session,
  ) async {
    try {
      _gateway.setCallback((_) {}, (_, __) {});

      final cfSession = _buildSession(session);
      final payment = CFWebCheckoutPaymentBuilder()
          .setSession(cfSession)
          .build();
      _gateway.doPayment(payment);

      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.redirected,
        orderId: session.orderId,
        message: 'Redirecting to Cashfree checkout…',
      );
    } on CFException catch (error) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.failed,
        orderId: session.orderId,
        message: error.message,
      );
    } catch (error) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.failed,
        orderId: session.orderId,
        message: error.toString(),
      );
    }
  }

  /// In-app modal checkout for local http:// dev (no HTTPS return URL required).
  Future<CashfreeCheckoutResult> _startWebDropCheckout(
    PaymentSessionModel session,
  ) async {
    try {
      final completer = Completer<CashfreeCheckoutResult>();
      _gateway.setCallback(
        (orderId) {
          if (!completer.isCompleted) {
            completer.complete(
              CashfreeCheckoutResult(
                status: CashfreeCheckoutStatus.success,
                orderId: orderId,
              ),
            );
          }
        },
        (CFErrorResponse error, String orderId) {
          if (!completer.isCompleted) {
            completer.complete(
              CashfreeCheckoutResult(
                status: CashfreeCheckoutStatus.failed,
                orderId: orderId,
                message: error.getMessage() ?? 'Payment failed.',
              ),
            );
          }
        },
      );

      final cfSession = _buildSession(session);
      final payment = CFDropCheckoutPaymentBuilder()
          .setSession(cfSession)
          .setPaymentComponent(
            CFPaymentComponentBuilder().setComponents([
              CFPaymentModes.UPI,
              CFPaymentModes.CARD,
              CFPaymentModes.NETBANKING,
              CFPaymentModes.WALLET,
            ]).build(),
          )
          .setTheme(
            CFThemeBuilder()
                .setNavigationBarBackgroundColorColor('#111111')
                .setButtonBackgroundColor('#C8F038')
                .setButtonTextColor('#111111')
                .build(),
          )
          .build();
      _gateway.doPayment(payment);

      final sdkResult = await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => CashfreeCheckoutResult(
          status: CashfreeCheckoutStatus.cancelled,
          orderId: session.orderId,
          message: 'Payment timed out.',
        ),
      );

      if (sdkResult.status != CashfreeCheckoutStatus.success) {
        return sdkResult;
      }

      return _confirmAndCredit(session.orderId);
    } on CFException catch (error) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.failed,
        orderId: session.orderId,
        message: error.message,
      );
    } catch (error) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.failed,
        orderId: session.orderId,
        message: error.toString(),
      );
    }
  }

  Future<CashfreeCheckoutResult> _startNativeCheckout(
    PaymentSessionModel session,
  ) async {
    try {
      final completer = Completer<CashfreeCheckoutResult>();
      _gateway.setCallback(
        (orderId) {
          if (!completer.isCompleted) {
            completer.complete(
              CashfreeCheckoutResult(
                status: CashfreeCheckoutStatus.success,
                orderId: orderId,
              ),
            );
          }
        },
        (CFErrorResponse error, String orderId) {
          if (!completer.isCompleted) {
            completer.complete(
              CashfreeCheckoutResult(
                status: CashfreeCheckoutStatus.failed,
                orderId: orderId,
                message: error.getMessage() ?? 'Payment failed.',
              ),
            );
          }
        },
      );

      final cfSession = _buildSession(session);
      final payment = CFWebCheckoutPaymentBuilder()
          .setSession(cfSession)
          .build();
      _gateway.doPayment(payment);

      final sdkResult = await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => CashfreeCheckoutResult(
          status: CashfreeCheckoutStatus.cancelled,
          orderId: session.orderId,
          message: 'Payment timed out.',
        ),
      );

      if (sdkResult.status != CashfreeCheckoutStatus.success) {
        return sdkResult;
      }

      return _confirmAndCredit(session.orderId);
    } on CFException catch (error) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.failed,
        orderId: session.orderId,
        message: error.message,
      );
    } catch (error) {
      return CashfreeCheckoutResult(
        status: CashfreeCheckoutStatus.failed,
        orderId: session.orderId,
        message: error.toString(),
      );
    }
  }

  CFSession _buildSession(PaymentSessionModel session) {
    final env = session.environment.toUpperCase() == 'PRODUCTION'
        ? CFEnvironment.PRODUCTION
        : CFEnvironment.SANDBOX;
    return CFSessionBuilder()
        .setEnvironment(env)
        .setOrderId(session.orderId)
        .setPaymentSessionId(session.paymentSessionId)
        .build();
  }

  Future<CashfreeCheckoutResult> _confirmAndCredit(String orderId) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      try {
        final data = await _payments.verifyPayment(orderId);
        if (data['success'] == true) {
          return CashfreeCheckoutResult(
            status: CashfreeCheckoutStatus.success,
            orderId: orderId,
            balance: (data['balance'] as num?)?.toDouble() ?? 0,
          );
        }
      } catch (_) {
        // Payment may still be settling — retry.
      }
    }
    return CashfreeCheckoutResult(
      status: CashfreeCheckoutStatus.unavailable,
      orderId: orderId,
      message:
          'Payment received — pull to refresh your wallet if balance is not updated yet.',
    );
  }
}
