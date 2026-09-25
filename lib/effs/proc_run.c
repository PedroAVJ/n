// V: run a shell command and answer its standard output.
// Fails with the exit status when the command does not exit 0.

Term v_proc_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* cmd = io_cstr(e, f[0], &n);
  FILE* p = popen(cmd, "r");
  free(cmd);
  if (p == NULL) {
    return io_fail(e, errno, NULL);
  }
  size_t cap = 4096, len = 0;
  char* buf = malloc(cap);
  size_t got;
  while ((got = fread(buf + len, 1, cap - len, p)) > 0) {
    len += got;
    if (len == cap) { cap *= 2; buf = realloc(buf, cap); }
  }
  int status = pclose(p);
  int code = WIFEXITED(status) ? WEXITSTATUS(status) : 128;
  if (code != 0) {
    free(buf);
    return io_fail(e, (uint32_t)code, "command failed");
  }
  Term out = io_str(e, buf, len);
  free(buf);
  return io_done(e, out);
}

static void __attribute__((constructor)) v_proc_run_use(void) {
  io_eff(CID_PROC_RUN, v_proc_run, 0);
}
