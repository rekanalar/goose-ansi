// Makes test/support_cases.goose for goose-ansi from chalk 6.0.1.
//
// Usage, in the package directory, with chalk 6.0.1 installed in CHALK_DIR:
//   CHALK_DIR=/path/to/dir node test/make_support_cases.mjs > test/support_cases.goose
//
// Every case holds an environment, a tty flag, an argument list and the
// level that supports-color of chalk gave. The environment is a text of
// NAME=value lines. NO_COLOR and COLORTERM=24bit are not generated: the
// package differs from chalk there, and the README says so. The seed is
// fixed, so the output is stable. The count goes to standard error.
import {pathToFileURL} from 'node:url';

const dir = process.env.CHALK_DIR;
if (!dir) throw new Error('set CHALK_DIR');
const mod = pathToFileURL(dir + '/node_modules/chalk/source/vendor/supports-color/index.js').href;
const KEYS = ['FORCE_COLOR','TERM','COLORTERM','CI','GITHUB_ACTIONS','GITEA_ACTIONS','CIRCLECI','TRAVIS','APPVEYOR','GITLAB_CI','BUILDKITE','DRONE','CI_NAME','TF_BUILD','AGENT_NAME','TEAMCITY_VERSION','TERM_PROGRAM','TERM_PROGRAM_VERSION','NO_COLOR'];
let n = 0;
async function oracle(env, tty, flags) {
  for (const k of KEYS) delete process.env[k];
  Object.assign(process.env, env);
  process.argv = ['node', 'x', ...flags];
  const m = await import(mod + '?c=' + (n++));
  const r = m.createSupportsColor({isTTY: tty});
  return r ? r.level : 0;
}

let state = 20261107;
function rnd() { state = (state + 0x6D2B79F5) | 0; let t = Math.imul(state ^ (state >>> 15), 1 | state); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }
const pick = (a) => a[Math.floor(rnd() * a.length)];

const D = {
  FORCE_COLOR: [undefined, undefined, '', '0', '1', '2', '3', '4', '10', 'true', 'false', 'abc', '2x'],
  TERM: [undefined, 'dumb', 'xterm', 'xterm-256color', 'screen', 'linux', 'vt100', 'foo', 'xterm-kitty', 'xterm-ghostty', 'wezterm', 'XTERM-256COLOR', 'rxvt-unicode-256color', 'ansi', 'x-256'],
  COLORTERM: [undefined, undefined, 'truecolor', '1', ''],
  CI: [undefined, undefined, '1', ''],
  KIND: [undefined, undefined, 'GITHUB_ACTIONS', 'GITEA_ACTIONS', 'CIRCLECI', 'TRAVIS', 'GITLAB_CI', 'APPVEYOR', 'BUILDKITE', 'DRONE', 'CI_NAME=codeship', 'CI_NAME=other'],
  AZ: [undefined, undefined, 'both', 'tf', 'agent'],
  TEAM: [undefined, undefined, '9.0.1', '9.1.0', '9.0.0', '9.00001.2', '9.10.0', '10.0.0', '8.1', '100.1', 'abc', '', '9', '9.', '2023.05.4'],
  TP: [undefined, undefined, 'iTerm.app', 'Apple_Terminal', 'vscode'],
  TPV: [undefined, '', '2.9', '3.0.1', '3', 'x', '10.1', '03'],
  TTY: [true, false],
  FLAGS: [[], [], [], ['--color'], ['--no-color'], ['--color=256'], ['--color=16m'], ['--color=full'], ['--color=truecolor'], ['--color=false'], ['--color=never'], ['--color=true'], ['--color=always'], ['--colors'], ['--no-colors'], ['--color', '--', '--no-color'], ['--', '--color'], ['--color=256', '--no-color'], ['--color', '--color=256'], ['--colour']],
};
const cases = [];
const mk = (r) => {
  const env = {};
  const set = (k, v) => { if (v !== undefined) env[k] = v; };
  set('FORCE_COLOR', pick(D.FORCE_COLOR)); set('TERM', pick(D.TERM)); set('COLORTERM', pick(D.COLORTERM));
  set('CI', pick(D.CI));
  const kind = pick(D.KIND);
  if (kind) { if (kind.startsWith('CI_NAME=')) env.CI_NAME = kind.slice(8); else env[kind] = '1'; }
  const az = pick(D.AZ);
  if (az === 'both') { env.TF_BUILD = 'True'; env.AGENT_NAME = 'a'; } else if (az === 'tf') env.TF_BUILD = 'True'; else if (az === 'agent') env.AGENT_NAME = 'a';
  set('TEAMCITY_VERSION', pick(D.TEAM)); set('TERM_PROGRAM', pick(D.TP)); set('TERM_PROGRAM_VERSION', pick(D.TPV));
  return {env, tty: pick(D.TTY), flags: pick(D.FLAGS)};
};
for (let i = 0; i < 2500; i++) cases.push(mk());
const single = [
  {TERM: 'xterm'}, {TERM: 'xterm', CI: '1'}, {TERM: 'xterm', CI: '1', GITHUB_ACTIONS: '1'}, {TERM: 'xterm', CI: '1', TRAVIS: '1'},
  {TERM: 'xterm', CI: '1', CI_NAME: 'codeship'}, {TERM: 'xterm', TF_BUILD: 'True', AGENT_NAME: 'a'}, {TERM: 'xterm', TEAMCITY_VERSION: '9.1.0'},
  {TERM: 'xterm', TEAMCITY_VERSION: '8.1'}, {TERM: 'xterm', TERM_PROGRAM: 'iTerm.app', TERM_PROGRAM_VERSION: '3.4.1'},
  {TERM: 'xterm', TERM_PROGRAM: 'iTerm.app', TERM_PROGRAM_VERSION: '2.9'}, {TERM: 'xterm', TERM_PROGRAM: 'Apple_Terminal'},
  {TERM: 'xterm', FORCE_COLOR: ''}, {TERM: 'xterm', CI: '1', GITHUB_ACTIONS: '1', FORCE_COLOR: '1'},
];
for (const env of single) for (const tty of [true, false]) cases.push({env, tty, flags: []});
for (const f of D.FLAGS) for (const tty of [true, false]) cases.push({env: {TERM: 'xterm-256color'}, tty, flags: f});

