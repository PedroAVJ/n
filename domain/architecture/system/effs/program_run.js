// V: the JS twin of program_run.c: run a program with its arguments, no shell, and answer its
// standard output. Arguments arrive as one string separated by \x1f. Standard error is discarded.
// Temporary, like program_run.c.

function program_run(cmd, args) {
  const c = Buffer.from(io_bytes(cmd)).toString("utf8");
  const a = Buffer.from(io_bytes(args)).toString("utf8");
  const argv = a.length > 0 ? a.split("\x1f") : [];
  const r = require("child_process").spawnSync(c, argv, { stdio: ["ignore", "pipe", "ignore"], maxBuffer: 1 << 30 });
  if (r.error) {
    return io_fail(Math.abs(r.error.errno ?? 5));
  }
  if (r.status !== 0) {
    return io_fail(r.status ?? 128);
  }
  return io_done(r.stdout.toString("utf8"));
}

io_eff(CID(Program.run), program_run);
