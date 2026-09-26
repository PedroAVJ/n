import Base
import ../arc/arc.bend as A
import ../lib/deploy.bend as D

# V's architecture, written with Arc. V is two things on the machine of whoever uses it: the v
# command and the V library it is built on. It deploys by publishing its packages to the Bend hub;
# its source lives on GitHub.

# ---- where it runs: whoever uses V, on their own computer ----
def nodes() -> List<&2, A.Node>:
  [A.Node{"machine", "Their machine", A.UserDevice{}, A.Other{}}]

def org() -> A.Org:
  A.Org{"Pedro", A.Vendor{"Apple", "iCloud"}, []}

# ---- what it is ----
def near() -> List<&2, A.Container>:
  [ A.Container{"v", "v", A.Cli{}, A.Ours{}, "machine", A.Local{}, [], "", [], [], [], ["Bend 2", "C"]},
    A.Container{"library", "V library", A.Lib{}, A.Ours{}, "machine", A.Local{}, [], "", [], [], [], ["Bend 2"]} ]

def parts() -> List<&2, A.Part>:
  [ A.Part{"cli", "v command (check, import, dryrun, plan, deploy, diagram)", A.Bend{}, "v", "machine"},
    A.Part{"proc", "Run-a-program effect", A.C{}, "v", "machine"},
    A.Part{"arc", "Arc (near-architecture)", A.Bend{}, "library", "machine"},
    A.Part{"lib", "Deploy and Mac library", A.Bend{}, "library", "machine"} ]

def links() -> List<&2, A.Link>:
  [ A.Link{"cli", "lib", "imports", False{}},
    A.Link{"lib", "arc", "", False{}},
    A.Link{"cli", "proc", "runs programs", False{}} ]


def system() -> A.System:
  A.System{org(), nodes(), near(), parts(), links()}

# ---- how it deploys: it pushes its repository to GitHub and publishes its packages to the Bend hub ----
def targets() -> List<&2, D.Target>:
  [D.GitHub{"PedroAVJ/n", True{}}, D.BendHub{}]

def packages() -> List<&2, D.Package>:
  [ D.Package{"near-architecture", "0.9.1.0", "../arc/arc.bend", ["arc"]},
    D.Package{"near-v-framework", "0.2.0.0", "../v.bend", ["cli", "lib", "proc"]} ]

# ---- what this system is, who owns it, and who uses it ----
def name() -> String:
  "V"

def image() -> A.Imagery:
  A.Plain{}

# Images for machines, programs and parts that have one of their own.
def pictures() -> List<&2, A.Picture>:
  []

def owner() -> A.Party:
  A.Human{"Pedro", A.Photo{"https://avatars.githubusercontent.com/PedroAVJ?s=256"}}

def kind() -> A.SystemKind:
  A.Product{}

# Who uses it: each "uses" edge names a party and the channel it comes through ("" when direct).
def uses() -> List<&2, A.Use>:
  [A.Use{A.Organization{"Builders", A.Emoji{"🧑🏻‍💻"}, A.Community{}}, "the Bend hub"}]
