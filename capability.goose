// The terminal capability check for the ansi package.
//
// The check follows the NO_COLOR convention: the variable NO_COLOR, set to
// any value including the empty one, turns styling off. The terminal name
// dumb turns it off too. Everything else stays on.

namespace ansi;

import std;
import os;

// enabled returns true when the terminal takes styling. It reads the
// environment at every call.
fn enabled() -> bool {
    var value: u8[>..] = [];
    let has_no_color = env("NO_COLOR", value);
    var term: u8[>..] = [];
    env("TERM", term);
    return enabled_with(has_no_color, term);
}

// enabled_with holds the logic, so a test can pass the inputs directly.
fn enabled_with(no_color: bool, term: u8[:]) -> bool {
    if no_color { return false; }
    if term == "dumb" { return false; }
    return true;
}

// color_level returns the colour level: 0 none, 1 sixteen colours, 2 the
// 256 palette, 3 truecolor. The level follows chalk.
fn color_level() -> i64 {
    var no_color: u8[>..] = [];
    let has_no_color = env("NO_COLOR", no_color);
    var term: u8[>..] = [];
    env("TERM", term);
    var colorterm: u8[>..] = [];
    env("COLORTERM", colorterm);
    var force: u8[>..] = [];
    env("FORCE_COLOR", force);
    return color_level_with(has_no_color, term, colorterm, force);
}

// color_level_with holds the logic. force is FORCE_COLOR: "0" to "3", or
// "true" or the empty value for level 1. The empty string means unset. A
// forced level wins over NO_COLOR, as in chalk.
fn color_level_with(no_color: bool, term: u8[:], colorterm: u8[:], force: u8[:]) -> i64 {
    if force.len > 0 {
        if force == "0" || force == "false" { return 0; }
        if force == "2" { return 2; }
        if force == "3" { return 3; }
        return 1;
    }
    if no_color || term == "dumb" { return 0; }
    if colorterm == "truecolor" || colorterm == "24bit" { return 3; }
    if find(term, "256color") >= 0 { return 2; }
    return 1;
}
