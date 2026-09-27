import Base
import ./type.bend as H

# Parsing a request's head (request line and headers) and printing a response.

# The text before the first `sep`, and after it; None when `sep` is not in `s`.
def cut.go(cs: List<&2, Char>, +sep: String, +before: List<&2, Char>) -> Maybe<&2, Sigma<&2, &2, String, _ => String>>:
  match cs:
    case []:
      None{}
    case +c <> +rest:
      Bool.pick(Maybe<&2, Sigma<&2, &2, String, _ => String>>, String.starts_with(String.from_list(c <> rest), sep),
        Some{(String.from_list(List.reverse(&2, Char, before)), String.drop(String.from_list(c <> rest), String.length(sep)))},
        cut.go(rest, sep, c <> before))

def cut(s: String, +sep: String) -> Maybe<&2, Sigma<&2, &2, String, _ => String>>:
  cut.go(String.to_list(s), sep, [])

def before.of(m: Maybe<&2, Sigma<&2, &2, String, _ => String>>, +s: String) -> String:
  match m:
    case Some{(b, _)}:
      b
    case None{}:
      s

def after.of(m: Maybe<&2, Sigma<&2, &2, String, _ => String>>) -> String:
  match m:
    case Some{(_, a)}:
      a
    case None{}:
      ""

def before(+s: String, +sep: String) -> String:
  before.of(cut(s, sep), s)

def after(+s: String, +sep: String) -> String:
  after.of(cut(s, sep))

def method(+m: String) -> H.Method:
  Bool.pick(H.Method, String.eq(m, "GET"), H.Get{}, Bool.pick(H.Method, String.eq(m, "POST"), H.Post{}, H.Other{m}))

def header(+line: String) -> H.Header:
  H.Header{String.to_lower(String.trim(before(line, ":"))), String.trim(after(line, ":"))}

def headers(ls: List<&2, String>) -> List<&2, H.Header>:
  match ls:
    case []:
      []
    case +l <> rest:
      +r = headers(rest)
      Bool.pick(List<&2, H.Header>, String.is_empty(String.trim(l)), r, header(l) <> r)

def first(xs: List<&2, String>) -> String:
  match xs:
    case []:
      ""
    case x <> _:
      x

def rest(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case _ <> r:
      r

def word(+line: String, +n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, String.split(line, ' '), n), "")

# A request from its head and whatever of its body has arrived.
def request(+head: String, +body: String) -> H.Request:
  +ls = String.lines(head)
  +target = word(String.trim(first(ls)), 1n)
  H.Request{method(word(String.trim(first(ls)), 0n)), before(target, "?"), after(target, "?"), headers(rest(ls)), body}

def get(hs: List<&2, H.Header>, +name: String) -> String:
  match hs:
    case []:
      ""
    case H.Header{+n, +v} <> rest:
      Bool.pick(String, String.eq(n, name), v, get(rest, name))

# ---- printing a response: Content-Length counts UTF-8 bytes ----
def bytes.of(+c: Char) -> Nat:
  +u = Char.to_u32(c)
  Bool.pick(Nat, U32.is_lt(u, 128), 1n, Bool.pick(Nat, U32.is_lt(u, 2048), 2n, Bool.pick(Nat, U32.is_lt(u, 65536), 3n, 4n)))

def bytes.go(cs: List<&2, Char>, +acc: Nat) -> Nat:
  match cs:
    case []:
      acc
    case +c <> rest:
      bytes.go(rest, Nat.add(acc, bytes.of(c)))

def bytes(s: String) -> Nat:
  bytes.go(String.to_list(s), 0n)

def status(s: H.Status) -> String:
  match s:
    case H.Ok{}:
      "200 OK"
    case H.BadRequest{}:
      "400 Bad Request"
    case H.NotFound{}:
      "404 Not Found"
    case H.MethodNotAllowed{}:
      "405 Method Not Allowed"
    case H.BadGateway{}:
      "502 Bad Gateway"

def print(r: H.Response) -> String:
  match r:
    case H.Response{s, t, +body}:
      "HTTP/1.1 " ++ status(s) ++ "\r\nContent-Type: " ++ t ++ "\r\nContent-Length: " ++ Nat.show(bytes(body)) ++
      "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" ++ body
