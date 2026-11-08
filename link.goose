// OSC 8 hyperlinks for the ansi package.
//
// The form is ESC ] 8 ; ; URL BEL, the text, ESC ] 8 ; ; BEL. This is the
// form of terminal-link.

namespace ansi;

import std;
import os;

// osc8_url writes the URL bytes that the OSC 8 form allows. The OSC 8
// spec allows only bytes 32 to 126 in the URI. Every other byte becomes
// %XX with uppercase hex, so a BEL or ESC in the URL cannot end the
// sequence early.
fn osc8_url(out: u8[>..]&, url: u8[:]) {
    let digits = "0123456789ABCDEF";
    for b in url {
        if b >= 32 && b <= 126 {
            out.push(b);
        } else {
            out.push('%');
            out.push(digits[b >> 4]);
            out.push(digits[b & 15]);
        }
    }
}

// link writes the text as a hyperlink to url.
fn link(out: u8[>..]&, text: u8[:], url: u8[:]) {
    out.append("\x1b]8;;");
    osc8_url(out, url);
    out.push(0x07);
    out.append(text);
    out.append("\x1b]8;;\x07");
}

// link_with writes a hyperlink when supported is true. Else it writes
// "text (url)", the fall back of terminal-link.
fn link_with(out: u8[>..]&, text: u8[:], url: u8[:], supported: bool) {
    if supported { link(out, text, url); return; }
    out.append(text);
    out.append(" (");
    osc8_url(out, url);
    out.push(')');
}

// links_supported_with holds the logic. force is FORCE_HYPERLINK, vte is
// VTE_VERSION. An empty string means the variable is not set.
fn links_supported_with(force: u8[:], term_program: u8[:], vte: u8[:], term: u8[:]) -> bool {
    if force.len > 0 { return force != "0"; }
    if term_program == "iTerm.app" || term_program == "WezTerm" || term_program == "vscode" || term_program == "ghostty" { return true; }
    if term == "xterm-kitty" || term == "xterm-ghostty" { return true; }
    if vte.len > 0 {
        let v, ok = parse_int(vte);
        if ok && v >= 5000 { return true; }
    }
    return false;
}

// links_supported reads the environment at every call. It does not test
// for a terminal. The caller decides that.
fn links_supported() -> bool {
    var force: u8[>..] = [];
    env("FORCE_HYPERLINK", force);
    var tp: u8[>..] = [];
    env("TERM_PROGRAM", tp);
    var vte: u8[>..] = [];
    env("VTE_VERSION", vte);
    var term: u8[>..] = [];
    env("TERM", term);
    return links_supported_with(force, tp, vte, term);
}
