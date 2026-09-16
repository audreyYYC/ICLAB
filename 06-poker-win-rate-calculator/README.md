# Poker Win-Rate Calculator

A reusable, parameterized Texas Hold'em hand evaluator plus a sequential top-level engine that exhaustively evaluates every possible turn-and-river completion from the remaining deck.

## At a glance

| Item | Implementation |
| --- | --- |
| Players | Nine in the top-level workload; parameterized in the evaluator |
| Known cards | Two hole cards per player and three shared flop cards |
| Search | All 465 legal turn/river combinations |
| Result | Integer win percentage for each player |
| RTL | [src/Poker.v](src/Poker.v), [src/WinRate.v](src/WinRate.v) |
| Verification | [verification/gen.py](verification/gen.py) |

## Reusable Poker IP

Poker.v evaluates all players combinationally within one cycle. It sorts seven ranks, groups cards by suit, detects duplicate-rank patterns, and packs each player's best hand into a comparable 24-bit ranking key. The key encodes the hand category and decisive cards so ordinary magnitude comparison handles kickers and ties. A parameter controls the number of players, and generate logic creates one evaluator path per player.

Handled cases include straight/royal flush, four of a kind, full house, flush, straight, three of a kind, two pair, one pair, high card, ties, kickers, and the ace-low straight.

## Win-rate engine

WinRate.v removes the 21 known cards from the 52-card deck, enumerates pairs from the 31 remaining-card slots, supplies each completed board to the Poker IP, and accumulates fractional credit for tied winners. The final stage converts accumulated wins to truncated integer percentages and emits all nine results together.

This is exhaustive enumeration, not Monte Carlo sampling.

## Verification

The Python utility independently generates cases and expected results, including ranking boundaries and tie behavior. It was developed with AI assistance, then reviewed, adapted, and used by the author.
