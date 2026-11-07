// Tests for the ansi package. Run with: goose run test/run.goose
//
// Every assert here is one acceptance scenario from the spec. A failed
// assert names its line.

import std;
import ansi from "..";
import chalk_cases;
import support_cases;
import os;

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

    // A UTF-8 sequence cut at the end of the text.
    var cut: u8[>..] = [];
    ansi::strip(cut, "\xe6\xbc");
    expect(cut, "\xe6\xbc", "strip truncated utf8");

    var cut2: u8[>..] = [];
    ansi::truncate(cut2, "\xe6\xbc", 2);
    expect(cut2, "\xe6\xbc", "truncate truncated utf8");

    // An escape sequence without an end.
    var open: u8[>..] = [];
    ansi::strip(open, "\x1b[31");
    expect(open, "\x1b[31", "strip open escape");

    // Every CSI sequence goes: cursor move, erase, private mode.
    var out4: u8[>..] = [];
    ansi::strip(out4, "\x1b[2Jx\x1b[10;5Hy\x1b[?25lz\x1b[3A");
    expect(out4, "xyz", "strip csi");

    // OSC sequences go, with a BEL end or an ST end.
    var out5: u8[>..] = [];
    ansi::strip(out5, "\x1b]8;;http://a.b\x07link\x1b]8;;\x07 \x1b]0;title\x1b\\ok");
    expect(out5, "link ok", "strip osc");

    // An OSC without an end stays.
    var out6: u8[>..] = [];
    ansi::strip(out6, "a\x1b]8;;x");
    expect(out6, "a\x1b]8;;x", "strip open osc");
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

fn test_bright() {
    var out: u8[>..] = [];
    ansi::bright_red(out, "x");
    expect(out, "\x1b[91mx\x1b[0m", "bright_red");
    var out2: u8[>..] = [];
    ansi::bg_bright_white(out2, "x");
    expect(out2, "\x1b[107mx\x1b[0m", "bg_bright_white");
    var out3: u8[>..] = [];
    ansi::bright_black(out3, "x");
    expect(out3, "\x1b[90mx\x1b[0m", "bright_black");
}

fn test_levels() {
    // Level 3 keeps truecolor.
    var a: u8[>..] = [];
    ansi::truecolor_at(a, "x", 255, 128, 0, 3);
    expect(a, "\x1b[38;2;255;128;0mx\x1b[0m", "level 3");
    // Level 2 lowers to the palette. chalk gives 214 for 255,128,0.
    var b: u8[>..] = [];
    ansi::truecolor_at(b, "x", 255, 128, 0, 2);
    expect(b, "\x1b[38;5;214mx\x1b[0m", "level 2");
    // Level 1 lowers to 16 colours. Bright yellow for 255,128,0.
    var c: u8[>..] = [];
    ansi::truecolor_at(c, "x", 255, 128, 0, 1);
    expect(c, "\x1b[93mx\x1b[0m", "level 1");
    // Level 0 writes the plain text.
    var d: u8[>..] = [];
    ansi::truecolor_at(d, "x", 255, 128, 0, 0);
    expect(d, "x", "level 0");
    // Background forms.
    var e: u8[>..] = [];
    ansi::bg_truecolor_at(e, "x", 255, 0, 0, 1);
    expect(e, "\x1b[101mx\x1b[0m", "bg level 1");
    var f: u8[>..] = [];
    ansi::bg_truecolor_at(f, "x", 0, 0, 255, 2);
    expect(f, "\x1b[48;5;21mx\x1b[0m", "bg level 2");
    // A palette number at lower levels.
    var g: u8[>..] = [];
    ansi::color256_at(g, "x", 196, 1);
    expect(g, "\x1b[91mx\x1b[0m", "color256 level 1");
    var h: u8[>..] = [];
    ansi::color256_at(h, "x", 196, 2);
    expect(h, "\x1b[38;5;196mx\x1b[0m", "color256 level 2");
    var i: u8[>..] = [];
    ansi::bg_color256_at(i, "x", 4, 1);
    expect(i, "\x1b[44mx\x1b[0m", "bg_color256 level 1");
    var j: u8[>..] = [];
    ansi::color256_at(j, "x", 196, 0);
    expect(j, "x", "color256 level 0");
    // Grays.
    assert(ansi::rgb_to_256(0, 0, 0) == 16);
    assert(ansi::rgb_to_256(255, 255, 255) == 231);
    assert(ansi::rgb_to_256(128, 128, 128) == 244);
    assert(ansi::rgb_to_256(255, 0, 0) == 196);
    assert(ansi::rgb_to_16(0, 0, 0) == 30);
    assert(ansi::rgb_to_16(255, 255, 255) == 97);
    assert(ansi::rgb_to_16(0, 0, 255) == 94);
}

