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
