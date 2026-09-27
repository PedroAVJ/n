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
import ../domain/architecture/system/effs/io.bend as X
import bend-kit-files@0.1.0.0/files.bend as Fs

# N's editor: .n documents written until each says exactly one thing. The first # heading is a document's
# title; the Markdown renders beside it as it is written. Jev screens the draft whenever typing pauses; N
# check has Claude check the whole document (type errors, then lint), giving each finding its fix or its
# readings, and a choice replaces the phrase.
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

# ---- the pages ----
def wide_style() -> S.Style:
  S.Style{[S.MaxWidth{S.Px{1280n}}, S.Centered{}, S.Padding{S.Px{28n}}, S.Flex{S.Column{}}, S.Gap{S.Px{14n}},
    S.Family{S.Sans{}}, S.Foreground{ink()}, S.Background{paper()}, S.MinHeight{S.Percent{100n}}],
    [S.When{S.Dark{}, [S.Foreground{mist()}, S.Background{night()}]}, S.When{S.Below{S.Px{600n}}, [S.Padding{S.Px{14n}}]}]}

def columns_style() -> S.Style:
  S.Style{[S.Flex{S.Row{}}, S.Gap{S.Px{18n}}], [S.When{S.Below{S.Px{900n}}, [S.Flex{S.Column{}}]}]}

def half_style() -> S.Style:
  S.Style{[S.Width{S.Percent{50n}}], [S.When{S.Below{S.Px{900n}}, [S.Width{S.Percent{100n}}]}]}

def document_style() -> S.Style:
  S.Style{[S.Width{S.Percent{100n}}, S.MinHeight{S.Px{560n}}, S.Padding{S.Px{16n}}, S.FontSize{S.Px{15n}},
    S.Family{S.Mono{}}, S.Border{S.Px{1n}, mist()}, S.Radius{S.Px{10n}}, S.Background{S.Rgb{255n, 255n, 255n}}, S.Foreground{ink()}],
    [S.When{S.Focus{}, [S.Border{S.Px{1n}, accent()}]}, S.When{S.Dark{}, [S.Background{S.Rgb{32n, 32n, 35n}}, S.Foreground{mist()}, S.Border{S.Px{1n}, S.Rgb{60n, 60n, 64n}}]}]}

def preview_style() -> S.Style:
  S.Style{[S.Padding{S.Px{4n}}, S.FontSize{S.Px{16n}}, S.Family{S.Sans{}}], []}

def link_style() -> S.Style:
  S.Style{[S.Foreground{ink()}, S.Padding{S.Px{12n}}, S.Border{S.Px{1n}, mist()}, S.Radius{S.Px{10n}}, S.Flex{S.Column{}}, S.Gap{S.Px{4n}}],
    [S.When{S.Hover{}, [S.Border{S.Px{1n}, accent()}]}, S.When{S.Dark{}, [S.Foreground{mist()}, S.Border{S.Px{1n}, S.Rgb{60n, 60n, 64n}}]}]}

def back_style() -> S.Style:
  S.Style{[S.Foreground{dim()}, S.FontSize{S.Px{14n}}, S.Padding{S.Px{10n}}], []}

def field_style() -> S.Style:
  S.Style{[S.Padding{S.Px{10n}}, S.FontSize{S.Px{15n}}, S.Border{S.Px{1n}, mist()}, S.Radius{S.Px{8n}}, S.Background{S.Rgb{255n, 255n, 255n}}, S.Foreground{ink()}],
    [S.When{S.Focus{}, [S.Border{S.Px{1n}, accent()}]}, S.When{S.Dark{}, [S.Background{S.Rgb{32n, 32n, 35n}}, S.Foreground{mist()}]}]}

def entry(+name: String, +title: String) -> Ht.Html:
  Ht.Link{"/d/" ++ name, link_style(), [Ht.Span{title_style(), [Ht.Text{title}]}, Ht.Span{hint_style(), [Ht.Text{name ++ ".n"}]}]}

def index(entries: List<&2, Ht.Html>) -> Ht.Document:
  Ht.Document{"N", [Ht.Main{page_style(), [
    Ht.Heading{title_style(), "N"},
    Ht.Paragraph{hint_style(), [Ht.Text{"Documents that say exactly one thing. Each is a .n file."}]},
    Ht.Div{row_style(), [Ht.Field{"name", "New document's name", "Name (letters, digits, - and _), like V", field_style()}, Ht.Button{"create", "New", [], button_style()}]},
    Ht.Region{"status", status_style(), []},
    Ht.Div{list_style(), entries}]}], "/app.js"}

