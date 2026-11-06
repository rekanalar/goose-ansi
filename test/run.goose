// Tests for the ansi package. Run with: goose run test/run.goose
//
// Every assert here is one acceptance scenario from the spec. A failed
// assert names its line.

import std;
import ansi from "..";

// expect checks that out holds the bytes.
fn expect(out: u8[>..]&, want: u8[:], what: u8[:]) {
    if out != want {
        print("FAIL ", what, ": got ", out.len, " bytes, want ", want.len);
        assert(false);
    }
}

fn test_attributes() {
    var out: u8[>..] = [];
    ansi::red(out, "x");
    expect(out, "\x1b[31mx\x1b[0m", "red");

    var out2: u8[>..] = [];
    ansi::bold(out2, "x");
    expect(out2, "\x1b[1mx\x1b[0m", "bold");

    var out3: u8[>..] = [];
    ansi::style(out3, "x", [1, 31]);
    expect(out3, "\x1b[1;31mx\x1b[0m", "style bold red");

    var out4: u8[>..] = [];
    ansi::underline(out4, "ab");
    expect(out4, "\x1b[4mab\x1b[0m", "underline");
}

fn test_colors() {
    var out: u8[>..] = [];
    ansi::color256(out, "x", 208);
    expect(out, "\x1b[38;5;208mx\x1b[0m", "color256");

    var out2: u8[>..] = [];
    ansi::truecolor(out2, "x", 255, 128, 0);
    expect(out2, "\x1b[38;2;255;128;0mx\x1b[0m", "truecolor");

    var out3: u8[>..] = [];
    ansi::bg_red(out3, "x");
    expect(out3, "\x1b[41mx\x1b[0m", "bg_red");

    var out4: u8[>..] = [];
    ansi::bg_color256(out4, "x", 21);
    expect(out4, "\x1b[48;5;21mx\x1b[0m", "bg_color256");

    var out5: u8[>..] = [];
    ansi::bg_truecolor(out5, "x", 10, 20, 30);
    expect(out5, "\x1b[48;2;10;20;30mx\x1b[0m", "bg_truecolor");
}

fn test_clamp() {
    var out: u8[>..] = [];
    ansi::color256(out, "x", 999);
    expect(out, "\x1b[38;5;255mx\x1b[0m", "clamp high");

    var out2: u8[>..] = [];
    ansi::color256(out2, "x", -3);
    expect(out2, "\x1b[38;5;0mx\x1b[0m", "clamp low");
}

fn test_strip() {
    var out: u8[>..] = [];
    ansi::strip(out, "\x1b[31mred\x1b[0m");
    expect(out, "red", "strip basic");

    var out2: u8[>..] = [];
    ansi::strip(out2, "a\x1b[1;38;5;9mb\x1b[0mc");
    expect(out2, "abc", "strip nested params");

    var out3: u8[>..] = [];
    ansi::strip(out3, "plain");
    expect(out3, "plain", "strip plain");

    // Another kind of escape stays.
    var out4: u8[>..] = [];
    ansi::strip(out4, "\x1b[2Jx");
    expect(out4, "\x1b[2Jx", "strip keeps non-sgr");
}

fn test_len() {
    assert(ansi::len("\x1b[31mred\x1b[0m") == 3);
    assert(ansi::len("plain") == 5);
    assert(ansi::len("") == 0);
    assert(ansi::len("\x1b[1ma\x1b[0m\x1b[31mb\x1b[0m") == 2);
}

fn test_width() {
    // Latin: one column.
    assert(ansi::char_width('a') == 1);
    // Hangul: two columns.
    assert(ansi::char_width(0xAC00) == 2);
    // CJK: two columns.
    assert(ansi::char_width(0x4E00) == 2);
    // Fullwidth forms: two columns.
    assert(ansi::char_width(0xFF21) == 2);
    // Halfwidth katakana: one column.
    assert(ansi::char_width(0xFF65) == 1);
    // An emoji: two columns.
    assert(ansi::char_width(0x1F600) == 2);
    // The Hangul Jamo block: two columns.
    assert(ansi::char_width(0x1100) == 2);
    // A narrow symbol: one column.
    assert(ansi::char_width(0x0041) == 1);
}

fn test_truncate() {
    var out: u8[>..] = [];
    ansi::truncate(out, "\x1b[31mred text\x1b[0m", 3);
    expect(out, "\x1b[31mred\x1b[0m", "truncate styled");

    var out2: u8[>..] = [];
    ansi::truncate(out2, "plain text", 5);
    expect(out2, "plain", "truncate plain");

    var out3: u8[>..] = [];
    ansi::truncate(out3, "short", 10);
    expect(out3, "short", "truncate no cut");

    var out4: u8[>..] = [];
    ansi::truncate(out4, "\x1b[31mabc\x1b[0m", 0);
    expect(out4, "", "truncate zero");

    // A wide character is not cut in half.
    var out5: u8[>..] = [];
    ansi::truncate(out5, "\xc3\xa9\xc3\xa9\xc3\xa9", 3);
    // Each of these is 1 column (Latin small e with acute, not wide).
    expect(out5, "\xc3\xa9\xc3\xa9\xc3\xa9", "truncate narrow utf8");

    // Two wide characters, width 3: only the first fits.
    var out6: u8[>..] = [];
    ansi::truncate(out6, "\xe6\xbc\xa2\xe6\xbc\xa2", 3);
    expect(out6, "\xe6\xbc\xa2", "truncate wide");

    // An emoji takes two columns.
    assert(ansi::len("\xf0\x9f\x98\x80") == 2);
    var out7: u8[>..] = [];
    ansi::truncate(out7, "\xf0\x9f\x98\x80a", 2);
    expect(out7, "\xf0\x9f\x98\x80", "truncate emoji");
}

fn test_capability() {
    assert(ansi::enabled_with(true, "xterm-256color") == false);
    assert(ansi::enabled_with(false, "dumb") == false);
    assert(ansi::enabled_with(false, "xterm-256color") == true);
    assert(ansi::enabled_with(false, "") == true);
}

fn main() {
    test_attributes();
    test_colors();
    test_clamp();
    test_strip();
    test_len();
    test_width();
    test_truncate();
    test_capability();
    print("all tests passed");
    return 0;
}