const q = (s) => '"' + s + '"';
const out = [];
const w = (s) => out.push(s);
w('namespace support_cases;');
w('');
w('import std;');
w('import ansi from "..";');
w('');
w('// split_args cuts the text at spaces into an argument list.');
w('fn split_args(text: const u8[:], out: const u8[:][>..]&) {');
w('    var start = 0;');
w('    var i = 0;');
w('    while i <= text.len {');
w('        if i == text.len || text[i] == \' \' {');
w('            if i > start { out.push(text[start..i]); }');
w('            start = i + 1;');
w('        }');
w('        i += 1;');
w('    }');
w('}');
w('');
w('// level_case sets each NAME=value line of the text, then checks the level.');
w('fn level_case(id: i64, tty: bool, lines: const u8[:], flags: const u8[:], want: i64) {');
w('    var e = ansi::empty_color_env();');
w('    var start = 0;');
w('    var i = 0;');
w('    while i <= lines.len {');
w('        if i == lines.len || lines[i] == \'\\n\' {');
w('            let line = lines[start..i];');
w('            var eq = 0;');
w('            while eq < line.len && line[eq] != \'=\' { eq += 1; }');
w('            if eq < line.len { ansi::color_env_set(e, line[0..eq], line[eq + 1..]); }');
w('            start = i + 1;');
w('        }');
w('        i += 1;');
w('    }');
w('    var args: const u8[:][>..] = [];');
w('    split_args(flags, args);');
w('    let f = ansi::color_flags(args[..]);');
w('    let got = ansi::color_level_env(tty, e, f);');
w('    if got != want { print("FAIL case ", id, " tty=", tty, " env=[", lines, "] flags=[", flags, "] want ", want, " got ", got); }');
w('    assert(got == want);');
w('}');
w('');
w('fn check_support() {');
let id = 0;
for (const c of cases) {
  const want = await oracle(c.env, c.tty, c.flags);
  const lines = Object.entries(c.env).map(([k, v]) => k + '=' + v).join('\\n');
  w(`    level_case(${id++}, ${c.tty}, ${q(lines)}, ${q(c.flags.join(' '))}, ${want});`);
}
w('}');
out.splice(1, 0, '// Cases made by test/make_support_cases.mjs with chalk 6.0.1, seed 20261107. Count: ' + cases.length + '.', '// Do not edit by hand. Make the file again with the script.');
process.stdout.write(out.join('\n') + '\n');
process.stderr.write('cases: ' + cases.length + '\n');
