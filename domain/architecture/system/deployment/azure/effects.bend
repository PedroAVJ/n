import Base
import bend-net-json@0.3.0.0/json.bend as Json
import bend-kit-files@0.1.0.0/files.bend as Fs
import ../../effs/io.bend as X
import ../../plan/type.bend as P
import ./type.bend as Az
import ./ops.bend as AzO
import ../../../environment/agreement/type.bend as G

# Azure, observed read-only: az's read commands with narrow projections, and the Azure DevOps identity
# from the az-devops profile. az runs through env, never a shell, with its command log file disabled so
# even metadata stays out of files.

# ---- JSON ----
def value(m: Maybe<&2, Json.Val>) -> Json.Val:
  match m:
    case None{}:
      Json.Null{}
    case Some{v}:
      v

def at(v: Json.Val, k: String) -> Json.Val:
  value(Json.get(v, k))

def string(v: Json.Val) -> String:
  match v:
    case Json.Str{s}:
      s
    case _:
      ""

def array(v: Json.Val) -> List<&2, Json.Val>:
  match v:
    case Json.Arr{xs}:
      xs
    case _:
      []

def strings(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []:
      []
    case x <> rest:
      string(x) <> strings(rest)

# [what] when its JSON could not be read.
def unread_if(what: String, m: Maybe<&2, Json.Val>) -> List<&2, String>:
  match m:
    case None{}:
      [what]
    case Some{_}:
      []

# ---- reading Azure ----
# az's standard output for these arguments, or "" when it fails.
def az_run(args: List<&2, String>) -> IO(String):
  X.run("env", "AZURE_LOGGING_ENABLE_LOG_FILE=false" <> "az" <> args)

def resource(+v: Json.Val) -> Az.Resource:
  Az.Resource{string(at(v, "name")), string(at(v, "type")), string(at(v, "resourceGroup"))}

def resources(xs: List<&2, Json.Val>) -> List<&2, Az.Resource>:
  match xs:
    case []:
      []
    case x <> rest:
      resource(x) <> resources(rest)

def permission(scope: String, +v: Json.Val) -> Az.Permission:
  Az.Permission{scope, strings(array(at(v, "actions"))), strings(array(at(v, "notActions")))}

def permissions_of(+scope: String, xs: List<&2, Json.Val>) -> List<&2, Az.Permission>:
  match xs:
    case []:
      []
    case x <> rest:
      permission(scope, x) <> permissions_of(scope, rest)

def add(o: Az.Observed, ps: List<&2, Az.Permission>, unread: List<&2, String>) -> Az.Observed:
  match o:
    case Az.Observed{ids, rs, gs, qs, us}:
      Az.Observed{ids, rs, gs, List.append(&2, Az.Permission, qs, ps), List.append(&2, String, us, unread)}

# The signed-in user's effective permissions on each resource group.
def permissions(+subscription: String, gs: List<&2, String>, o: Az.Observed) -> IO(Az.Observed):
  match gs:
    case []:
      IO.pure(Az.Observed, o)
    case +g <> rest:
      do IO<Az.Observed>:
        out : String <- az_run(["rest", "--method", "get", "--url", "https://management.azure.com/subscriptions/" ++ subscription ++ "/resourceGroups/" ++ g ++ "/providers/Microsoft.Authorization/permissions?api-version=2015-07-01", "--query", "value[].{actions:actions,notActions:notActions}", "-o", "json"])
        +m : Maybe<&2, Json.Val> = Json.parse(out)
        permissions(subscription, rest, add(o, permissions_of(g, array(value(m))), unread_if("permissions on " ++ g, m)))

# Who az-devops is signed in as, or "" when it has no profile.
def devops() -> IO(String):
  do IO<String>:
    h : String <- X.home()
    text : String <- X.read(Fs.path.join(h, ".config/azure-plugin/profiles.json"))
    return string(at(at(value(Json.parse(text)), "devops"), "username"))

def identities(user: String, +devops: String) -> List<&2, Az.Identity>:
  Az.Identity{"azure", user} <> Bool.pick(List<&2, Az.Identity>, String.is_empty(devops), [], [Az.Identity{"devops", devops}])

def signed(m: Maybe<&2, Json.Val>) -> IO(Az.Observed):
  match m:
    case None{}:
      IO.pure(Az.Observed, Az.Observed{[], [], [], [], ["the signed-in Azure account"]})
    case Some{+account}:
      do IO<Az.Observed>:
        rs : String <- az_run(["resource", "list", "--query", "[].{name:name,type:type,resourceGroup:resourceGroup}", "-o", "json"])
        gs : String <- az_run(["group", "list", "--query", "[].name", "-o", "json"])
        d : String <- devops()
        +mr : Maybe<&2, Json.Val> = Json.parse(rs)
        +mg : Maybe<&2, Json.Val> = Json.parse(gs)
        +groups : List<&2, String> = strings(array(value(mg)))
        permissions(string(at(account, "id")), groups,
          Az.Observed{identities(string(at(account, "name")), d), resources(array(value(mr))), groups, [],
            List.append(&2, String, unread_if("Azure resources", mr), unread_if("resource groups", mg))})

# Azure as it is: who is signed in, its resources and groups, and the signed-in user's permissions.
def observe() -> IO(Az.Observed):
  do IO<Az.Observed>:
    account : String <- az_run(["account", "show", "--query", "{name:user.name,id:id}", "-o", "json"])
    signed(Json.parse(account))

# The Azure checks against the declared resources and the agreement (see AzO.steps).
def checks(az: Az.Azure, a: G.Agreement) -> IO(List<&2, P.Step>):
  do IO<List<&2, P.Step>>:
    o : Az.Observed <- observe()
    return AzO.steps(az, a, o)
