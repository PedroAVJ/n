// V: run a program with its arguments, no shell, and answer its standard output.
// Arguments arrive as one string separated by \x1f (the unit separator). Standard error is discarded.
// Fails with the exit status when the program does not exit 0.
// Temporary: bend-kit-process does this, but its 0.1.0.0 runs on Bend 2.0.27 only, and
// bend-kit-files needs 2.0.28 or later.

#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

extern char** environ;

Term v_program_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0, m = 0;
  char* cmd = io_cstr(e, f[0], &n);
  char* args = io_cstr(e, f[1], &m);
  int argc = 1;
  for (uint64_t i = 0; i < m; i++) if (args[i] == 0x1f) argc++;
  char** argv = malloc(sizeof(char*) * (argc + 2));
  argv[0] = cmd;
  int k = 1;
  if (m > 0) {
    argv[k++] = args;
    for (uint64_t i = 0; i < m; i++) if (args[i] == 0x1f) { args[i] = 0; argv[k++] = args + i + 1; }
  }
  argv[k] = NULL;
  int fd[2];
  if (pipe(fd) != 0) { free(argv); free(cmd); free(args); return io_fail(e, errno, NULL); }
  posix_spawn_file_actions_t fa;
  posix_spawn_file_actions_init(&fa);
  posix_spawn_file_actions_adddup2(&fa, fd[1], 1);
  posix_spawn_file_actions_addclose(&fa, fd[0]);
  posix_spawn_file_actions_addopen(&fa, 2, "/dev/null", O_WRONLY, 0);
  pid_t pid;
  int err = posix_spawnp(&pid, cmd, &fa, NULL, argv, environ);
  posix_spawn_file_actions_destroy(&fa);
  close(fd[1]);
  free(argv); free(cmd); free(args);
  if (err != 0) { close(fd[0]); return io_fail(e, (uint32_t)err, "cannot run the program"); }
  size_t cap = 4096, len = 0;
  char* buf = malloc(cap);
  ssize_t got;
  while ((got = read(fd[0], buf + len, cap - len)) > 0) {
    len += (size_t)got;
    if (len == cap) { cap *= 2; buf = realloc(buf, cap); }
  }
  close(fd[0]);
  int status = 0;
  waitpid(pid, &status, 0);
  int code = WIFEXITED(status) ? WEXITSTATUS(status) : 128;
  if (code != 0) { free(buf); return io_fail(e, (uint32_t)code, "the program failed"); }
  Term out = io_str(e, buf, len);
  free(buf);
  return io_done(e, out);
}

static void __attribute__((constructor)) v_program_run_use(void) {
  io_eff(CID(Program.run), v_program_run, 0);
}