fn test_color_level() {
    assert(ansi::color_level_with(false, "xterm-256color", "truecolor", "") == 3);
    assert(ansi::color_level_with(false, "xterm-256color", "", "") == 2);
    assert(ansi::color_level_with(false, "xterm", "", "") == 1);
    assert(ansi::color_level_with(true, "xterm-256color", "truecolor", "") == 0);
    assert(ansi::color_level_with(false, "dumb", "", "") == 0);
    assert(ansi::color_level_with(true, "xterm", "", "2") == 2);
    assert(ansi::color_level_with(false, "xterm-256color", "", "0") == 0);
    // 0.2.0 gave 1. FORCE_COLOR=true sets a minimum of 1 and then detects, as chalk does.
    assert(ansi::color_level_with(false, "xterm-256color", "", "true") == 2);
    assert(ansi::color_level_with(false, "xterm", "", "true") == 1);
}

fn test_support_cases() {
    support_cases::check_support();
}

fn test_detect_rules() {
    var e = ansi::empty_color_env();
    ansi::color_env_set(e, "TERM", "xterm");
    ansi::color_env_set(e, "CI", "1");
    ansi::color_env_set(e, "GITHUB_ACTIONS", "1");
    let none = ansi::color_flags([]);
    assert(ansi::color_level_env(true, e, none) == 3);
    var t = ansi::empty_color_env();
    ansi::color_env_set(t, "TERM", "xterm");
    ansi::color_env_set(t, "TEAMCITY_VERSION", "9.1.0");
    assert(ansi::color_level_env(true, t, none) == 1);
    ansi::color_env_set(t, "TEAMCITY_VERSION", "8.1");
    assert(ansi::color_level_env(true, t, none) == 0);
    var z = ansi::empty_color_env();
    ansi::color_env_set(z, "TERM", "xterm");
    ansi::color_env_set(z, "FORCE_COLOR", "");
    assert(ansi::color_level_env(true, z, none) == 1);
    let no = ansi::color_flags(["x", "--no-color"]);
    assert(no.force == 0);
    let after = ansi::color_flags(["x", "--", "--no-color"]);
    assert(after.force == -1);
    let c256 = ansi::color_flags(["x", "--color=256"]);
    assert(c256.exact == 2);
}

fn test_link() {
    var out: u8[>..] = [];
    ansi::link(out, "site", "https://a.b");
    expect(out, "\x1b]8;;https://a.b\x07site\x1b]8;;\x07", "link");
    assert(ansi::len(out) == 4);
    var out2: u8[>..] = [];
    ansi::link_with(out2, "site", "https://a.b", false);
    expect(out2, "site (https://a.b)", "link fallback");
    assert(ansi::links_supported_with("", "iTerm.app", "", "xterm"));
    assert(ansi::links_supported_with("", "", "6003", "xterm"));
    assert(!ansi::links_supported_with("", "", "4000", "xterm"));
    assert(!ansi::links_supported_with("", "Apple_Terminal", "", "xterm"));
    assert(ansi::links_supported_with("1", "", "", "dumb"));
    assert(!ansi::links_supported_with("0", "iTerm.app", "", "xterm"));
}

fn test_ellipsis() {
    var out: u8[>..] = [];
    ansi::truncate_ellipsis(out, "hello world", 6);
    expect(out, "hello\xe2\x80\xa6", "ellipsis plain");
    var out2: u8[>..] = [];
    ansi::truncate_ellipsis(out2, "short", 10);
    expect(out2, "short", "ellipsis fits");
    var out3: u8[>..] = [];
    ansi::truncate_ellipsis(out3, "\x1b[31mhello world\x1b[0m", 6);
    expect(out3, "\x1b[31mhello\x1b[0m\xe2\x80\xa6", "ellipsis styled");
    var out4: u8[>..] = [];
    ansi::truncate_with(out4, "hello world", 8, "...");
    expect(out4, "hello...", "truncate_with");
    assert(ansi::len(out4) == 8);
    // Text that fits keeps its trailing sequence.
    var out5: u8[>..] = [];
    ansi::truncate_ellipsis(out5, "\x1b[31mab\x1b[0m", 5);
    expect(out5, "\x1b[31mab\x1b[0m", "ellipsis fits styled");
    // A cut inside a link closes the link.
    var out6: u8[>..] = [];
    ansi::truncate(out6, "\x1b]8;;http://a\x07abcdef\x1b]8;;\x07", 3);
    expect(out6, "\x1b]8;;http://a\x07abc\x1b]8;;\x07", "truncate link");
}

