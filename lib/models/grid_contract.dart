/// Which way power flows under a contract.
enum GridContractSide {
  /// The site buys power at a locked price for the term.
  buy,

  /// The site delivers power at a locked price for the term.
  sell,
}

/// A fixed-term power contract, the way real energy is actually traded: you see
/// the spot price, you commit to a rate and a term, and the price is locked for
/// that term whatever the market does next.
///
/// That is where the decision lives. Sign a cheap midday buy for four hours and
/// you carry it through the evening peak; sign an evening sell and you have to
/// actually deliver, at a rate your generation and battery can sustain, or pay
/// an imbalance charge for what you fail to supply.
class GridContract {
  GridContract({
    required this.side,
    required this.price,
    required this.ratePerSecond,
    required this.totalSeconds,
  }) : secondsLeft = totalSeconds;

  final GridContractSide side;

  /// MONEY per unit of energy, locked at signing.
  final double price;

  /// Units of energy per second moved for the term.
  final double ratePerSecond;

  final double totalSeconds;
  double secondsLeft;

  /// Energy actually moved so far, and the money it has settled.
  double energyMoved = 0;
  double settled = 0;

  /// Energy the site failed to deliver on a sell contract.
  double shortfall = 0;

  bool get isDone => secondsLeft <= 0;

  double get progress =>
      totalSeconds <= 0 ? 1 : 1 - (secondsLeft / totalSeconds).clamp(0.0, 1.0);

  /// Total value of the contract if it runs to term without a shortfall.
  double get notional => price * ratePerSecond * totalSeconds;

  /// Term in in-game hours, given how long a game day runs.
  double termHours(double dayLength) => totalSeconds / (dayLength / 24);
}
