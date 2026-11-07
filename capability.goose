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

// is_digits tells whether s is one or more ASCII digits.
fn is_digits(s: u8[:]) -> bool {
    if s.len == 0 { return false; }
    for c in s {
        if c < '0' || c > '9' { return false; }
    }
    return true;
}

// term_level gives the level that the name of the terminal alone gives.
// The rules and their order are those of supports-color in chalk 6.0.1.
// It gives -1 when no rule fits.
fn term_level(term: u8[:], colorterm: u8[:]) -> i64 {
    if colorterm == "truecolor" || colorterm == "24bit" { return 3; }
    if term == "xterm-kitty" || term == "xterm-ghostty" || term == "wezterm" { return 3; }
    var low: u8[>..] = [];
    low.append(term);
    to_lower(low[..]);
    let t = low[..];
    if ends_with(t, "-256") || ends_with(t, "-256color") { return 2; }
    if starts_with(t, "screen") || starts_with(t, "xterm") || starts_with(t, "vt100") { return 1; }
    if starts_with(t, "vt220") || starts_with(t, "rxvt") { return 1; }
    if find(t, "color") >= 0 || find(t, "ansi") >= 0 || find(t, "cygwin") >= 0 || find(t, "linux") >= 0 { return 1; }
    if colorterm.len > 0 { return 1; }
    return -1;
}

// color_level_tty gives the colour level for the environment. is_tty says
// whether the stream is a terminal; the caller knows, the package cannot ask.
// force is FORCE_COLOR. The empty string means not set, for force and for
// colorterm. The order follows chalk 6.0.1, with two differences: NO_COLOR
// gives 0 when FORCE_COLOR does not decide, and COLORTERM=24bit gives 3.
fn color_level_tty(is_tty: bool, no_color: bool, term: u8[:], colorterm: u8[:], force: u8[:]) -> i64 {
    var min = 0;
    var forced = false;
    if force == "false" { return 0; }
    if force == "true" {
        forced = true;
        min = 1;
    } else if is_digits(force) {
        // The value is a level. Stop adding at 4, so a long string is safe.
        var n = 0;
        for c in force {
            if n < 4 { n = n * 10 + (c - '0'); }
        }
        if n > 3 { return 3; }
        return n;
    }
    if !forced {
        if no_color || !is_tty { return 0; }
    }
    if term == "dumb" { return min; }
    let l = term_level(term, colorterm);
    if l >= 0 { return l; }
    return min;
}

// color_level_with holds the logic for a terminal, so a test can pass the
// inputs directly.
fn color_level_with(no_color: bool, term: u8[:], colorterm: u8[:], force: u8[:]) -> i64 {
    return color_level_tty(true, no_color, term, colorterm, force);
}

// color_level_stream reads the whole environment and the program
// arguments, and gives the level for a stream. chalk gives supportsColor
// for the stdout stream and supportsColorStderr for the stderr stream. The
// two differ only by the terminal flag.
fn color_level_stream(is_tty: bool) -> i64 {
    let e = read_color_env();
    let argv = args();
    var list: const u8[:][>..] = [];
    for a in argv { list.push(a); }
    let f = color_flags(list[..]);
    return color_level_env(is_tty, e, f);
}

// color_level returns the colour level for a terminal: 0 none, 1 sixteen
// colours, 2 the 256 palette, 3 truecolor.
fn color_level() -> i64 {
    return color_level_stream(true);
}

// ColorEnv holds what the level rules read from the environment, as
// values and not as text, so it owns nothing. The has_ flags tell a
// variable that is set and empty from one that is not set.
//
// force is the level that FORCE_COLOR names: -1 when the variable is not
// set or has another text, 0 for false, 1 for true or an empty value, and
// 0 to 3 for a number. force_numeric is true for a number.
struct ColorEnv {
    force: i64,
    force_numeric: bool,
    term_dumb: bool,
    term_top: bool,
    term_256: bool,
    term_basic: bool,
    colorterm_true: bool,
    has_colorterm: bool,
    has_teamcity: bool,
    teamcity_ok: bool,
    term_program: i64,
    term_program_version: i64,
    ci: bool,
    ci_github: bool,
    ci_other: bool,
    ci_codeship: bool,
    tf_build: bool,
    agent_name: bool,
    no_color: bool,
}