fn test_wrap() {
    var out: u8[>..] = [];
    ansi::wrap(out, "the quick brown fox", 10, false);
    expect(out, "the quick\nbrown fox", "wrap plain");

    // A long word stays whole without hard.
    var out2: u8[>..] = [];
    ansi::wrap(out2, "abcdefghij kl", 4, false);
    expect(out2, "abcdefghij\nkl", "wrap long word");

    // A long word breaks with hard.
    var out3: u8[>..] = [];
    ansi::wrap(out3, "abcdefghij kl", 4, true);
    expect(out3, "abcd\nefgh\nij\nkl", "wrap hard");

    // The style stays across the break.
    var out4: u8[>..] = [];
    ansi::wrap(out4, "\x1b[31mred green blue\x1b[0m", 9, false);
    expect(out4, "\x1b[31mred green\x1b[0m\n\x1b[31mblue\x1b[0m", "wrap sgr");

    // A reset ends the carry.
    var out5: u8[>..] = [];
    ansi::wrap(out5, "\x1b[1mab\x1b[0m cd ef", 5, false);
    expect(out5, "\x1b[1mab\x1b[0m cd\nef", "wrap after reset");

    // The link stays across the break.
    var out6: u8[>..] = [];
    ansi::wrap(out6, "\x1b]8;;u\x07aa bb\x1b]8;;\x07", 2, false);
    expect(out6, "\x1b]8;;u\x07aa\x1b]8;;\x07\n\x1b]8;;u\x07bb\x1b]8;;\x07", "wrap link");

    // A newline in the text resets the column.
    var out7: u8[>..] = [];
    ansi::wrap(out7, "ab\ncd ef", 5, false);
    expect(out7, "ab\ncd ef", "wrap newline");

    // Wide characters count two columns.
    var out8: u8[>..] = [];
    ansi::wrap(out8, "\xe6\xbc\xa2 \xe6\xbc\xa2", 3, false);
    expect(out8, "\xe6\xbc\xa2\n\xe6\xbc\xa2", "wrap wide");

    // A new colour replaces the old one in the carry.
    var out9: u8[>..] = [];
    ansi::wrap(out9, "\x1b[31ma \x1b[32mb c", 3, false);
    expect(out9, "\x1b[31ma \x1b[32mb\x1b[0m\n\x1b[32mc", "wrap colour replace");
}