def editor(+name: String, +content: String) -> Ht.Document:
  Ht.Document{name ++ " · N", [Ht.Main{wide_style(), [
    Ht.Div{row_style(), [Ht.Link{"/", back_style(), [Ht.Text{"← Documents"}]}, Ht.Region{"status", status_style(), []}]},
    Ht.Region{"title", title_style(), [Ht.Text{name}]},
    Ht.Div{columns_style(), [
      Ht.Div{half_style(), [Ht.TextArea{"draft", "Document", "# " ++ name ++ "\n\nWhat it is, exactly.", content, document_style()}]},
      Ht.Div{half_style(), [Ht.Region{"preview", preview_style(), []}]}]},
    Ht.Div{row_style(), [
      Ht.Button{"save", "Save", [], quiet_style()},
      Ht.Button{"check", "N check", [], button_style()},
      Ht.Button{"copy", "Copy", [], quiet_style()}]},
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
    out : String <- E.claude(C.type_prompt(text))
    return fragment(finding_cards(text, C.findings(C.text(C.at(Json.parse(out), "result")), text)))

# ---- documents: .n files in one folder, named by letters, digits, - and _ ----
def folder() -> IO(String):
  do IO<String>:
    +home : String <- X.home()
    return home ++ "/Library/Application Support/N/documents"

def name_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c) || Char.is_eq(c, '-') || Char.is_eq(c, '_')

def name_chars(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case +c <> rest:
      name_char(c) && name_chars(rest)

def name_ok(+n: String) -> Bool:
  Nat.is_ge(String.length(n), 1n) && Nat.is_le(String.length(n), 64n) && name_chars(String.to_list(n))

def title_of(ls: List<&2, String>, +fallback: String) -> String:
  match ls:
    case []:
      fallback
    case +l <> rest:
      Bool.pick(String, String.starts_with(l, "# "), String.trim(String.drop(l, 2n)), title_of(rest, fallback))

def names(fs: List<&2, String>) -> List<&2, String>:
  match fs:
    case []:
      []
    case +f <> rest:
      +r = names(rest)
      Bool.pick(List<&2, String>, String.ends_with(f, ".n") && name_ok(String.take(f, Nat.sub(String.length(f), 2n))), String.take(f, Nat.sub(String.length(f), 2n)) <> r, r)

def entries(ns: List<&2, String>, +dir: String) -> IO(List<&2, Ht.Html>):
  match ns:
    case []:
      IO.pure(List<&2, Ht.Html>, [])
    case +n <> rest:
      do IO<List<&2, Ht.Html>>:
        head : String <- X.read_head(dir ++ "/" ++ n ++ ".n", 4096)
        more : List<&2, Ht.Html> <- entries(rest, dir)
        return entry(n, title_of(String.lines(head), n)) <> more

def html(+text: String) -> H.Response:
  H.Response{H.Ok{}, "text/html; charset=utf-8", text}

def plain(s: H.Status, +text: String) -> H.Response:
  H.Response{s, "text/plain; charset=utf-8", text}

def listing() -> IO(H.Response):
  do IO<H.Response>:
    +dir : String <- folder()
    _ : Bool <- X.succeeds("/bin/mkdir", ["-p", dir])
    r : Result<&1, &1, U32 & String, List<&2, String>> <- Fs.list_dir(dir)
    es : List<&2, Ht.Html> <- entries(names(Result.default(&1, &1, U32 & String, List<&2, String>, r, [])), dir)
    return html(HtO.document(index(es)))

def opened(+name: String) -> IO(H.Response):
  do IO<H.Response>:
    +dir : String <- folder()
    exists : Bool <- X.succeeds("/bin/test", ["-f", dir ++ "/" ++ name ++ ".n"])
    content : String <- X.read(dir ++ "/" ++ name ++ ".n")
    return Bool.pick(H.Response, exists, html(HtO.document(editor(name, content))), plain(H.NotFound{}, "No document " ++ name))

def saved(+name: String, +body: String) -> IO(H.Response):
  do IO<H.Response>:
    +dir : String <- folder()
    X.write(dir ++ "/" ++ name ++ ".n", body)
    return plain(H.Ok{}, "Saved")

def created(+name: String) -> IO(H.Response):
  do IO<H.Response>:
    +dir : String <- folder()
    _ : Bool <- X.succeeds("/bin/mkdir", ["-p", dir])
    exists : Bool <- X.succeeds("/bin/test", ["-f", dir ++ "/" ++ name ++ ".n"])
    Bool.pick(IO(Unit), exists, IO.pure(Unit, Unit{}), X.write(dir ++ "/" ++ name ++ ".n", "# " ++ name ++ "\n\n"))
    return plain(H.Ok{}, "/d/" ++ name)

# ---- the glue: what the browser does, and nothing it decides ----
def script() -> String:
  "const $=id=>document.getElementById(id);\nconst post=async(u,b)=>{const r=await fetch(u,{method:'POST',headers:{'content-type':'text/plain; charset=utf-8'},body:b});return r.text()};\nconst esc=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');\nconst inl=s=>esc(s).replace(/`([^`]+)`/g,'<code>$1</code>').replace(/\\*\\*([^*]+)\\*\\*/g,'<strong>$1</strong>').replace(/\\*([^*]+)\\*/g,'<em>$1</em>').replace(/\\[([^\\]]+)\\]\\(([^)\\s]+)\\)/g,'<a href=\"$2\">$1</a>');\nfunction md(t){let o='',p=[],l=null,c=null;const fp=()=>{if(p.length){o+='<p>'+inl(p.join(' '))+'</p>';p=[]}},fl=()=>{if(l){o+='</'+l+'>';l=null}};\nfor(const r of t.split('\\n')){if(c!==null){if(r.startsWith('```')){o+='<pre><code>'+esc(c)+'</code></pre>';c=null}else c+=(c?'\\n':'')+r;continue}\nif(r.startsWith('```')){fp();fl();c='';continue}let m=r.match(/^(#{1,6})\\s+(.*)$/);if(m){fp();fl();o+='<h'+m[1].length+'>'+inl(m[2])+'</h'+m[1].length+'>';continue}\nm=r.match(/^\\s*([-*]|\\d+\\.)\\s+(.*)$/);if(m){fp();const k=/\\d/.test(m[1])?'ol':'ul';if(l!==k){fl();o+='<'+k+'>';l=k}o+='<li>'+inl(m[2])+'</li>';continue}\nif(!r.trim()){fp();fl();continue}fl();p.push(r)}fp();fl();if(c!==null)o+='<pre><code>'+esc(c)+'</code></pre>';return o}\nconst d=$('draft');\nif(d){const f=$('findings'),s=$('status'),pv=$('preview'),ti=$('title');let t,saved=d.value;\nconst title=()=>{const m=d.value.match(/^#\\s+(.+)$/m);const x=m?m[1].trim():location.pathname.slice(3);ti.textContent=x;document.title=x+' · N'};\nconst show=()=>{pv.innerHTML=md(d.value);title();s.textContent=d.value===saved?'Saved':'Unsaved'};\nconst save=async()=>{const v=d.value;await post(location.pathname,v);saved=v;s.textContent=d.value===saved?'Saved':'Unsaved'};\nshow();\nd.addEventListener('input',()=>{show();clearTimeout(t);f.innerHTML='';if(!d.value.trim()||d.value.length>8000)return;t=setTimeout(async()=>{const v=d.value;const h=await post('/api/screen',v);if(d.value===v)f.innerHTML=h},1200)});\ndocument.addEventListener('keydown',e=>{if((e.metaKey||e.ctrlKey)&&e.key==='s'){e.preventDefault();save()}});\n$('save').addEventListener('click',save);\n$('check').addEventListener('click',async()=>{if(!d.value.trim())return;s.textContent='N checking the whole document…';const t0=Date.now();f.innerHTML=await post('/api/check',d.value);s.textContent='Checked in '+((Date.now()-t0)/1000).toFixed(1)+'s · '+(d.value===saved?'Saved':'Unsaved')});\n$('copy').addEventListener('click',async()=>{await navigator.clipboard.writeText(d.value);s.textContent='Copied'});\nf.addEventListener('click',e=>{const b=e.target.closest('button[data-choice]');if(!b)return;const a=+b.dataset.start,z=+b.dataset.end,cs=[...d.value];d.value=cs.slice(0,a).join('')+b.dataset.choice+cs.slice(z).join('');b.closest('div[class]').parentElement===f?b.closest('div[class]').remove():null;f.innerHTML='';show();d.focus()});}\nconst n=$('name');\nif(n){const go=async()=>{const v=n.value.trim();if(!v)return;const r=await post('/new',v);if(r.startsWith('/d/'))location=r;else $('status').textContent=r};\n$('create').addEventListener('click',go);n.addEventListener('keydown',e=>{if(e.key==='Enter')go()});}"

# ---- routes ----
def document(+m: String, +name: String, +body: String) -> IO(H.Response):
  Bool.pick(IO(H.Response), Bool.not(name_ok(name)), IO.pure(H.Response, plain(H.BadRequest{}, "A document's name is letters, digits, - and _")),
    Bool.pick(IO(H.Response), String.eq(m, "POST"), saved(name, body), opened(name)))

def route(+m: String, +path: String, +body: String) -> IO(H.Response):
  Bool.pick(IO(H.Response), String.eq(path, "/"), listing(),
    Bool.pick(IO(H.Response), String.eq(path, "/app.js"), IO.pure(H.Response, H.Response{H.Ok{}, "text/javascript; charset=utf-8", script()}),
      Bool.pick(IO(H.Response), String.starts_with(path, "/d/"), document(m, String.drop(path, 3n), body),
        Bool.pick(IO(H.Response), String.eq(m, "POST") && String.eq(path, "/new"),
          Bool.pick(IO(H.Response), name_ok(String.trim(body)), created(String.trim(body)), IO.pure(H.Response, plain(H.BadRequest{}, "A document's name is letters, digits, - and _"))),
          Bool.pick(IO(H.Response), String.eq(m, "POST") && String.eq(path, "/api/screen"), screen(body),
            Bool.pick(IO(H.Response), String.eq(m, "POST") && String.eq(path, "/api/check"), deep(body),
              IO.pure(H.Response, plain(H.NotFound{}, "Not found"))))))))

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
