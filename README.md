# goose-ansi

[![ci](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml)

Terminal styling for the [Goose](https://github.com/aardappel/goose) programming language: SGR sequences, colors, and width-aware measuring.

## Features

- Attributes: bold, dim, italic, underline, reverse, strike.
- Colors: 8 and 16 colors, the 256-color palette, and 24-bit truecolor.
- A foreground and a background for each color form.
- Colour levels 0 to 3, with a fall back from RGB to 256 and 16 colours.
- `strip` takes every CSI and OSC sequence. `len` and `truncate` measure styled text.
- `truncate_ellipsis` and `truncate_with` mark a cut.
- `wrap` breaks lines and keeps the style and the link.
- OSC 8 hyperlinks with a fall back to text and URL.
- A width table from the Unicode EastAsianWidth data.
- Pure Goose. No C code.

## Install

Put this line in the root file of your program:

```goose
import ansi from "rekanalar/goose-ansi@v0.2.0";
```

## Example

```goose
import std;
import ansi from "rekanalar/goose-ansi@v0.2.0";

fn main() {
    var line: u8[>..] = [];
    ansi::bold(line, "error: ");
    ansi::red(line, "the file is missing");
    print(line);
    return 0;
}
```

## Functions

| Function | Result |
|---|---|
| `style(out, text, codes)` | the text with the SGR parameters in codes |
| `bold`, `dim`, `italic`, `underline`, `reverse`, `strike` | the text with that attribute |
| `black` … `white`, `gray` | the text in that foreground color |
| `bg_black` … `bg_white` | the text on that background color |
| `color256(out, text, n)` | the text in the 256-color palette |
| `bg_color256(out, text, n)` | the text on a 256-color background |
| `truecolor(out, text, r, g, b)` | the text in 24-bit color |
| `bg_truecolor(out, text, r, g, b)` | the text on a 24-bit background |
| `bright_black` … `bright_white`, `bg_bright_black` … `bg_bright_white` | the bright 16-colour set |
| `truecolor_at(out, text, r, g, b, level)`, `bg_truecolor_at` | RGB lowered to the level 0 to 3 |
| `color256_at(out, text, n, level)`, `bg_color256_at` | a palette number lowered to the level |
| `rgb_to_256(r, g, b)`, `rgb_to_16(r, g, b)`, `to_16(n)` | the nearest palette number or SGR code |
| `color_level()` | the level of the terminal, 0 to 3 |
| `strip(out, s)` | s without its CSI and OSC sequences |
| `len(s)` | the visible length in columns |
| `truncate(out, s, width)` | at most width columns of s |
| `truncate_ellipsis(out, s, width)` | s, or a cut of s that ends with U+2026 |
| `truncate_with(out, s, width, tail)` | s, or a cut of s that ends with tail |
| `wrap(out, s, width, hard)` | s broken into lines of at most width columns |
| `link(out, text, url)` | an OSC 8 hyperlink |
| `link_with(out, text, url, supported)` | a link, or "text (url)" |
| `links_supported()` | true when the terminal takes OSC 8 |
| `char_width(cp)` | the columns of one code point |
| `enabled()` | true when the terminal takes styling |

Every writer appends to a builder the caller owns. A color number above 255
clamps to 255. A number below 0 clamps to 0.

## Styling and the terminal

`enabled()` reads the environment. `NO_COLOR`, set to any value, turns styling
off. `TERM=dumb` turns it off too. The writers do not check `enabled()`
themselves, so the caller decides.

## Colour levels

`color_level()` follows chalk: 0 none, 1 sixteen colours, 2 the 256 palette,
3 truecolor. `FORCE_COLOR` (0 to 3) wins. Else `NO_COLOR` or `TERM=dumb` gives
0. `COLORTERM=truecolor` or `24bit` gives 3. A `TERM` with `256color` gives 2.
Else the level is 1. The `_at` writers take the level and lower the colour.
The plain writers do not lower. Level 0 writes the plain text.

## Limits

- `color_level()` does not test for a tty. The caller decides that.
- `wrap` splits at spaces only. It does not break at hyphens.
- `wrap` trims no space at the start of a line, except at a break.
- `wrap` keeps the style as a list of SGR codes. An unusual code stays as is.
- `links_supported()` knows a few terminals and `VTE_VERSION` 5000 or more.
- The writers do not parse nested styles. Use `style` with several codes.
- Width counts code points. It does not join emoji sequences.

## Widths

`len` and `truncate` count columns. A wide character takes two columns. The
table comes from the EastAsianWidth.txt file of the Unicode Character
Database. A malformed UTF-8 byte takes one column.

`truncate` keeps the sequences it passes. It cuts between them. A cut of
styled text ends with the reset sequence. A cut inside a link closes the link.

## Test

```bash
goose run test/run.goose
goose run examples/demo.goose
```

## License

MIT
