import '../core/money.dart';
import 'database.dart';

/// [CurrencyRates.rateToBaseMicros] and [Transactions.fxRateToBaseMicros]
/// are both scaled by this so the rate is an exact integer, never a
/// `double` — the same rule [Money] itself follows.
const currencyRateScale = 1000000;

/// Converts [amount] (in some other currency) into the parent currency
/// using [rateToBaseMicros] — units of parent per 1 unit of that currency,
/// scaled by [currencyRateScale].
Money convertUsingRate(Money amount, int rateToBaseMicros) =>
    Money((amount.paise * rateToBaseMicros) ~/ currencyRateScale);

/// A transaction's value in the parent currency — computed, never stored
/// redundantly. Every Reports/Stats/Budget total that must stay stable
/// after a rate changes later (the "snapshot" design decision) folds over
/// this instead of raw [TransactionRow.amount].
extension TransactionBaseValue on TransactionRow {
  Money get baseAmount => currencyCode == null
      ? amount
      : convertUsingRate(amount, fxRateToBaseMicros!);
}
