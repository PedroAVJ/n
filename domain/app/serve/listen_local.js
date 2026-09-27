// The JS twin of listen_local.c: Base's tcp_listen.js on 127.0.0.1.


function listen_local(port) {
  const sys = io_sys();
  const fd = sys.socket(2, 1, 0);
  if (fd < 0) {
    return io_fail(sys.errno());
  }
  const one = new Int32Array([1]);
  const level = sys.mac ? 0xffff : 1;
  sys.setsockopt(fd, level, sys.mac ? 4 : 2, sys.ptr(one), 4);
  const at = io_addr("127.0.0.1", Number(port));
  if (at === null) {
    sys.close(fd);
    return io_fail(22);
  }
  if (sys.bind(fd, sys.ptr(at), 16) < 0 || sys.listen(fd, 512) < 0
    || sys.fcntl(fd, 4, sys.fcntl(fd, 3, 0) | (sys.mac ? 4 : 0x800)) < 0) {
    const code = sys.errno();
    sys.close(fd);
    return io_fail(code);
  }
  return io_done(fd);
}

io_eff(CID(listen_local), listen_local);