// test_chalk_gaps holds the hand cases for the modifiers, the underline
// colour, the hex strings and the level rules of chalk 6.0.1.
fn test_chalk_gaps() {
    var o: u8[>..] = [];
    ansi::overline(o, "x");
    expect(o, "\x1b[53mx\x1b[0m", "overline");
    o = [];
    ansi::hidden(o, "x");
    expect(o, "\x1b[8mx\x1b[0m", "hidden");
    // The plain underline writers do not lower.
    o = [];
    ansi::underline_rgb(o, "x", 255, 136, 0);
    expect(o, "\x1b[58;2;255;136;0mx\x1b[0m", "underline_rgb");
    o = [];
    ansi::underline_color256(o, "x", 200);
    expect(o, "\x1b[58;5;200mx\x1b[0m", "underline_color256");
    // A value outside the range clamps.
    o = [];
    ansi::underline_rgb(o, "x", 300, -5, 2);
    expect(o, "\x1b[58;2;255;0;2mx\x1b[0m", "underline_rgb clamp");
    o = [];
    ansi::underline_color256(o, "x", 300);
    expect(o, "\x1b[58;5;255mx\x1b[0m", "underline_color256 clamp");
    o = [];
    ansi::underline_color256(o, "x", -3);
    expect(o, "\x1b[58;5;0mx\x1b[0m", "underline_color256 clamp low");
    // Level 0 writes the plain text.
    o = [];
    ansi::underline_rgb_at(o, "x", 1, 2, 3, 0);
    expect(o, "x", "underline_rgb_at level 0");
    o = [];
    assert(ansi::hex_at(o, "x", "#ff8800", 0));
    expect(o, "x", "hex_at level 0");
    // The plain hex writers write the truecolor form.
    o = [];
    assert(ansi::hex(o, "x", "#f80"));
    expect(o, "\x1b[38;2;255;136;0mx\x1b[0m", "hex");
    o = [];
    assert(ansi::bg_hex(o, "x", "FF8800"));
    expect(o, "\x1b[48;2;255;136;0mx\x1b[0m", "bg_hex");
    o = [];
    assert(ansi::underline_hex(o, "x", "f80"));
    expect(o, "\x1b[58;2;255;136;0mx\x1b[0m", "underline_hex");
    // A bad string gives false and writes nothing.
    o = [];
    assert(!ansi::hex(o, "x", "##fff"));
    assert(!ansi::bg_hex(o, "x", "#ff88"));
    assert(!ansi::underline_hex(o, "x", ""));
    assert(o.len == 0);

    // wrap keeps an underline colour over a line break, with a zero or a
    // 31 in the parts of the colour.
    var uw: u8[>..] = [];
    ansi::underline_rgb(uw, "aa bb", 255, 0, 31);
    var wrapped: u8[>..] = [];
    ansi::wrap(wrapped, uw[..], 3, false);
    expect(wrapped, "\x1b[58;2;255;0;31maa\x1b[0m\n\x1b[58;2;255;0;31mbb\x1b[0m", "wrap underline rgb");
    var uw2: u8[>..] = [];
    ansi::underline_color256(uw2, "aa bb", 0);
    wrapped = [];
    ansi::wrap(wrapped, uw2[..], 3, false);
    expect(wrapped, "\x1b[58;5;0maa\x1b[0m\n\x1b[58;5;0mbb\x1b[0m", "wrap underline palette");

    // The same for a truecolor foreground. Version 0.2.0 read the zero as a
    // reset and the 31 as a red foreground.
    var tw: u8[>..] = [];
    ansi::truecolor(tw, "aa bb", 255, 0, 31);
    wrapped = [];
    ansi::wrap(wrapped, tw[..], 3, false);
    expect(wrapped, "\x1b[38;2;255;0;31maa\x1b[0m\n\x1b[38;2;255;0;31mbb\x1b[0m", "wrap truecolor zero");
    var bw: u8[>..] = [];
    ansi::bg_truecolor(bw, "aa bb", 0, 0, 0);
    wrapped = [];
    ansi::wrap(wrapped, bw[..], 3, false);
    expect(wrapped, "\x1b[48;2;0;0;0maa\x1b[0m\n\x1b[48;2;0;0;0mbb\x1b[0m", "wrap bg truecolor black");

    // The level rules.
    assert(ansi::color_level_tty(true, true, "xterm-256color", "", "") == 0);
    assert(ansi::color_level_tty(true, true, "xterm-256color", "", "2") == 2);
    assert(ansi::color_level_tty(true, false, "xterm", "24bit", "") == 3);
    assert(ansi::color_level_tty(true, false, "xterm", "", "4") == 3);
    assert(ansi::color_level_tty(true, false, "xterm", "", "10") == 3);
    assert(ansi::color_level_tty(true, false, "xterm-256color", "", "true") == 2);
    assert(ansi::color_level_tty(false, false, "xterm-256color", "", "") == 0);
    assert(ansi::color_level_tty(false, false, "xterm-256color", "", "1") == 1);
    assert(ansi::color_level_tty(true, false, "", "", "") == 0);
    assert(ansi::color_level_tty(true, false, "xterm", "", "abc") == 1);
    // An empty force means not set, so a pipe gives 0.
    assert(ansi::color_level_tty(false, false, "xterm", "", "") == 0);
    assert(ansi::color_level_with(false, "xterm-256color", "", "true") == 2);
    assert(ansi::color_level_with(false, "xterm", "", "4") == 3);
    // A long force string is read in one pass.
    var long_force: u8[>..] = [];
    for i in 0..10000 { long_force.push('7'); }
    let t0 = clock_ns();
    assert(ansi::color_level_tty(true, false, "xterm", "", long_force[..]) == 3);
    var long_hex: u8[>..] = [];
    for i in 0..100000 { long_hex.push('f'); }
    var lo: u8[>..] = [];
    assert(!ansi::hex(lo, "x", long_hex[..]));
    assert(clock_ns() - t0 < 1000000000);
    // The stream level reads the environment. With a terminal it equals
    // color_level. Without one it is 0 unless FORCE_COLOR is set.
    assert(ansi::color_level_stream(true) == ansi::color_level());
    var force: u8[>..] = [];
    if !env("FORCE_COLOR", force) {
        assert(ansi::color_level_stream(false) == 0);
    }
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
    test_bright();
    test_levels();
    test_color_level();
    test_detect_rules();
    test_support_cases();
    test_link();
    test_ellipsis();
    test_wrap();
    test_chalk_gaps();
    chalk_cases::check_modifiers();
    chalk_cases::check_colors();
    chalk_cases::check_lowering();
    chalk_cases::check_hex();
    chalk_cases::check_hex_bad();
    chalk_cases::check_levels();
    print("all tests passed");
    return 0;
}
