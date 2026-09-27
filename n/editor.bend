import Base
import bend-net-json@0.3.0.0/json.bend as Json
import ../general/http/type.bend as H
import ../domain/app/style/type.bend as S
import ../domain/app/html/type.bend as Ht
import ../domain/app/html/ops.bend as HtO
import ../domain/app/serve/effects.bend as Sv
import ./type.bend as T
import ./check.bend as C
import ./effects.bend as E

# N's editor: a page where a prompt is written until it is exact. Jev screens the draft whenever typing
# pauses; N check has Claude give each finding its readings or its fix, and a reading replaces the phrase.
# The server, the page and its styles are Bend; the browser gets HTML and a few lines of glue.
#   n editor [port]   serve on 127.0.0.1:<port> (4610 when absent); $N_KEYCHAIN names the OpenRouter key's item

# ---- the look ----
def ink() -> S.Color:
  S.Rgb{28n, 27n, 26n}

def paper() -> S.Color:
  S.Rgb{250n, 249n, 246n}

def night() -> S.Color:
  S.Rgb{22n, 22n, 24n}

def mist() -> S.Color:
  S.Rgb{236n, 234n, 230n}

def dim() -> S.Color:
  S.Rgb{110n, 106n, 100n}

def accent() -> S.Color:
  S.Rgb{194n, 65n, 12n}

def page_style() -> S.Style:
  S.Style{[S.MaxWidth{S.Px{760n}}, S.Centered{}, S.Padding{S.Px{32n}}, S.Flex{S.Column{}}, S.Gap{S.Px{16n}},
    S.Family{S.Sans{}}, S.Foreground{ink()}, S.Background{paper()}, S.MinHeight{S.Percent{100n}}],
    [S.When{S.Dark{}, [S.Foreground{mist()}, S.Background{night()}]}, S.When{S.Below{S.Px{600n}}, [S.Padding{S.Px{16n}}]}]}

def title_style() -> S.Style:
  S.Style{[S.FontSize{S.Px{28n}}, S.Weight{600n}, S.Margin{S.Px{0n}}], []}

def hint_style() -> S.Style:
  S.Style{[S.Foreground{dim()}, S.Margin{S.Px{0n}}, S.FontSize{S.Px{14n}}], []}

def draft_style() -> S.Style:
  S.Style{[S.Width{S.Percent{100n}}, S.MinHeight{S.Px{220n}}, S.Padding{S.Px{14n}}, S.FontSize{S.Px{17n}},
    S.Family{S.Sans{}}, S.Border{S.Px{1n}, mist()}, S.Radius{S.Px{10n}}, S.Background{S.Rgb{255n, 255n, 255n}}, S.Foreground{ink()}],
    [S.When{S.Focus{}, [S.Border{S.Px{1n}, accent()}]}, S.When{S.Dark{}, [S.Background{S.Rgb{32n, 32n, 35n}}, S.Foreground{mist()}, S.Border{S.Px{1n}, S.Rgb{60n, 60n, 64n}}]}]}

def row_style() -> S.Style:
  S.Style{[S.Flex{S.Row{}}, S.Gap{S.Px{10n}}], []}

def button_style() -> S.Style:
  S.Style{[S.Padding{S.Px{10n}}, S.Radius{S.Px{8n}}, S.Border{S.Px{1n}, ink()}, S.Background{ink()}, S.Foreground{paper()}, S.Pointer{}, S.FontSize{S.Px{15n}}],
    [S.When{S.Hover{}, [S.Background{accent()}, S.Border{S.Px{1n}, accent()}]}, S.When{S.Dark{}, [S.Background{mist()}, S.Foreground{night()}, S.Border{S.Px{1n}, mist()}]}]}

def quiet_style() -> S.Style:
  S.Style{[S.Padding{S.Px{10n}}, S.Radius{S.Px{8n}}, S.Border{S.Px{1n}, mist()}, S.Background{S.Transparent{}}, S.Foreground{ink()}, S.Pointer{}, S.FontSize{S.Px{15n}}],
    [S.When{S.Hover{}, [S.Border{S.Px{1n}, accent()}]}, S.When{S.Dark{}, [S.Foreground{mist()}]}]}

