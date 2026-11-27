/// Which banks' SMS XPENC knows, and how a sender ID is matched.
///
/// India's bank SMS come from a sender ID like `JD-HDFCBK-S`: a 2-letter
/// operator/circle prefix (`JD-`, `AX-`, `VM-`…) that changes from message
/// to message, the bank's fixed code (`HDFCBK`), and since TRAI's DLT rules
/// a suffix for the kind of message — `-S` service, `-T` transactional,
/// `-G` government, `-P` promotional. Tracking a bank means tracking its
/// code; a `-P` message is an advert and never read.
library;

/// One bank's SMS identity.
class BankSmsTemplate {
  const BankSmsTemplate(this.bank, this.senderCodes, {this.sharedIn});

  final String bank;

  /// The fixed middle of its sender IDs: `HDFCBK` in `JD-HDFCBK-S`.
  final List<String> senderCodes;

  /// The GitHub issue someone shared this bank's messages in (the "Bank
  /// support" form), when the format came from a user.
  final int? sharedIn;
}

/// Banks XPENC tracks out of the box. Seeded into `sender_rules`, where the
/// user can switch each off or add their own.
///
/// To add one, take it from a "Bank support" issue — never guess a sender
/// code: a wrong one reads someone else's messages.
const kBankSmsTemplates = <BankSmsTemplate>[
  // From people who shared redacted samples on GitHub.
  BankSmsTemplate('HDFC Bank', ['HDFCBK'], sharedIn: 165),
  BankSmsTemplate('Federal Bank', ['FEDBNK'], sharedIn: 211),
  // Shipped since 1.0.
  BankSmsTemplate('India Post Payments Bank', ['IPPB', 'IPPBNK']),
  BankSmsTemplate('Yes Bank', ['YESBNK']),
  BankSmsTemplate('ICICI Bank', ['ICICIB']),
  BankSmsTemplate('State Bank of India', ['SBIINB', 'SBIUPI']),
  BankSmsTemplate('Axis Bank', ['AXISBK']),
  BankSmsTemplate('Kotak Mahindra Bank', ['KOTAKB']),
  BankSmsTemplate('Punjab National Bank', ['PNBSMS']),
];

/// [kBankSmsTemplates], one row per sender code, as `sender_rules` seeds.
final kSeedSenderRules = <({String pattern, String bank})>[
  for (final t in kBankSmsTemplates)
    for (final code in t.senderCodes) (pattern: code, bank: t.bank),
];

/// Where a user shares their bank's messages so it can become a template.
const kBankSupportIssueUrl =
    'https://github.com/PATILYASHH/XPENC/issues/new?template=bank_support.yml';

final _operatorPrefix = RegExp(r'^[A-Z]{2}-');
final _dltSuffix = RegExp(r'-[STPG]$');
final _promotionalSuffix = RegExp(r'-P$');
final _notCode = RegExp(r'[^A-Z0-9]');
final _code = RegExp(r'^[A-Z0-9]{3,12}$');

/// The fixed middle of a sender ID: `JD-HDFCBK-S` and `VM-HDFCBK` are both
/// `HDFCBK`.
String senderCode(String sender) => sender
    .trim()
    .toUpperCase()
    .replaceFirst(_operatorPrefix, '')
    .replaceFirst(_dltSuffix, '')
    .replaceAll(_notCode, '');

/// What the user typed as a sender to track (`AX-FEDBNK-S`, `fedbnk`), as
/// it's stored (`FEDBNK`) — null when no usable code is left. A phone
/// number never is one: XPENC doesn't read people's messages.
String? normalizeSenderPattern(String input) {
  final code = senderCode(input);
  if (!_code.hasMatch(code)) return null;
  if (RegExp(r'^\d{7,}$').hasMatch(code)) return null;
  return code;
}

/// `JD-HDFCBK-P`: an advert from the bank, never a payment.
bool isPromotionalSender(String sender) =>
    _promotionalSuffix.hasMatch(sender.trim().toUpperCase());

/// Whether a message from [sender] is one the user tracks: its ID contains
/// one of [patterns] (enabled `sender_rules`) and it isn't an advert.
bool tracksSender(String sender, Iterable<String> patterns) {
  if (isPromotionalSender(sender)) return false;
  final s = sender.toUpperCase();
  for (final p in patterns) {
    if (p.isNotEmpty && s.contains(p.toUpperCase())) return true;
  }
  return false;
}

/// The known bank [sender] belongs to, if any.
BankSmsTemplate? templateForSender(String sender) {
  final s = sender.toUpperCase();
  for (final t in kBankSmsTemplates) {
    for (final code in t.senderCodes) {
      if (s.contains(code)) return t;
    }
  }
  return null;
}
