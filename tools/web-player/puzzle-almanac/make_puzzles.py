#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""Make Puzzle Almanac's Number Place puzzles (data/numbers.txt).

  python3 tools/web-player/puzzle-almanac/make_puzzles.py [--check]

Number Place (the puzzle Dell Magazines first printed in 1979) is a grid
of N by N squares in boxes; each row, each column and each box holds every
number from 1 to N once. The game has three sizes:

  4 by 4  boxes of 2 by 2   for a young child
  6 by 6  boxes of 2 by 3   (2 rows of 3 squares)
  9 by 9  boxes of 3 by 3

Each puzzle is made here from a seed, so the file is the same every time:
a whole grid is filled at random (backtracking), then squares are emptied
in a random order, two at a time opposite each other through the middle
(so the puzzle has the look of a printed one), while

  - the puzzle has exactly one answer (a full search counts two at most), and
  - it can be solved by "singles" alone: a square that can hold only one
    number, or a number that fits in only one square of a row, a column or
    a box. So no puzzle ever needs a guess, which is what makes it a fair
    puzzle for a child and a calm one for everyone else,

and while there are more given numbers than MIN_GIVEN (fewer givens is a
harder puzzle, and these are meant to be gentle).

The game makes many more puzzles from each of these: it gives the numbers
other names (1 becomes 3 and so on), changes the order of the rows in a band
of boxes, of the bands, of the columns in a stack of boxes and of the stacks,
and may turn the grid half way round. None of that changes the answer's
being one and only one, or the singles that find it
(tests/lcs/webplayer/puzzle-almanac.livecodescript and
tools/ci/tests/test_puzzle_almanac.py check both sides).

Each line of numbers.txt is SIZE:PUZZLE:ANSWER, the squares row by row,
0 for an empty one. --check makes the file again and compares it with the
committed one.
"""

import argparse
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = os.path.join(HERE, 'data', 'numbers.txt')

# size: (box rows, box columns, puzzles, fewest givens)
SIZES = {
    4: (2, 2, 96, 6),
    6: (2, 3, 160, 13),
    9: (3, 3, 240, 28),
}
SEED = 20261107


def units(n, br, bc):
    """Every row, column and box, as lists of square indexes."""
    rows = [[r * n + c for c in range(n)] for r in range(n)]
    cols = [[r * n + c for r in range(n)] for c in range(n)]
    boxes = []
    for r0 in range(0, n, br):
        for c0 in range(0, n, bc):
            boxes.append([(r0 + r) * n + c0 + c for r in range(br) for c in range(bc)])
    return rows + cols + boxes


def peers_of(n, all_units):
    peers = [set() for _ in range(n * n)]
    for unit in all_units:
        for i in unit:
            peers[i].update(unit)
    for i in range(n * n):
        peers[i].discard(i)
    return [sorted(p) for p in peers]


class Shape:
    def __init__(self, n, br, bc):
        self.n, self.br, self.bc = n, br, bc
        self.units = units(n, br, bc)
        self.peers = peers_of(n, self.units)


def candidates(shape, grid, i):
    used = {grid[p] for p in shape.peers[i]}
    return [v for v in range(1, shape.n + 1) if v not in used]


def fill(shape, rng):
    """A whole grid, at random."""
    grid = [0] * (shape.n * shape.n)

    def go(k):
        if k == len(grid):
            return True
        options = candidates(shape, grid, k)
        rng.shuffle(options)
        for v in options:
            grid[k] = v
            if go(k + 1):
                return True
        grid[k] = 0
        return False

    if not go(0):
        raise RuntimeError('no grid')
    return grid


def count_answers(shape, grid, limit=2):
    """How many answers the puzzle has, counting no further than limit."""
    grid = list(grid)
    found = 0

    def go():
        nonlocal found
        best, best_opts = -1, None
        for i, v in enumerate(grid):
            if v == 0:
                opts = candidates(shape, grid, i)
                if not opts:
                    return
                if best_opts is None or len(opts) < len(best_opts):
                    best, best_opts = i, opts
                    if len(opts) == 1:
                        break
        if best < 0:
            found += 1
            return
        for v in best_opts:
            grid[best] = v
            go()
            if found >= limit:
                break
        grid[best] = 0

    go()
    return found


def solve_by_singles(shape, grid):
    """The grid as far as singles alone fill it (naked and hidden)."""
    grid = list(grid)
    changed = True
    while changed:
        changed = False
        for i, v in enumerate(grid):
            if v == 0:
                opts = candidates(shape, grid, i)
                if len(opts) == 1:
                    grid[i] = opts[0]
                    changed = True
        for unit in shape.units:
            for v in range(1, shape.n + 1):
                if any(grid[i] == v for i in unit):
                    continue
                places = [i for i in unit if grid[i] == 0 and v in candidates(shape, grid, i)]
                if len(places) == 1:
                    grid[places[0]] = v
                    changed = True
    return grid


def make_one(shape, rng, min_given):
    answer = fill(shape, rng)
    puzzle = list(answer)
    size = shape.n * shape.n
    order = list(range(size))
    rng.shuffle(order)
    given = size
    for i in order:
        j = size - 1 - i
        if puzzle[i] == 0:
            continue
        pair = {i, j}
        if given - len(pair) < min_given:
            continue
        saved = {k: puzzle[k] for k in pair}
        for k in pair:
            puzzle[k] = 0
        if count_answers(shape, puzzle) == 1 and solve_by_singles(shape, puzzle) == answer:
            given -= len(pair)
        else:
            for k, v in saved.items():
                puzzle[k] = v
    return puzzle, answer


def make_all():
    rng = random.Random(SEED)
    lines = []
    for n, (br, bc, count, min_given) in SIZES.items():
        shape = Shape(n, br, bc)
        seen = set()
        while len([1 for line in lines if line.startswith('%d:' % n)]) < count:
            puzzle, answer = make_one(shape, rng, min_given)
            key = ''.join(map(str, puzzle))
            if key in seen:
                continue
            seen.add(key)
            lines.append('%d:%s:%s' % (n, key, ''.join(map(str, answer))))
    return lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--check', action='store_true', help='compare with the committed file')
    args = ap.parse_args(argv)
    text = '\n'.join(make_all()) + '\n'
    if args.check:
        with open(TARGET, encoding='utf-8') as f:
            same = f.read() == text
        print('PUZZLES OK' if same else 'PUZZLES DIFFER')
        return 0 if same else 1
    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    with open(TARGET, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('PUZZLES MADE %s' % TARGET)
    return 0


if __name__ == '__main__':
    sys.exit(main())