// ColorFlags holds what the program arguments say. force is -1 for no
// flag, 0 for a flag that turns colour off, and 1 for a flag that turns it
// on. exact is -1, or the level that --color=256 or --color=16m names.
struct ColorFlags {
    force: i64,
    exact: i64,
}

// empty_color_env gives an environment with no variable set.
fn empty_color_env() -> ColorEnv {
    return ColorEnv { force: -1, force_numeric: false, term_dumb: false, term_top: false, term_256: false, term_basic: false, colorterm_true: false, has_colorterm: false, has_teamcity: false, teamcity_ok: false, term_program: 0, term_program_version: -1, ci: false, ci_github: false, ci_other: false, ci_codeship: false, tf_build: false, agent_name: false, no_color: false };
}

// teamcity_passes tells whether a TeamCity version has colour. The rule of
// supports-color is the pattern 9.0*[1-9][0-9]*. or [0-9]{2,}. at the
// start.
fn teamcity_passes(v: const u8[:]) -> bool {
    var i = 0;
    while i < v.len && v[i] >= '0' && v[i] <= '9' { i += 1; }
    if i >= v.len || v[i] != '.' { return false; }
    if i >= 2 { return true; }
    if i != 1 || v[0] != '9' { return false; }
    // After 9. a run of digits with one that is not zero, then a dot.
    var j = 2;
    var nonzero = false;
    while j < v.len && v[j] >= '0' && v[j] <= '9' {
        if v[j] != '0' { nonzero = true; }
        j += 1;
    }
    return nonzero && j < v.len && v[j] == '.';
}

// leading_int reads the integer at the start of the text up to the first
// dot, as parseInt does. It gives -1 when there is none. At most nine
// digits count.
fn leading_int(v: const u8[:]) -> i64 {
    var i = 0;
    while i < v.len && (v[i] == ' ' || v[i] == '\t') { i += 1; }
    if i < v.len && v[i] == '+' { i += 1; }
    var n: i64 = 0;
    var digits = 0;
    while i < v.len && v[i] >= '0' && v[i] <= '9' {
        if digits < 9 { n = n * 10 + (v[i] - '0'); }
        digits += 1;
        i += 1;
    }
    if digits == 0 { return -1; }
    return n;
}

// color_env_set records one variable of the process environment in e.
// A name that the rules do not read is ignored.
fn color_env_set(e: ColorEnv&, name: const u8[:], value: const u8[:]) {
    if name == "FORCE_COLOR" {
        e.force_numeric = false;
        e.force = -1;
        if value == "false" {
            e.force = 0;
        } else if value == "true" || value.len == 0 {
            e.force = 1;
        } else if is_digits(value) {
            var n = 0;
            for c in value {
                if n < 4 { n = n * 10 + (c - '0'); }
            }
            if n > 3 { n = 3; }
            e.force = n;
            e.force_numeric = true;
        }
    } else if name == "TERM" {
        var low: u8[>..] = [];
        low.append(value);
        to_lower(low[..]);
        let t = low[..];
        e.term_dumb = value == "dumb";
        e.term_top = value == "xterm-kitty" || value == "xterm-ghostty" || value == "wezterm";
        e.term_256 = ends_with(t, "-256") || ends_with(t, "-256color");
        e.term_basic = starts_with(t, "screen") || starts_with(t, "xterm") || starts_with(t, "vt100") || starts_with(t, "vt220") || starts_with(t, "rxvt") || find(t, "color") >= 0 || find(t, "ansi") >= 0 || find(t, "cygwin") >= 0 || find(t, "linux") >= 0;
    } else if name == "COLORTERM" {
        e.has_colorterm = true;
        e.colorterm_true = value == "truecolor" || value == "24bit";
    } else if name == "TEAMCITY_VERSION" {
        e.has_teamcity = true;
        e.teamcity_ok = teamcity_passes(value);
    } else if name == "TERM_PROGRAM" {
        e.term_program = 0;
        if value == "iTerm.app" { e.term_program = 1; }
        if value == "Apple_Terminal" { e.term_program = 2; }
    } else if name == "TERM_PROGRAM_VERSION" {
        e.term_program_version = leading_int(value);
    } else if name == "CI" {
        e.ci = true;
    } else if name == "GITHUB_ACTIONS" || name == "GITEA_ACTIONS" || name == "CIRCLECI" {
        e.ci_github = true;
    } else if name == "TRAVIS" || name == "APPVEYOR" || name == "GITLAB_CI" || name == "BUILDKITE" || name == "DRONE" {
        e.ci_other = true;
    } else if name == "CI_NAME" {
        e.ci_codeship = value == "codeship";
    } else if name == "TF_BUILD" {
        e.tf_build = true;
    } else if name == "AGENT_NAME" {
        e.agent_name = true;
    } else if name == "NO_COLOR" {
        e.no_color = true;
    }
}

