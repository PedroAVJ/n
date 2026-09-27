import Base
import ../../../general/http/type.bend as H
import ../../../general/http/ops.bend as HO

# Serving HTTP over TCP: each connection is read to a whole request, answered by the handler, and closed,
# in a computation of its own so a slow answer does not hold the others up.

def sent(r: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case (s, _):
      Socket.close(s)

def respond(sock: Socket, +response: H.Response) -> IO(Unit):
  do IO<Unit>:
    r : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(sock, HO.print(response))
    sent(r)

# Whether what has arrived holds the whole head and as many body bytes as Content-Length says.
def whole.of(m: Maybe<&2, Sigma<&2, &2, String, _ => String>>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{(head, body)}:
      Nat.is_ge(HO.bytes(body), Maybe.default(&2, Nat, Nat.read(HO.get(HO.headers(String.lines(head)), "content-length")), 0n))

def whole(+s: String) -> Bool:
  whole.of(HO.cut(s, "\r\n\r\n"))

def got(r: Socket & Result<&1, &1, U32 & String, String>) -> Socket & String:
  match r:
    case (s, Done{t}):
      (s, t)
    case (s, Fail{_}):
      (s, "")

# Reads until the request is whole, the peer stops, or the fuel runs out. A socket is used once, so each
# decision is a match, and the steps call one another below them: they are unsafe, and the fuel bounds them.
@unsafe def more(fuel: Nat, sock: Socket, +acc: String) -> IO(Socket & String):
  match fuel:
    case 0n:
      IO.pure(Socket & String, (sock, acc))
    case 1n+k:
      step(whole(acc), k, sock, acc)

@unsafe def step(done: Bool, fuel: Nat, sock: Socket, +acc: String) -> IO(Socket & String):
  match done:
    case True{}:
      IO.pure(Socket & String, (sock, acc))
    case False{}:
      do IO<Socket & String>:
        r : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(sock, 65536)
        joined(fuel, got(r), acc)

@unsafe def joined(fuel: Nat, st: Socket & String, +acc: String) -> IO(Socket & String):
  match st:
    case (s, +t):
      grown(String.is_empty(t), fuel, s, acc, t)

@unsafe def grown(stopped: Bool, fuel: Nat, sock: Socket, +acc: String, +t: String) -> IO(Socket & String):
  match stopped:
    case True{}:
      IO.pure(Socket & String, (sock, acc))
    case False{}:
      more(fuel, sock, acc ++ t)

def request.of(+s: String) -> H.Request:
  HO.request(HO.before(s, "\r\n\r\n"), HO.after(s, "\r\n\r\n"))

def answered(~handle: H.Request -> IO(H.Response), st: Socket & String) -> IO(Unit):
  match st:
    case (s, +raw):
      do IO<Unit>:
        response : H.Response <- handle(request.of(raw))
        respond(s, response)

def connection(~handle: H.Request -> IO(H.Response), sock: Socket) -> IO(Unit):
  do IO<Unit>:
    r : Socket & String <- more(256n, sock, "")
    answered(~handle, r)

def accepted(~handle: H.Request -> IO(H.Response), r: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match r:
    case (l, Done{sock}):
      do IO<Listener>:
        _ : Chan(Unit) <- IO.fork(Unit, connection(~handle, sock))
        return l
    case (l, Fail{_}):
      IO.pure(Listener, l)

# Serving never ends on its own, so its loop is unsafe: it recurses for as long as the program runs.
@unsafe def loop(~handle: H.Request -> IO(H.Response), listener: Listener) -> IO(Unit):
  do IO<Unit>:
    r : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    l : Listener <- accepted(~handle, r)
    loop(~handle, l)

def listening(~handle: H.Request -> IO(H.Response), r: Result<&1, &1, U32 & String, Listener>, +port: U32) -> IO(Unit):
  match r:
    case Done{l}:
      do IO<Unit>:
        IO.print("serving on 127.0.0.1:" ++ U32.show(port))
        loop(~handle, l)
    case Fail{_}:
      IO.die(Unit, 1, "cannot listen on port " ++ U32.show(port))

def serve(~handle: H.Request -> IO(H.Response), +port: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Listener> <- TCP.listen(port)
    listening(~handle, r, port)
