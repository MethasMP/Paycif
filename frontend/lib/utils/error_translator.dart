import 'package:frontend/l10n/generated/app_localizations.dart';

class ErrorTranslator {
  /// Translates technical error messages from Omise or Backend into human-friendly localized strings.
  static String translate(AppLocalizations l10n, String technicalMessage) {
    final msg = technicalMessage.toLowerCase();

    // 1. Omise Tokenization / Card Errors
    if (msg.contains('invalid_card') || msg.contains('number is invalid')) {
      return l10n.errorCardInvalid;
    }
    if (msg.contains('expired_card') || msg.contains('card is expired')) {
      return l10n.errorExpiredCard;
    }
    if (msg.contains('brand_not_supported')) {
      return l10n.errorBrandNotSupported;
    }
    if (msg.contains('insufficient_funds')) {
      return l10n.errorInsufficientFunds;
    }
    if (msg.contains('authentication_failure') ||
        msg.contains('failed 3d secure')) {
      return l10n.errorAuthenticationFailed;
    }

    // 2. Connectivity Errors
    if (msg.contains('socketexception') ||
        msg.contains('connection failed') ||
        msg.contains('network_error')) {
      return l10n.errorConnectionFailed;
    }

    // 3. Backend / Generic Errors
    if (msg.contains('unauthorized') || msg.contains('401')) {
      return l10n.commonSessionExpired;
    }

    if (msg.contains('timeout') || msg.contains('deadline exceeded')) {
      return l10n.errorConnectionFailed;
    }

    if (msg.contains('failed to load rates') ||
        msg.contains('failed to fetch rate') ||
        msg.contains('pq:')) {
      return l10n.errorProcessingFailed;
    }

    // Default fallback
    return l10n.errorUnknown;
  }
}
