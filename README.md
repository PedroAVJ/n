# V

Data structures for your Bend algorithms: a play on Niklaus Wirth's *Algorithms + Data Structures =
Programs*. V as in Victor, after Victor Taelin, who created Bend, and the pronunciation of Bend.
Single characters for things are my brand.

Describe a system once, as types, and derive everything else from it.
A broken invariant is a compile error, never a runtime surprise.

V is a library, not a language: the language is [Bend 2](https://bend-lang.com). Base comes first,
then packages from the Bend hub, and only then V's own data structures.

## Data structures

Each is a folder with its type, its operations, and, where it has them, its laws and their proofs.
A type only one other type uses sits inside that type's folder.

```
general/                 useful anywhere
├─ rose/                 a keyed value and any number of children
└─ compound/             rose trees plus edges between any two keys; lifting edges to what shows
   └─ edge/
domain/
└─ architecture/         a software system in its environment
   ├─ category/          what a container or outside system is, and what it provides
   ├─ relationship/      stored on its source: what it does with its destination, and how
   ├─ system/
   │  ├─ container/      its technology (vendors, frameworks, libraries, languages), checked against the repository
   │  │  └─ component/
   │  ├─ deployment/     the address, the data stores that must survive, and the machines
   │  │  ├─ host/        an owned device, a provider's cloud, or someone else's
   │  │  ├─ nix_darwin/  a Mac: its flake, services, Tailscale serves, listeners and launch agents
   │  │  │  ├─ service/
   │  │  │  ├─ setting/  macOS settings and the firewall (mac.nix)
   │  │  │  └─ brew/     Homebrew
   │  │  └─ azure/       declared resources, checked against the subscription
   │  ├─ release/        the packages and the repository it publishes
   │  ├─ plan/           what a deploy would do
   │  └─ effs/           running programs; reading and writing files
   ├─ environment/
   │  ├─ party/
   │  ├─ external/
   │  ├─ constraint/
   │  ├─ inventory/      the devices the owner has, and its cloud
   │  └─ agreement/      the organization's people, identities, grants and budgets
   └─ view/              C4's views, drawn with D2
```

`v.bend` imports all of it.

## Effects

Files go through [bend-kit-files](https://hub.bend-lang.com/n/bend-kit-files) and Base's File API.
Running a program (git, gh, bend, d2) is V's one effect of its own:
`domain/architecture/system/effs/program_run.c` and its twin `program_run.js`, one per Bend lane
(`bend file.bend` runs the JS lane; `bend file.bend -o bin` builds the C lane). It runs a program
with a list of arguments, never through a shell.

It is temporary. [bend-kit-process](https://hub.bend-lang.com/n/bend-kit-process) does the same,
but its only version, 0.1.0.0, runs on Bend 2.0.27 alone, while bend-kit-files needs 2.0.28 or later:

| Bend   | bend-kit-process              | bend-kit-files     |
|--------|-------------------------------|--------------------|
| 2.0.27 | works                         | does not build     |
| 2.0.28 | builds, fails when it runs    | works              |
| 2.0.29 | does not build                | works              |

When a bend-kit-process release runs on current Bend, V uses it and deletes `effs/`.

## A system

A repository describes its system as a value of `Architecture`, states its laws in `LAWS.bend`,
proves them in `PROOF.bend`, and has a `system.bend` whose `main` runs it. `system.bend` imports the
proofs, so it compiles only while the laws hold: checking is compiling, and nothing runs otherwise.

```sh
bend system.bend dryrun     # what a deploy would change
bend system.bend deploy     # change it
bend system.bend diagram    # draw the views into diagrams/
bend system.bend import     # print each nix-darwin Mac's current settings as Bend
bend system.bend --check-only
```

This repository is one: `architecture.bend` is V's own architecture. A plan covers the release (the
packages; each Claude Code plugin, built fresh and compared with the tag `v<version>` in its own GitHub
repository, which is also the marketplace it installs from; the repository), each container's technology against the repository, each deployment node
(a nix-darwin Mac: its settings, Homebrew, services, serves, listeners and launch agents; an Azure
subscription: its resources and who may access them), and what the deploy would break compared with
the last deploy (recorded in `.git/v-deployed`). It stops first on a file that is not Bend, dead code,
a package changed without a new version, uncommitted changes, a visibility GitHub disagrees with, or
any runtime check that fails.

Bend's JavaScript lane (`bend file.bend`) overflows on deep recursion (see Bend's WONTFIX), so V reads
only the heads of files where that is all it needs, compares files with `cmp`, and splits long outputs
without deep recursion.

## N

`n/` is N, a type checker for prompts, released as the Claude Code plugin `n` (GitHub
`PedroAVJ/n-plugin`), not yet as a Bend hub package. Before the agent reads a prompt, Jev screens each phrase, and
Claude runs N's type error and lint check on what Jev flags: each finding gets its one reading or its
candidate readings, in N's vocabulary (`n/type.bend`). A prompt with nothing to settle passes silently,
and so does any failure.

```sh
bend n/n.bend dryrun < hook-input.json   # what the hook would send, without sending it
bend n/n.bend plugin out                 # build the plugin into out/
```

## License

MIT.
