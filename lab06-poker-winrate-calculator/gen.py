#!/usr/bin/env python3
"""
Poker Test Case Generator
Generates input.txt and output.txt for Poker IP verification
"""

import random
from itertools import combinations
from collections import Counter
from typing import List, Tuple

# Configuration
NUM_PATTERNS = 10000
IP_WIDTH = 9  # Number of players

# Card encoding
SUITS = {'C': 0, 'D': 1, 'H': 2, 'S': 3}
SUIT_NAMES = ['C', 'D', 'H', 'S']
RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A']
RANK_VALUES = {r: i+2 for i, r in enumerate(RANKS)}  # 2->2, 3->3, ..., A->14

# Hand rankings
HAND_RANKS = {
    'High Card': 0,
    'One Pair': 1,
    'Two Pair': 2,
    'Three of a Kind': 3,
    'Straight': 4,
    'Flush': 5,
    'Full House': 6,
    'Four of a Kind': 7,
    'Straight Flush': 8
}

class Card:
    def __init__(self, rank: str, suit: str):
        self.rank = rank  # '2'-'9', 'T', 'J', 'Q', 'K', 'A'
        self.suit = suit  # 'C', 'D', 'H', 'S'
        self.rank_val = RANK_VALUES[rank]
        self.suit_val = SUITS[suit]
    
    def __repr__(self):
        return f"{self.rank}{self.suit}"
    
    def __eq__(self, other):
        return self.rank == other.rank and self.suit == other.suit
    
    def __hash__(self):
        return hash((self.rank, self.suit))

def create_deck() -> List[Card]:
    """Create a standard 52-card deck"""
    return [Card(r, s) for r in RANKS for s in SUIT_NAMES]

def check_straight(ranks: List[int]) -> Tuple[bool, int]:
    """Check if ranks form a straight. Returns (is_straight, high_card)"""
    sorted_ranks = sorted(set(ranks), reverse=True)
    
    # Check regular straight
    if len(sorted_ranks) == 5:
        if sorted_ranks[0] - sorted_ranks[4] == 4:
            return True, sorted_ranks[0]
    
    # Check A-2-3-4-5 (wheel)
    if sorted_ranks == [14, 5, 4, 3, 2]:
        return True, 5  # In wheel, high card is 5
    
    return False, 0

def classify_hand(five_cards: List[Card]) -> Tuple[str, List[int]]:
    """Classify a 5-card hand and return comparison values"""
    ranks = sorted([c.rank_val for c in five_cards], reverse=True)
    suits = [c.suit for c in five_cards]
    
    is_flush = len(set(suits)) == 1
    is_straight, straight_high = check_straight(ranks)
    
    rank_counts = Counter(ranks)
    counts = sorted(rank_counts.values(), reverse=True)
    unique_ranks = sorted(rank_counts.keys(), key=lambda x: (rank_counts[x], x), reverse=True)
    
    # Straight Flush
    if is_flush and is_straight:
        return 'Straight Flush', [straight_high]
    
    # Four of a Kind
    if counts == [4, 1]:
        quad = [r for r in unique_ranks if rank_counts[r] == 4][0]
        kicker = [r for r in unique_ranks if rank_counts[r] == 1][0]
        return 'Four of a Kind', [quad, kicker]
    
    # Full House
    if counts == [3, 2]:
        trip = [r for r in unique_ranks if rank_counts[r] == 3][0]
        pair = [r for r in unique_ranks if rank_counts[r] == 2][0]
        return 'Full House', [trip, pair]
    
    # Flush
    if is_flush:
        return 'Flush', ranks
    
    # Straight
    if is_straight:
        return 'Straight', [straight_high]
    
    # Three of a Kind
    if counts == [3, 1, 1]:
        trip = [r for r in unique_ranks if rank_counts[r] == 3][0]
        kickers = sorted([r for r in unique_ranks if rank_counts[r] == 1], reverse=True)
        return 'Three of a Kind', [trip] + kickers
    
    # Two Pair
    if counts == [2, 2, 1]:
        pairs = sorted([r for r in unique_ranks if rank_counts[r] == 2], reverse=True)
        kicker = [r for r in unique_ranks if rank_counts[r] == 1][0]
        return 'Two Pair', pairs + [kicker]
    
    # One Pair
    if counts == [2, 1, 1, 1]:
        pair = [r for r in unique_ranks if rank_counts[r] == 2][0]
        kickers = sorted([r for r in unique_ranks if rank_counts[r] == 1], reverse=True)
        return 'One Pair', [pair] + kickers
    
    # High Card
    return 'High Card', ranks

