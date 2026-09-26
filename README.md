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
   ├─ relationship/      stored on its source: what it does with its destination, and how
   ├─ system/            containers and components, where they run, and what the system publishes
   │  ├─ container/
   │  │  └─ component/
   │  ├─ deployment/
   │  ├─ release/
   │  └─ plan/
   ├─ environment/       who uses it, the systems around it, and its constraints
   │  ├─ party/
   │  ├─ external/
   │  └─ constraint/
   └─ view/              C4's views (context, containers, components, deployment, dynamic), drawn with D2
```

`v.bend` imports all of it. Effects run through
[bend-kit-process](https://hub.bend-lang.com/n/bend-kit-process) and
[bend-kit-files](https://hub.bend-lang.com/n/bend-kit-files); V has no foreign code of its own.

## A system

A repository describes its system as a value of `Architecture`, states its laws in `LAWS.bend`,
proves them in `PROOF.bend`, and has a `system.bend` whose `main` runs it. `system.bend` imports the
proofs, so it compiles only while the laws hold: checking is compiling, and nothing runs otherwise.

```sh
bend system.bend dryrun     # what a deploy would change
bend system.bend deploy     # change it
bend system.bend diagram    # draw the views into diagrams/
bend system.bend --check-only
```

This repository is one: `architecture.bend` is V's own architecture. A deploy publishes the package
and pushes the repository, and stops first if a file is not Bend, a file no entry reaches (dead
code), a package changed without a new version, uncommitted changes, or GitHub's visibility
differing from the declared one.

## License

MIT.
