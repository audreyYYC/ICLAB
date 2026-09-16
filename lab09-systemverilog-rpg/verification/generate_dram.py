#!/usr/bin/env python3

"""Generate randomized RPG player records for RTL verification."""

import random


def generate_dram():
    with open("dram.dat", "w", encoding="ascii") as dram_file:
        dram_file.write("@10000\n")

        for _player_id in range(256):
            hp = random.randint(5000, 50000)
            month = random.randint(1, 12)

            if month == 2:
                day = random.randint(1, 28)
            elif month in (4, 6, 9, 11):
                day = random.randint(1, 30)
            else:
                day = random.randint(1, 31)

            attack = random.randint(5000, 50000)
            defense = random.randint(5000, 50000)
            exp = random.randint(33000, 60000)
            mp = random.randint(5000, 50000)

            dram_file.write(
                f"{(hp >> 8) & 0xFF:02X} {hp & 0xFF:02X} "
                f"{month & 0x0F:02X} {day & 0x1F:02X}\n"
            )
            dram_file.write(
                f"{(attack >> 8) & 0xFF:02X} {attack & 0xFF:02X} "
                f"{(defense >> 8) & 0xFF:02X} {defense & 0xFF:02X}\n"
            )
            dram_file.write(
                f"{(exp >> 8) & 0xFF:02X} {exp & 0xFF:02X} "
                f"{(mp >> 8) & 0xFF:02X} {mp & 0xFF:02X}\n"
            )


if __name__ == "__main__":
    generate_dram()
    print("Generated dram.dat with 256 players")
