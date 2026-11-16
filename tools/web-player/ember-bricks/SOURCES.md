# Ember Bricks: where its sounds, font and levels come from

Nothing the game shows is a picture: its bricks, paddle, balls, sparks and
screens are graphics that its builder (`../ember-bricks.livecodescript`)
makes, and the game itself colours. The sounds were made for it by
`make_assets.py`, from sine, square and triangle waves and noise: nothing
is recorded, and nothing is anyone else's. The levels (`levels.txt`) were
drawn for it. So the game, its sounds and its levels are OXT-Beyond's own,
under the GPLv3 as the rest.

The font is Atkinson Hyperlegible, by the Braille Institute of America,
under the SIL Open Font License 1.1 (`licenses/`). Its two files are
Puzzle Almanac's (`../puzzle-almanac/fonts/`), byte for byte: Google Fonts'
copy with Macintosh name records added, which the web engine's font loader
reads, and nothing else changed (`../puzzle-almanac/make_assets.py` adds
them, and says why).

| File here | From | Made by |
| --- | --- | --- |
| `sounds/attack.wav` | made here | `make_assets.py`: trouble from the rival, in a duel |
| `sounds/best.wav` | made here | `make_assets.py`: a new best score |
| `sounds/blaze.wav` | made here | `make_assets.py`: the fireball |
| `sounds/bomb.wav` | made here | `make_assets.py`: a bomb goes off |
| `sounds/brick-1.wav` | made here | `make_assets.py`: a brick breaks, the heat cold |
| `sounds/brick-2.wav` | made here | `make_assets.py`: a brick breaks, a note higher for each step of the heat |
| `sounds/brick-3.wav` | made here | `make_assets.py`: the same |
| `sounds/brick-4.wav` | made here | `make_assets.py`: the same |
| `sounds/brick-5.wav` | made here | `make_assets.py`: a brick breaks, the heat white hot |
| `sounds/clear.wav` | made here | `make_assets.py`: a level cleared |
| `sounds/click.wav` | made here | `make_assets.py`: a button |
| `sounds/go.wav` | made here | `make_assets.py`: a duel begins |
| `sounds/hazard.wav` | made here | `make_assets.py`: a dark spark caught |
| `sounds/heat.wav` | made here | `make_assets.py`: the heat goes up a step |
| `sounds/join.wav` | made here | `make_assets.py`: a duel's link is made |
| `sounds/laser.wav` | made here | `make_assets.py`: the paddle's bolts |
| `sounds/launch.wav` | made here | `make_assets.py`: the ball leaves the paddle |
| `sounds/life.wav` | made here | `make_assets.py`: a life won |
| `sounds/lost.wav` | made here | `make_assets.py`: a ball lost |
| `sounds/over.wav` | made here | `make_assets.py`: the run ends |
| `sounds/paddle.wav` | made here | `make_assets.py`: the ball off the paddle |
| `sounds/power.wav` | made here | `make_assets.py`: a bright spark caught |
| `sounds/shield.wav` | made here | `make_assets.py`: the net throws a ball back |
| `sounds/steel.wav` | made here | `make_assets.py`: the ball off steel |
| `sounds/tick.wav` | made here | `make_assets.py`: a duel's last ten seconds |
| `sounds/tough.wav` | made here | `make_assets.py`: a brick that takes more than one hit |
| `sounds/wall.wav` | made here | `make_assets.py`: the ball off a wall |
| `fonts/AtkinsonHyperlegible-Regular.ttf` | Google Fonts, Atkinson Hyperlegible (`ofl/atkinsonhyperlegible/AtkinsonHyperlegible-Regular.ttf`), by way of Puzzle Almanac | copied from `../puzzle-almanac/fonts/`, where Macintosh name records were added |
| `fonts/AtkinsonHyperlegible-Bold.ttf` | Google Fonts, Atkinson Hyperlegible (`ofl/atkinsonhyperlegible/AtkinsonHyperlegible-Bold.ttf`), by way of Puzzle Almanac | copied from `../puzzle-almanac/fonts/`, where Macintosh name records were added |
| `licenses/atkinson-hyperlegible-OFL.txt` | Google Fonts, Atkinson Hyperlegible (`ofl/atkinsonhyperlegible/OFL.txt`) | copied |
| `levels.txt` | made here | drawn for the game; the file says what each letter is |
