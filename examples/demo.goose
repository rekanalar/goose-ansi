// An example for the ansi package.
//
// It prints styled lines and shows the measuring functions.
//
// Run with: goose run examples/demo.goose

import std;
import ansi from "..";

fn main() {
    // The styles.
    var line: u8[>..] = [];
    ansi::bold(line, "bold");
    line.append(" ");
    ansi::dim(line, "dim");
    line.append(" ");
    ansi::italic(line, "italic");
    line.append(" ");
    ansi::underline(line, "underline");
    line.append(" ");
    ansi::strike(line, "strike");
    print(line);

    // The colors.
    var colors: u8[>..] = [];
    ansi::red(colors, "red");
    colors.append(" ");
    ansi::green(colors, "green");
    colors.append(" ");
    ansi::yellow(colors, "yellow");
    colors.append(" ");
    ansi::blue(colors, "blue");
    colors.append(" ");
    ansi::magenta(colors, "magenta");
    colors.append(" ");
    ansi::cyan(colors, "cyan");
    print(colors);

    // The background.
    var bg: u8[>..] = [];
    ansi::bg_red(bg, " red background ");
    print(bg);

    // The 256-color palette.
    var ramp: u8[>..] = [];
    for i in 0..24 {
        ansi::color256(ramp, "  ", 16 + i * 10);
    }
    print(ramp);

    // The measuring functions.
    print("");
    var plain: u8[>..] = [];
    ansi::strip(plain, "\x1b[31mred\x1b[0m");
    print("strip: ", plain);

    var styled: u8[>..] = [];
    ansi::red(styled, "red");
    print("len:   ", ansi::len(styled), " columns");

    var cut: u8[>..] = [];
    ansi::truncate(cut, styled, 2);
    print("cut:   ", cut);

    // The capability check.
    if ansi::enabled() {
        print("the terminal takes styling");
    } else {
        print("the terminal does not take styling");
    }
    return 0;
}
