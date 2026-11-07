# goose-ansi

[![ci](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml)

Terminal styling for the [Goose](https://github.com/aardappel/goose) programming language: SGR sequences, colors, and width-aware measuring.

## Features

- Attributes: bold, dim, italic, underline, overline, hidden, reverse, strike.
- Colors: 8 and 16 colors, the 256-color palette, and 24-bit truecolor.
- A foreground and a background for each color form, and an underline colour.
- Colours from hex strings such as `#ff8800` and `f80`.
- Colour levels 0 to 3, with a fall back from RGB to 256 and 16 colours.
- A level function with the rules of chalk 6, for a stream that is or is not a terminal.
- `strip` takes every CSI and OSC sequence. `len` and `truncate` measure styled text.
- `truncate_ellipsis` and `truncate_with` mark a cut.
- `wrap` breaks lines and keeps the style and the link.
- OSC 8 hyperlinks with a fall back to text and URL.
- A width table from the Unicode EastAsianWidth data.
- Pure Goose. No C code.

## Install

Put this line in the root file of your program:

```goose
import ansi from "rekanalar/goose-ansi@v0.3.0";
```

## Example

```goose
import std;
import ansi from "rekanalar/goose-ansi@v0.3.0";

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
| `bold`, `dim`, `italic`, `underline`, `overline`, `hidden`, `reverse`, `strike` | the text with that attribute |
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
| `underline_rgb(out, text, r, g, b)`, `underline_color256(out, text, n)` | the text with a coloured underline (SGR 58) |
| `underline_rgb_at(out, text, r, g, b, level)`, `underline_color256_at(out, text, n, level)` | the underline colour lowered to the level |
| `hex(out, text, s)`, `bg_hex`, `underline_hex` | the text in the colour of a hex string; give false for a bad string |
| `hex_at(out, text, s, level)`, `bg_hex_at`, `underline_hex_at` | the same, lowered to the level |
| `color_level()` | the level of the terminal, 0 to 3 |
| `color_level_stream(is_tty)` | the level for a stream; the caller says whether it is a terminal |
| `color_level_tty(is_tty, no_color, term, colorterm, force)` | the level for given inputs |
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

`color_level()` follows chalk 6: 0 none, 1 sixteen colours, 2 the 256 palette,
3 truecolor. The order of the rules is that of `supports-color` in chalk 6.0.1.

- `FORCE_COLOR` of `false` or `0` gives 0. A number gives that number, at most 3.
- `FORCE_COLOR=true` sets a minimum of 1 and then detects the level.
- Another value of `FORCE_COLOR` has no effect.
- Without `FORCE_COLOR`, `NO_COLOR` gives 0, and so does a stream that is not a terminal.
- `TERM=dumb` gives the minimum.
- `COLORTERM=truecolor` or `24bit`, or `TERM` of `xterm-kitty`, `xterm-ghostty` or `wezterm`, gives 3.
- A `TERM` that ends with `-256` or `-256color` gives 2.
- A `TERM` that starts with `screen`, `xterm`, `vt100`, `vt220` or `rxvt`, or holds `color`, `ansi`, `cygwin` or `linux`, gives 1.
- Any other `COLORTERM` gives 1. Else the level is the minimum.

The `_at` writers take the level and lower the colour. The plain writers do
not lower. Level 0 writes the plain text. An empty string for `force` or
`colorterm` means not set. chalk reads an empty `FORCE_COLOR` as set.

`color_level_stream(true)` is chalk `supportsColor` for a terminal.
`color_level_stream(false)` is `supportsColorStderr` for a pipe. The two
differ only by the terminal flag. The package has no terminal check, because
the Goose standard library has none. The caller passes the flag.

## Limits

- `color_level()` does not test for a tty. It assumes one. Use `color_level_stream` with the flag.
- The level reads `TERM`, `COLORTERM`, `FORCE_COLOR` and `NO_COLOR` only. It does not read the CI variables, `TF_BUILD`, `TEAMCITY_VERSION`, `TERM_PROGRAM`, the Windows release or the `--color` flags.
- `NO_COLOR` gives level 0. chalk ignores it. `COLORTERM=24bit` gives level 3. chalk gives 1 for it.
- `wrap` splits at spaces only. It does not break at hyphens.
- `wrap` trims no space at the start of a line, except at a break.
- `wrap` keeps the style as a list of SGR codes. An unusual code stays as is.
- `links_supported()` knows a few terminals and `VTE_VERSION` 5000 or more.
- The writers do not parse nested styles. Use `style` with several codes.
- Width counts code points. It does not join emoji sequences.

## Hex strings and underline colours

A hex string has three or six hex digits, in any case, after at most one `#`.
Any other text gives false and writes nothing. chalk reads other text as black, or
as the first match.

A colour number outside 0 to 255 clamps. chalk does not clamp.
Every writer closes with ESC[0m. chalk closes with the reset of the one attribute.

The underline colour exists in chalk 6 (`underlineRgb`, `underlineHex`,
`underlineAnsi256`). It is not in chalk 5. Not every terminal draws it.

## Changes from 0.2.0

- `FORCE_COLOR` of 4 or more gives 3. Version 0.2.0 gave 1.
- `FORCE_COLOR=true` detects the level. With `TERM=xterm-256color` the level is 2. Version 0.2.0 gave 1.
- A `FORCE_COLOR` that is not a number, `true` or `false` has no effect. Version 0.2.0 gave 1.
- A `TERM` of an unknown name with no `COLORTERM` gives 0. Version 0.2.0 gave 1.
- A `TERM` with `256color` inside, but not at the end, no longer gives 2.
- `wrap` keeps a truecolor or underline colour over a line break. Version 0.2.0 lost the colour when a part was zero.
- A colour lowered to 16 colours gets the bright code only when one component is full. Version 0.2.0 gave the bright code to most light colours. A light gray now gives 37, not 97.

## Widths

`len` and `truncate` count columns. A wide character takes two columns. The
table comes from the EastAsianWidth.txt file of the Unicode Character
Database. A malformed UTF-8 byte takes one column.

`truncate` keeps the sequences it passes. It cuts between them. A cut of
styled text ends with the reset sequence. A cut inside a link closes the link.

## Test

```bash
goose run test/run.goose
goose run test/run.goose --debug
goose run examples/demo.goose
```

The file `test/chalk_cases.goose` holds 1207 cases from chalk 6.0.1. The script
`test/make_chalk_cases.mjs` makes them with a fixed seed. 14 of them are refusal cases
with no chalk result. The script needs chalk 6.0.1 and Node.

## License

MIT