def status_style() -> S.Style:
  S.Style{[S.Foreground{dim()}, S.FontSize{S.Px{14n}}, S.Padding{S.Px{10n}}], []}

def card_style() -> S.Style:
  S.Style{[S.Padding{S.Px{14n}}, S.Radius{S.Px{10n}}, S.Border{S.Px{1n}, mist()}, S.Flex{S.Column{}}, S.Gap{S.Px{8n}}],
    [S.When{S.Dark{}, [S.Border{S.Px{1n}, S.Rgb{60n, 60n, 64n}}]}]}

def flagged_style() -> S.Style:
  S.Style{[S.Weight{600n}, S.Underline{accent()}, S.Margin{S.Px{0n}}], []}

def plain_style() -> S.Style:
  S.Style{[S.Margin{S.Px{0n}}], []}

def list_style() -> S.Style:
  S.Style{[S.Flex{S.Column{}}, S.Gap{S.Px{10n}}], []}

# ---- the page ----
def page() -> Ht.Document:
  Ht.Document{"N", [Ht.Main{page_style(), [
    Ht.Heading{title_style(), "N"},
    Ht.Paragraph{hint_style(), [Ht.Text{"Write the prompt until it has one reading. Jev screens it as you pause; N check asks Claude for the readings."}]},
    Ht.TextArea{"draft", "Prompt", "What do you want done?", draft_style()},
    Ht.Div{row_style(), [
      Ht.Button{"check", "N check", [], button_style()},
      Ht.Button{"copy", "Copy", [], quiet_style()},
      Ht.Region{"status", status_style(), []}]},
    Ht.Region{"findings", list_style(), []}]}], "/app.js"}

# ---- findings, as fragments the page swaps in ----
def span_of(+text: String, +start: Nat, +t: String) -> String:
  String.take(String.drop(text, C.trimmed_start(text, start, t)), String.length(t))

def jev_cards(+text: String, ms: List<&2, C.Mark>) -> List<&2, Ht.Html>:
  match ms:
    case []:
      []
    case C.Mark{C.Phrase{T.Span{start, _}, +t}, +issue} <> rest:
      Ht.Div{card_style(), [
        Ht.Paragraph{flagged_style(), [Ht.Text{span_of(text, start, t)}]},
        Ht.Paragraph{plain_style(), [Ht.Text{C.issue_question(issue)}]},
        Ht.Paragraph{hint_style(), [Ht.Text{"Jev: " ++ issue ++ ". N check for readings."}]}]} <> jev_cards(text, rest)

def choice(+start: Nat, +end: Nat, +t: String) -> Ht.Html:
  Ht.Button{"choice", t, [Ht.Datum{"start", Nat.show(start)}, Ht.Datum{"end", Nat.show(end)}, Ht.Datum{"choice", t}], quiet_style()}

def choices(+start: Nat, +end: Nat, rs: List<&2, T.Reading>) -> List<&2, Ht.Html>:
  match rs:
    case []:
      []
    case T.Reading{_, t} <> rest:
      choice(start, end, t) <> choices(start, end, rest)

def finding_card(+text: String, f: C.Finding) -> Ht.Html:
  match f:
    case C.Finding{T.Unconfirmed{_, T.Reading{T.Span{+start, +end}, new}}, _, why, _}:
      Ht.Div{card_style(), [
        Ht.Paragraph{flagged_style(), [Ht.Text{String.take(String.drop(text, start), Nat.sub(end, start))}]},
        Ht.Paragraph{plain_style(), [Ht.Text{why}]},
        Ht.Div{row_style(), [choice(start, end, new)]}]}
    case C.Finding{T.Ambiguous{_, T.Span{+start, +end}, rs}, _, why, question}:
      Ht.Div{card_style(), [
        Ht.Paragraph{flagged_style(), [Ht.Text{String.take(String.drop(text, start), Nat.sub(end, start))}]},
        Ht.Paragraph{plain_style(), [Ht.Text{question}]},
        Ht.Paragraph{hint_style(), [Ht.Text{why}]},
        Ht.Div{list_style(), choices(start, end, rs)}]}
    case C.Finding{_, _, why, _}:
      Ht.Div{card_style(), [Ht.Paragraph{plain_style(), [Ht.Text{why}]}]}