// read_color_env reads the variables of the rules from the process
// environment.
fn read_color_env() -> ColorEnv {
    var e = empty_color_env();
    let names: const u8[:][] = ["FORCE_COLOR", "TERM", "COLORTERM", "CI", "GITHUB_ACTIONS", "GITEA_ACTIONS", "CIRCLECI", "TRAVIS", "APPVEYOR", "GITLAB_CI", "BUILDKITE", "DRONE", "CI_NAME", "TF_BUILD", "AGENT_NAME", "TEAMCITY_VERSION", "TERM_PROGRAM", "TERM_PROGRAM_VERSION", "NO_COLOR"];
    for name in names {
        var value: u8[>..] = [];
        if env(name, value) { color_env_set(e, name, value[..]); }
    }
    return e;
}

// has_flag tells whether an argument before the first "--" is --name.
fn has_flag(args: const u8[:][:], stop: i64, name: const u8[:]) -> bool {
    var i: i64 = 0;
    while i < stop {
        let a = args[i];
        if a.len == name.len + 2 && a[0] == '-' && a[1] == '-' && a[2..] == name { return true; }
        i += 1;
    }
    return false;
}

// color_flags reads the program arguments by the rule of has-flag: an
// argument after "--" has no effect.
fn color_flags(args: const u8[:][:]) -> ColorFlags {
    var stop: i64 = args.len;
    var i: i64 = 0;
    while i < args.len {
        if args[i] == "--" { stop = i; break; }
        i += 1;
    }
    var f = ColorFlags { force: -1, exact: -1 };
    if has_flag(args, stop, "no-color") || has_flag(args, stop, "no-colors") || has_flag(args, stop, "color=false") || has_flag(args, stop, "color=never") {
        f.force = 0;
    } else if has_flag(args, stop, "color") || has_flag(args, stop, "colors") || has_flag(args, stop, "color=true") || has_flag(args, stop, "color=always") {
        f.force = 1;
    }
    if has_flag(args, stop, "color=16m") || has_flag(args, stop, "color=full") || has_flag(args, stop, "color=truecolor") {
        f.exact = 3;
    } else if has_flag(args, stop, "color=256") {
        f.exact = 2;
    }
    return f;
}

// color_level_env gives the colour level for a stream by the rules of
// supports-color in chalk 6.0.1, in their order. Two rules differ from
// chalk: NO_COLOR gives 0 when nothing forces colour, and COLORTERM of
// 24bit gives 3. The rule for Windows is not in the package.
fn color_level_env(is_tty: bool, e: ColorEnv&, f: ColorFlags&) -> i64 {
    // FORCE_COLOR from the environment wins over the flags.
    var force = e.force;
    if force < 0 { force = f.force; }
    if force == 0 { return 0; }
    if f.exact >= 0 { return f.exact; }
    if force >= 0 && e.force_numeric { return force; }
    if e.tf_build && e.agent_name { return 1; }
    if force < 0 && (e.no_color || !is_tty) { return 0; }
    var min = 0;
    if force > 0 { min = force; }
    if e.term_dumb { return min; }
    if e.ci {
        if e.ci_github { return 3; }
        if e.ci_other || e.ci_codeship { return 1; }
        return min;
    }
    if e.has_teamcity {
        if e.teamcity_ok { return 1; }
        return 0;
    }
    if e.colorterm_true || e.term_top { return 3; }
    if e.term_program != 0 {
        if e.term_program == 1 {
            if e.term_program_version >= 3 { return 3; }
            return 2;
        }
        if e.term_program == 2 { return 2; }
    }
    if e.term_256 { return 2; }
    if e.term_basic { return 1; }
    if e.has_colorterm { return 1; }
    return min;
}
