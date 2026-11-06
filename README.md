# goose-ansi

[![ci](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml)

Terminal styling for Goose: SGR sequences, colors, and width-aware measuring.

## Features

- Attributes: bold, dim, italic, underline, reverse, strike.
- Colors: 8 and 16 colors, the 256-color palette, and 24-bit truecolor.
- A foreground and a background for each color form.
- `strip`, `len`, and `truncate` for styled text.
- A width table from the Unicode EastAsianWidth data.
- Pure Goose. No C code.

## Install

Put this line in the root file of your program:

```goose
import ansi from "rekanalar/goose-ansi@v0.1.1";
```

## Example

```goose
import std;
import ansi from "rekanalar/goose-ansi@v0.1.1";

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
| `strip(out, s)` | s without its SGR sequences |
| `len(s)` | the visible length in columns |
| `truncate(out, s, width)` | at most width columns of s |
| `char_width(cp)` | the columns of one code point |
| `enabled()` | true when the terminal takes styling |

Every writer appends to a builder the caller owns. A color number above 255
clamps to 255. A number below 0 clamps to 0.

## Styling and the terminal

`enabled()` reads the environment. `NO_COLOR`, set to any value, turns styling
off. `TERM=dumb` turns it off too. The writers do not check `enabled()`
themselves, so the caller decides.

## Widths

`len` and `truncate` count columns. A wide character takes two columns. The
table comes from the EastAsianWidth.txt file of the Unicode Character
Database. A malformed UTF-8 byte takes one column.

`truncate` keeps the sequences it passes. It cuts between them. A cut of
styled text ends with the reset sequence.

## Test

```bash
goose run test/run.goose
goose run examples/demo.goose
```

## License

MIT