def finding_cards(+text: String, fs: List<&2, C.Finding>) -> List<&2, Ht.Html>:
  match fs:
    case []:
      []
    case f <> rest:
      finding_card(text, f) <> finding_cards(text, rest)

def clear() -> List<&2, Ht.Html>:
  [Ht.Paragraph{hint_style(), [Ht.Text{"One reading. Nothing to settle."}]}]

def fragment(+cards: List<&2, Ht.Html>) -> H.Response:
  H.Response{H.Ok{}, "text/html; charset=utf-8", HtO.fragment(Bool.pick(List<&2, Ht.Html>, List.is_empty(&2, Ht.Html, cards), clear(), cards))}

# ---- the checks ----
def screen(+text: String) -> IO(H.Response):
  do IO<H.Response>:
    item : String <- E.env("N_KEYCHAIN")
    +k : String <- E.key(item)
    +ps : List<&2, C.Phrase> = C.phrases(text)
    response : String <- E.ask(E.decisions_url(), k, Json.encode(C.request("typesafe/jev-1.13", "", text, ps)))
    return fragment(jev_cards(text, C.marks(response, ps)))

def deep(+text: String) -> IO(H.Response):
  do IO<H.Response>:
    out : String <- E.claude(C.checker_prompt("", text, []))
    return fragment(finding_cards(text, C.findings(C.text(C.at(Json.parse(out), "result")), text)))

# ---- the glue: what the browser does, and nothing it decides ----
def script() -> String:
  "const d=document.getElementById('draft'),f=document.getElementById('findings'),s=document.getElementById('status');let t;" ++
  "const post=async(u)=>{const r=await fetch(u,{method:'POST',headers:{'content-type':'text/plain; charset=utf-8'},body:d.value});return r.text()};" ++
  "d.addEventListener('input',()=>{clearTimeout(t);f.innerHTML='';if(!d.value.trim())return;t=setTimeout(async()=>{const v=d.value;const h=await post('/api/screen');if(d.value===v)f.innerHTML=h},900)});" ++
  "document.getElementById('check').addEventListener('click',async()=>{if(!d.value.trim())return;s.textContent='N checking…';const t0=Date.now();f.innerHTML=await post('/api/check');s.textContent='Checked in '+((Date.now()-t0)/1000).toFixed(1)+'s'});" ++
  "document.getElementById('copy').addEventListener('click',async()=>{await navigator.clipboard.writeText(d.value);s.textContent='Copied'});" ++
  "f.addEventListener('click',e=>{const b=e.target.closest('button[data-choice]');if(!b)return;const a=+b.dataset.start,z=+b.dataset.end,cs=[...d.value];d.value=cs.slice(0,a).join('')+b.dataset.choice+cs.slice(z).join('');f.innerHTML='';s.textContent='Replaced';d.focus()});"

# ---- routes ----
def route(+m: String, +path: String, +body: String) -> IO(H.Response):
  Bool.pick(IO(H.Response), String.eq(path, "/"), IO.pure(H.Response, H.Response{H.Ok{}, "text/html; charset=utf-8", HtO.document(page())}),
    Bool.pick(IO(H.Response), String.eq(path, "/app.js"), IO.pure(H.Response, H.Response{H.Ok{}, "text/javascript; charset=utf-8", script()}),
      Bool.pick(IO(H.Response), String.eq(m, "POST") && String.eq(path, "/api/screen"), screen(String.trim(body)),
        Bool.pick(IO(H.Response), String.eq(m, "POST") && String.eq(path, "/api/check"), deep(String.trim(body)),
          IO.pure(H.Response, H.Response{H.NotFound{}, "text/plain; charset=utf-8", "Not found"})))))

def method_name(m: H.Method) -> String:
  match m:
    case H.Get{}:
      "GET"
    case H.Post{}:
      "POST"
    case H.Other{n}:
      n

def handle(r: H.Request) -> IO(H.Response):
  match r:
    case H.Request{m, path, _, _, body}:
      route(method_name(m), path, body)

def run(+port: U32) -> IO(Unit):
  Sv.serve(~handle, port)
