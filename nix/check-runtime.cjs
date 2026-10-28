// Exercise the installed native modules with the same runtime as Desktop Host.
const { createRequire } = require('node:module');
const requireRuntime = createRequire(`${process.argv[2]}/package.json`);
const addon = requireRuntime('node-addon-require-builtin');
if (typeof addon.requireBuiltin('internal/bootstrap/realm').internalBinding !== 'function') {
  throw new Error('Node internal access is unavailable');
}

let output = '';
const terminal = requireRuntime('node-pty').spawn(process.argv[3], ['-c', 'printf nixos-dsh-pty-ok'], {
  name: 'xterm', cols: 80, rows: 24, cwd: process.env.HOME, env: process.env,
});
const deadline = setTimeout(() => { terminal.kill(); process.exit(1); }, 10000);
terminal.onData((data) => { output += data; });
terminal.onExit(({ exitCode }) => {
  clearTimeout(deadline);
  if (exitCode !== 0 || !output.includes('nixos-dsh-pty-ok')) process.exit(1);
  console.log('Node internals and PTY smoke checks passed');
});
