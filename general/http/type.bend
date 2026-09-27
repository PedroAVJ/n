import Base

# HTTP/1.1 as data: a request as it arrives, and a response as it leaves.
type Method is Data:
  Get{}
  Post{}
  Other{name: String}

type Header is Data:
  Header{name: String, value: String}

# path is without its query; query is what follows the ?, or "".
type Request is Data:
  Request{method: Method, path: String, query: String, headers: List<&2, Header>, body: String}

type Status is Data:
  Ok{}
  BadRequest{}
  NotFound{}
  MethodNotAllowed{}
  BadGateway{}

type Response is Data:
  Response{status: Status, contentType: String, body: String}
