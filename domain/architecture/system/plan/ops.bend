import Base
import ../release/type.bend as Rl
import ../release/ops.bend as RlO
import ../release/plugin/ops.bend as PlO
import ./type.bend as P

def visibility(p: Bool) -> String:
  match p:
    case True{}:
      "public"
    case False{}:
      "private"

# ---- the repository: Bend only and no dead code come first, then GitHub ----
def repo_steps(+fs: List<&2, String>, +reached: List<&2, String>) -> List<&2, P.Step>:
  List.append(&2, P.Step,
    Bool.pick(List<&2, P.Step>, String.is_empty(RlO.not_bend(fs)), [],
      [P.Blocked{"repository", RlO.not_bend(fs) ++ " is not Bend"}]),
    List.append(&2, P.Step,
      Bool.pick(List<&2, P.Step>, String.is_empty(RlO.dead(fs, reached)), [],
        [P.Blocked{"repository", RlO.dead(fs, reached) ++ " is dead code: no entry reaches it"}]),
      Bool.pick(List<&2, P.Step>, String.is_empty(RlO.hub_refused(reached)), [],
        [P.Blocked{"repository", RlO.hub_refused(reached) ++ ": the Bend hub refuses this path (segments of letters, digits and _)"}])))

def remote_step(+repo: Rl.Repository, rm: P.Remote) -> P.Step:
  match repo rm:
    case Rl.Repository{+name, +public} P.Remote{+origin, +vis, clean, pushed}:
      Bool.pick(P.Step, String.contains(origin, name),
        Bool.pick(P.Step, String.eq(vis, visibility(public)),
          Bool.pick(P.Step, clean,
            Bool.pick(P.Step, pushed, P.Current{"github " ++ name}, P.Push{name}),
            P.Blocked{"github " ++ name, "uncommitted changes"}),
          P.Blocked{"github " ++ name, "GitHub says " ++ Bool.pick(String, String.is_empty(vis), "nothing (unreachable)", vis) ++ ", declared " ++ visibility(public)}),
        P.Blocked{"github " ++ name, "origin is " ++ origin})

# ---- each package: already published as it is, new, or changed without a new version ----
def package_step(p: Rl.Package, h: P.Hub) -> P.Step:
  match p:
    case Rl.Package{+n, +v, e, _}:
      match h:
        case P.Same{}:
          P.Current{"package " ++ n ++ "@" ++ v}
        case P.Unpublished{}:
          P.Publish{n, v, e}
        case P.Differs{f}:
          P.Blocked{"package " ++ n ++ "@" ++ v, f ++ " changed since it was published; give it a new version"}

def package_steps(ps: List<&2, Rl.Package>, hs: List<&2, P.Hub>) -> List<&2, P.Step>:
  match ps:
    case []:
      []
    case p <> prest:
      match hs:
        case []:
          []
        case h <> hrest:
          package_step(p, h) <> package_steps(prest, hrest)

# ---- each plugin: released as it builds, new, or changed without a new version ----
def plugin_step(g: Rl.Plugin, t: P.Tag) -> P.Step:
  match g t:
    case Rl.Plugin{+n, ver, _, _, Rl.Repository{+r, _}} P.Tag{repo, tagged, +built, valid, differs}:
      +v = PlO.version_show(ver)
      +what = "plugin " ++ n ++ "@" ++ v
      Bool.pick(P.Step, String.is_empty(built), P.Blocked{what, "does not build"},
        Bool.pick(P.Step, Bool.not(String.eq(built, v)), P.Blocked{what, "builds as version " ++ built},
        Bool.pick(P.Step, Bool.not(valid), P.Blocked{what, "claude plugin validate rejects the build"},
          Bool.pick(P.Step, Bool.not(repo), P.ReleasePlugin{n, v, r, True{}},
            Bool.pick(P.Step, Bool.not(tagged), P.ReleasePlugin{n, v, r, False{}},
              Bool.pick(P.Step, differs, P.Blocked{what, "changed since " ++ n ++ "-v" ++ v ++ " was released; give it a new version"},
                P.Current{what}))))))

def plugin_steps(gs: List<&2, Rl.Plugin>, ts: List<&2, P.Tag>) -> List<&2, P.Step>:
  match gs:
    case []:
      []
    case g <> grest:
      match ts:
        case []:
          []
        case t <> trest:
          plugin_step(g, t) <> plugin_steps(grest, trest)

# The plan: what a deploy would do, from the release and what was observed.
def plan(r: Rl.Release, o: P.Observed) -> List<&2, P.Step>:
  match r o:
    case Rl.Release{repo, ps, gs} P.Observed{+fs, +reached, hs, rm, ts}:
      List.append(&2, P.Step, repo_steps(fs, reached), List.append(&2, P.Step, package_steps(ps, hs),
        List.append(&2, P.Step, plugin_steps(gs, ts), [remote_step(repo, rm)])))

def blocked(s: P.Step) -> Bool:
  match s:
    case P.Blocked{_, _}:
      True{}
    case _:
      False{}

def any_blocked(ss: List<&2, P.Step>) -> Bool:
  match ss:
    case []:
      False{}
    case s <> rest:
      blocked(s) || any_blocked(rest)

def show(s: P.Step) -> String:
  match s:
    case P.Current{w}:
      "current  " ++ w
    case P.Publish{n, v, _}:
      "publish  " ++ n ++ "@" ++ v
    case P.Push{r}:
      "push     github " ++ r
    case P.ReleasePlugin{+n, +v, r, create}:
      "release  plugin " ++ n ++ "@" ++ v ++ " to marketplace github " ++ r ++ " as tag " ++ n ++ "-v" ++ v ++ Bool.pick(String, create, " (a new repository)", "")
    case P.Rebuild{h, _, _}:
      "rebuild  nix-darwin " ++ h
    case P.ServePort{p, t, _}:
      "serve    :" ++ U32.show(p) ++ " -> " ++ t
    case P.Change{w, now, want}:
      "change   " ++ w ++ ": " ++ now ++ " -> " ++ want
    case P.Blocked{w, why}:
      "blocked  " ++ w ++ ": " ++ why

def show_all(ss: List<&2, P.Step>) -> String:
  match ss:
    case []:
      ""
    case s <> rest:
      show(s) ++ "\n" ++ show_all(rest)
