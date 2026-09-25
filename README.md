# N

A static type checker for `.n` source, in [Bend 2](https://bend-lang.com).

A `.n` file is source code in any code: English, Spanish, a diagram. N elaborates it into Bend
terms, typed against V, the framework in this repository, and reports type errors. A span with
more than one reading is a type error: the author picks the reading they meant, or N fixes it when
context settles it. U, N's feelings stage, runs after N and owns only the rules about feelings.

Near is the editor where `.n` files are written and their errors shown.

`n.bend` holds N's vocabulary: spans, readings, stages and diagnostics. The checker is not written yet.

## V

Data structures for your Bend algorithms: a play on Niklaus Wirth's *Algorithms + Data Structures =
Programs*. V as in Victor, after Victor Taelin, who created Bend, and the pronunciation of Bend.
Single characters for things are my brand.

Describe a system once, as types, and derive everything else from it.
A broken invariant is a compile error, never a runtime surprise.

V is a framework, not a language: the language is [Bend 2](https://bend-lang.com).
It builds on packages from the Bend hub, and nothing in it is specific to one project.

### Arc

`arc/arc.bend` is the architecture layer, published on its own. A system is two
hierarchies over the same containers:

- **Where it runs:** node → container → part. Nodes have a role (`UserDevice`,
  `Server`, `Overlay` or `Outside`), and servers and user devices name an owned
  physical device or the organization's vendor cloud.
- **What it is:** system → container → part. A container is one of a closed list of
  kinds (`Client`, `Network`, `DataApi`, `AgentsApi`, `ModelApi`, `Worker`), `Ours` or
  `Theirs`, with an exposure (`Local`, `Lan`, `Tailnet`, `Device`, `Public`) and the
  capabilities it provides.

Keys work like foreign keys, and a project writes its laws with Arc's predicates:
well-formedness, private servers, devices reaching servers only through the private
network, each capability provided exactly once, and a D2 diagram.

### The rest of V

- `lib/deploy.bend`: services, routes and launchd jobs for an Arc system; what a change
  breaks; minimality against the machine (launch agents, listeners); the deploy plan and
  the nix-darwin flake.
- `lib/mac_types.bend`: a Mac's nix-darwin-labeled settings, declared and observed, and
  the typed firewall.
- `cli/`: the `v` command. The only foreign code is one C effect (`lib/effs/proc_run.c`)
  that runs another program.

Packages: `bend-net-json@0.3.0.0` (Tailscale's serve status), `bend-net-url@0.4.0.0` (URL decoding).

### Targets

A project declares where it deploys, and `v system deploy` runs only those targets:

- `NixDarwin{host}`: configure a Mac with nix-darwin (`v system import` and `v system dryrun` read and
  diff it). Needs Nix and Homebrew.
- `TailscaleServe{}`: serve the plan's ports on the private network. Needs Tailscale.
- `GitHub{repo, public}`: push the project's repository to its main branch. Fails on uncommitted
  changes, an origin other than `repo`, or a visibility other than the declared one.
- `BendHub{}`: publish the project's packages. A package already published with the same
  files is left alone; changed files without a new version fail the deploy.

### This repository's architecture

`arch/` is this repository as a V project: N, the `v` command, the tools it drives, GitHub and the
Bend hub. Its targets are `GitHub` and `BendHub`, so `cd arch && v system deploy` proves the laws,
pushes the repository and publishes its packages.

### A project

`v` runs in a project's folder. The project describes itself with Arc and V's library and
provides small programs `v` compiles and runs: `facts.bend` (where V's library is, its
targets, services and packages) and its laws (`LAWS.bend` / `PROOF.bend`), plus, for the
targets that use them, `plan.bend`, `current.bend`, `flake.bend`, `mac.gen.bend`,
`mac.dryrun.bend` and `diagram.bend`.

```sh
bend cli/main.bend -o bin/v     # build v
v system check      # snapshot the machine, then prove the project's laws
v system import     # read the Mac into mac.now.bend (mac.bend keeps its declarations)
v system dryrun     # what applying mac.bend would change, without changing anything
v system plan       # the deploy steps
v system deploy     # prove, then run the project's targets
v system diagram out.png
```

## License

MIT.
