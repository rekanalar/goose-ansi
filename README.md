# goose-ansi

[![ci](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-ansi/actions/workflows/ci.yml)

Terminal styling for the [Goose](https://github.com/aardappel/goose) programming language: SGR sequences, colors, and width-aware measuring, and a terminal check.

## Features

- Attributes: bold, dim, italic, underline, double underline, blink, fast blink, frame, encircle, overline, hidden, reverse, strike.
- Colors: 8 and 16 colors, the 256-color palette, and 24-bit truecolor.
- A foreground and a background for each color form, and an underline colour.
- Colours from hex strings such as `#ff8800` and `f80`.
- Colour levels 0 to 3, with a fall back from RGB to 256 and 16 colours.
- A level function with the rules of chalk 6, for a stream that is or is not a terminal.
- `strip` takes every CSI and OSC sequence, with the C1 forms. `len` and `truncate` measure styled text.
- `len` follows the Unicode cluster rules: joined emoji, flags, keycaps and combining marks.
- `style::style_parse` reads a style string such as `bold red on blue`, as `rich` does.
- `is_tty` and `terminal_size` ask the real terminal. `set_override` forces a colour level.
- `truncate_ellipsis` and `truncate_with` mark a cut.
- `wrap` and `wrap_full` break lines and keep the style and the link.
- OSC 8 hyperlinks with a fall back to text and URL.
- Width tables from the Unicode 18 data. A script rebuilds them.
- A small C layer for the terminal check. It builds on Linux, macOS and Windows.

## Install

Put this line in the root file of your program:

```goose
import ansi from "rekanalar/goose-ansi@v1.0.1";
```

The CI runs the gate on Linux, macOS and Windows. It uses Goose v2026.4
and v2026.3 on each.

## Example

```goose
import std;
import ansi from "rekanalar/goose-ansi@v1.0.1";

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
| `color_level()` | the level of stdout, 0 to 3; it asks the real stream |
| `color_level_stream(is_tty)` | the level for a stream; reads the environment and the program arguments; the override wins |
| `color_level_env(is_tty, env, flags)` | the level for a `ColorEnv` and a `ColorFlags`, by the rules of `supports-color` |
| `read_color_env()`, `color_env_set(env, name, value)`, `empty_color_env()` | build a `ColorEnv` from the process or by hand |
| `color_flags(args)` | the `--color` and `--no-color` flags of an argument list; an argument after `--` has no effect |
| `color_level_tty(is_tty, no_color, term, colorterm, force)` | the level for given inputs |
| `strip(out, s)` | s without its CSI and OSC sequences |
| `len(s)` | the visible length in columns |
| `truncate(out, s, width)` | at most width columns of s |
| `truncate_ellipsis(out, s, width)` | s, or a cut of s that ends with U+2026 |
| `truncate_with(out, s, width, tail)` | s, or a cut of s that ends with tail |
| `wrap(out, s, width, hard)` | s broken into lines of at most width columns |
| `wrap_full(out, s, width, hard, trim, word_wrap)` | the same with the options of `wrap-ansi`; `trim` drops the space at a break, `word_wrap` false breaks at the width |
| `len_with(s, ambiguous_is_narrow, count_ansi)` | the width with the options of `string-width` |
| `blink`, `blink2`, `underline2`, `frame`, `encircle` | the text with that attribute (SGR 5, 6, 21, 51, 52) |
| `is_tty(fd)`, `is_tty_stdout()`, `is_tty_stderr()` | true when the descriptor is a terminal |
| `terminal_size(out)`, `terminal_size_with(fd, out)` | writes `columns rows`; `COLUMNS` and `LINES` override; 80 and 25 when unknown |
| `color_level_stdout()`, `color_level_stderr()` | the level of the real stream |
| `set_override(level)`, `unset_override()`, `override_active()` | force the level, as `set_override` of `owo-colors` |
| `style::style_parse(codes, spec)` | writes the SGR codes of a style string; gives 0, or -1 for a bad word |
| `styled(out, text, spec)` | the text in a style string, with `rgb(r,g,b)`, `color(n)` and `link URL`; false for a bad string |
| `style::style_link(url, spec)` | writes the url of a `link URL` word; gives 1, or 0 |
| `link(out, text, url)` | an OSC 8 hyperlink; the URL bytes that OSC 8 forbids are written as `%XX` |
| `link_with(out, text, url, supported)` | a link, or "text (url)"; both forms write the URL with `%XX` |
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

- `FORCE_COLOR` of `false` or `0` gives 0, and so do `--no-color`, `--no-colors`, `--color=false` and `--color=never`. `FORCE_COLOR` wins over the flags.
- `--color=16m`, `--color=full` and `--color=truecolor` give 3. `--color=256` gives 2.
- A number in `FORCE_COLOR` gives that number, at most 3.
- `FORCE_COLOR=true` sets a minimum of 1 and then detects the level.
- An empty `FORCE_COLOR` sets a minimum of 1 and then detects the level.
- The flags `--color`, `--colors`, `--color=true` and `--color=always` set a minimum of 1 and then detect the level.
- An argument after `--` is not a flag.
- `TF_BUILD` and `AGENT_NAME` together give 1, even on a pipe.
- Without a force value, `NO_COLOR` gives 0, and so does a stream that is not a terminal.
- `TERM=dumb` gives the minimum.
- With `CI` set: `GITHUB_ACTIONS`, `GITEA_ACTIONS` or `CIRCLECI` gives 3. `TRAVIS`, `APPVEYOR`, `GITLAB_CI`, `BUILDKITE`, `DRONE` or `CI_NAME=codeship` gives 1. Else the minimum.
- `TEAMCITY_VERSION` gives 1 when the version starts with `9.`, then zeros, then a digit 1 to 9, then a dot. Else it gives 0. The version `9.1.0` gives 1. The version `9.0.1` gives 0.
- `COLORTERM=truecolor` or `24bit`, or `TERM` of `xterm-kitty`, `xterm-ghostty` or `wezterm`, gives 3.
- `TERM_PROGRAM=iTerm.app` gives 3 from version 3, else 2. `Apple_Terminal` gives 2.
- A `TERM` that ends with `-256` or `-256color` gives 2.
- A `TERM` that starts with `screen`, `xterm`, `vt100`, `vt220` or `rxvt`, or holds `color`, `ansi`, `cygwin` or `linux`, gives 1.
- Any other `COLORTERM` gives 1. Else the level is the minimum.

The `_at` writers take the level and lower the colour. The plain writers do
not lower. Level 0 writes the plain text. `color_level_tty` takes text, so an empty string means not set there. Use
`color_env_set` with an empty value to say that a variable is set and empty.

`color_level_stream(true)` is chalk `supportsColor` for a terminal.
`color_level_stream(false)` is `supportsColorStderr` for a pipe. The two
differ only by the terminal flag. `color_level_stdout()` and
`color_level_stderr()` ask the real stream through the C layer.

## Limits

The references disagree in these places, and no standard decides. The package picks one behaviour and names it here.

- Windows release rule. `chalk` reads the build number: 10586 gives level 2 and 14931 gives level 3. `rich` probes the console. Rust `supports-color` assumes ANSI from Windows 10 1511. The package has no Windows release rule.
- Colour fall back. `chalk` uses `color-convert`. `rich` uses HLS, a grey test and a weighted distance. The package follows `chalk`.
- Escape bytes in a width. `string-width` strips them. `rich` `cell_len` counts them. `len` strips. `len_with(s, true, true)` counts.
- `NO_COLOR`. `chalk` ignores it. `rich` and Rust honor it. The package honors it. `COLORTERM=24bit` gives level 3; `chalk` gives 1.
- Marks. `string-width` counts a lone mark outside its listed blocks as 1 column (U+05B0, U+093C). `rich` counts 0. The package counts 0, as Unicode General Category M does.
- Text emoji. `string-width` counts a bare U+00A9, U+2714 or U+2764 as 2. `rich` counts 1. The package counts 1, as UTS 51 does for text presentation. U+FE0F, a joiner or a keycap makes it 2.
- Colour names. `rich` has 235 xterm names. The package takes the 16 base names, the `bright_` forms, `#rrggbb`, `rgb(r,g,b)`, `color(n)` and `default`. `#rgb` is not a style colour.
- A style string writes "on" codes only. `not bold` alone gives -1, because it writes no code. `rich` gives an empty style.
- `rich` markup, the span model, tables and export are a text framework. They are out of scope.

Other limits:

- `color_level_tty` reads `TERM`, `COLORTERM`, `FORCE_COLOR` and `NO_COLOR` only. `color_level_stream` and `color_level_env` read all the rules except the Windows release rule.
- `wrap` splits at spaces only. It does not break at hyphens.
- `wrap` keeps the style as a list of SGR codes. An unusual code stays as is.
- `links_supported()` knows a few terminals and `VTE_VERSION` 5000 or more.
- Link URL bytes. Before this change the writers wrote the URL raw. Now they write each byte below 0x20, the byte 0x7F and each byte from 0x80 as `%XX` in uppercase hex. A printable URL, with any `%XX` it holds, keeps its bytes. The fall back `text (url)` shows `%C3%A9` where it showed `é`.
- After the encoding, a link URL of 2045 bytes or more is no link to `strip`, `len`, `truncate` and `wrap`. They read the opening sequence as text. A URL of 2044 bytes or fewer works.
- The writers do not parse nested styles. Use `style` with several codes.
- The C1 controls count in their UTF-8 form (C2 9B, C2 9C, C2 9D). A lone byte 0x9B is not a control.
- `terminal_size` reads stdout, then stderr, then stdin. It does not follow a resize.

## Security

A terminal reads `ESC`, `BEL` and the C1 bytes inside an OSC 8 link as controls. A URL that holds them ends the sequence early. The rest runs as escapes. It can set the window title, clear the screen or write the clipboard with OSC 52.

`ansi-escapes` 7.3.0, `terminal-link` 5.0.0 and `rich` 15.0.0 write the URL into the sequence raw. We read their source. This package does not copy that.

Protections beyond those references:

- `link`, the `link` word of `styled` and the fall back of `link_with` write the URL through `osc8_url`. It keeps the bytes 32 to 126. It writes every other byte as `%XX`. No raw `ESC`, `BEL` or C1 byte reaches the sequence.
- `style_link` still returns the raw word. `styled` encodes it when it writes.

Risks that stay:

- The `text` argument is yours. `link`, `styled` and `wrap` write it as is. Text from an untrusted source can carry escapes. Run `strip` on it first.
- `wrap` copies an OSC 8 sequence from its input and writes it again on each line. It does not encode that sequence. Run `strip` on untrusted input.
- A terminal ends an OSC sequence at a bare `ESC`. `strip`, `len` and `truncate` do not. They can read a hostile input sequence as one sequence where the terminal reads two. `strip` untrusted input before you pass it on.
- An encoded URL of 2045 bytes or more is not a link to the scanners. See the limits.

## Hex strings and underline colours

A hex string has three or six hex digits, in any case, after at most one `#`.
Any other text gives false and writes nothing. chalk reads other text as black, or
as the first match.

A colour number outside 0 to 255 clamps. chalk does not clamp.
Every writer closes with ESC[0m. chalk closes with the reset of the one attribute.

The underline colour exists in chalk 6 (`underlineRgb`, `underlineHex`,
`underlineAnsi256`). It is not in chalk 5. Not every terminal draws it.

## Widths

`len` and `truncate` count columns of grapheme clusters. A wide character
and an emoji take two columns. A combining mark, a control, a joiner, a
variation selector and a zero width space take none. A flag pair, a keycap
and a joined emoji family take two.

The tables come from the Unicode 18
data. The script `scripts/build-width.py` rebuilds them. A malformed UTF-8
byte takes one column.

`truncate` keeps the sequences it passes. It cuts between clusters. A cut of
styled text ends with the reset sequence. A cut inside a link closes the link.

## Test

```bash
goose run test/run.goose
goose run test/run.goose --debug
goose run examples/demo.goose
goose run examples/detect.goose
goose run examples/terminal.goose
```

The file `test/chalk_cases.goose` holds 1207 cases from chalk 6.0.1. The script
`test/make_chalk_cases.mjs` makes them with a fixed seed. 14 of them are refusal cases
with no chalk result. The script needs chalk 6.0.1 and Node.

The file `test/support_cases.goose` holds 2566 cases for the level rules. The script
`test/make_support_cases.mjs` makes them with the seed 20261107. It needs chalk 6.0.1 and Node.

The tests also hold 42 width cases checked against `string-width` 7.2.0 and `rich` 15.0.0.

## License

MIT
