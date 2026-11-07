// An example for the ansi package.
//
// It gives the colour level for three environments, as chalk does. The
// environment is set by hand here. A program reads the real one with
// color_level_stream.
//
// Run with: goose run examples/detect.goose
import std;
import ansi from "..";

fn level_for(vars: const u8[:][:], flags: const u8[:][:]) -> i64 {
    var e = ansi::empty_color_env();
    var i = 0;
    while i + 1 < vars.len {
        ansi::color_env_set(e, vars[i], vars[i + 1]);
        i += 2;
    }
    let f = ansi::color_flags(flags);
    return ansi::color_level_env(true, e, f);
}

fn main() {
    let none: const u8[:][] = [];
    print("GitHub Actions: ", level_for(["TERM", "xterm", "CI", "1", "GITHUB_ACTIONS", "1"], none));
    print("iTerm 3:        ", level_for(["TERM", "xterm", "TERM_PROGRAM", "iTerm.app", "TERM_PROGRAM_VERSION", "3.4.1"], none));
    print("--no-color:     ", level_for(["TERM", "xterm-256color"], ["prog", "--no-color"]));
}
