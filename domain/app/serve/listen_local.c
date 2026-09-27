// Listening on 127.0.0.1 only: Base's TCP.listen binds every interface. A copy of Base's tcp_listen.c
// with its address changed; delete it when Base can listen on one address.

Term listen_local_run(Env e, Term* f, IoWork* w) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return io_fail(e, (uint32_t)errno, NULL);
  }
  int one = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
  struct sockaddr_in at;
  if (io_sys_addr("127.0.0.1", (uint32_t)f[0], &at) < 0) {
    close(fd);
    return io_fail(e, EINVAL, NULL);
  }
  int bound = bind(fd, (struct sockaddr*)&at, sizeof(at));
  if (bound < 0 || listen(fd, 512) < 0
    || fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) {
    uint32_t code = (uint32_t)errno;
    close(fd);
    return io_fail(e, code, NULL);
  }
  return io_done(e, io_hand(fd));
}

static void __attribute__((constructor)) listen_local_use(void) {
  io_eff(CID(listen_local), listen_local_run, 0);
}