def evaluate_hand(seven_cards: List[Card]) -> Tuple[int, Tuple]:
    """Evaluate 7 cards and return best 5-card hand value"""
    best_hand = None
    best_rank = -1
    
    # Try all 5-card combinations
    for five_cards in combinations(seven_cards, 5):
        hand_type, comparison_values = classify_hand(list(five_cards))
        hand_value = (HAND_RANKS[hand_type], tuple(comparison_values))
        
        if best_hand is None or hand_value > best_rank:
            best_hand = hand_type
            best_rank = hand_value
    
    return best_rank

def generate_test_case() -> Tuple[List[Card], List[List[Card]], int]:
    """
    Generate one valid poker test case
    Returns: (public_cards, players_hole_cards, winner_binary)
    """
    deck = create_deck()
    random.shuffle(deck)
    
    # Deal cards
    public_cards = deck[:5]
    players_hole_cards = []
    card_idx = 5
    
    for _ in range(IP_WIDTH):
        players_hole_cards.append([deck[card_idx], deck[card_idx + 1]])
        card_idx += 2
    
    # Evaluate each player's hand
    player_hands = []
    for i in range(IP_WIDTH):
        seven_cards = public_cards + players_hole_cards[i]
        hand_value = evaluate_hand(seven_cards)
        player_hands.append((i, hand_value))
    
    # Find winners
    best_value = max(hand_value for _, hand_value in player_hands)
    winners = [i for i, hand_value in player_hands if hand_value == best_value]
    
    # Generate winner binary (MSB = Player 8, LSB = Player 0)
    winner_bits = ['0'] * IP_WIDTH
    for w in winners:
        winner_bits[IP_WIDTH - 1 - w] = '1'
    
    winner_binary = int(''.join(winner_bits), 2)
    
    return public_cards, players_hole_cards, winner_binary

def write_input_txt(test_cases: List, filename: str = "input.txt"):
    """Write all test cases to input.txt"""
    with open(filename, 'w') as f:
        f.write(f"{len(test_cases)}\n")
        
        for public_cards, players_hole_cards, _ in test_cases:
            # Write public cards (5 cards, each 4-bit num + 2-bit suit = 6 bits)
            for card in public_cards:
                f.write(f"{card.rank_val:X} {card.suit_val:X}\n")
            
            # Write each player's hole cards (9 players × 2 cards)
            for player_cards in players_hole_cards:
                for card in player_cards:
                    f.write(f"{card.rank_val:X} {card.suit_val:X}\n")

def write_output_txt(test_cases: List, filename: str = "output.txt"):
    """Write expected outputs to output.txt"""
    with open(filename, 'w') as f:
        for _, _, winner_binary in test_cases:
            # Write as 9-bit binary represented in hex (need 3 hex digits)
            f.write(f"{winner_binary:03X}\n")

def main():
    print("=" * 80)
    print("Poker Test Case Generator")
    print("=" * 80)
    print(f"Generating {NUM_PATTERNS} test cases...")
    print(f"IP_WIDTH = {IP_WIDTH} players")
    print()
    
    test_cases = []
    
    for i in range(NUM_PATTERNS):
        try:
            public_cards, players_hole_cards, winner_binary = generate_test_case()
            test_cases.append((public_cards, players_hole_cards, winner_binary))
            
            if (i + 1) % 10 == 0:
                print(f"Generated {i + 1}/{NUM_PATTERNS} test cases...")
        
        except Exception as e:
            print(f"Error generating test case {i}: {e}")
            continue
    
    # Write to files
    write_input_txt(test_cases)
    write_output_txt(test_cases)
    
    print()
    print("=" * 80)
    print("Generation Complete!")
    print("=" * 80)
    print(f"✓ Created input.txt with {len(test_cases)} test cases")
    print(f"✓ Created output.txt with {len(test_cases)} expected outputs")
    print()
    
    # Show a sample
    if test_cases:
        print("Sample Test Case:")
        public, players, winner = test_cases[0]
        print(f"  Public cards: {' '.join(str(c) for c in public)}")
        for i, player_cards in enumerate(players):
            print(f"  Player {i}: {' '.join(str(c) for c in player_cards)}")
        print(f"  Winner binary: {winner:09b} (hex: {winner:03X})")
        print()

if __name__ == "__main__":
    main()