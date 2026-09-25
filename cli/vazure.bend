import Base
import ../lib/effs/io.bend as X
import ../lib/vstr.bend as S
import ./project.bend as P
import bend-net-json@0.3.0.0/json.bend as Json

# Only ARM/DevOps read commands with narrow JMESPath projections appear here.
# Disable Azure CLI command logs: even metadata must not create files outside the project.
def parsed(m: Maybe<&2, Json.Val>, label: String) -> IO(Json.Val):
  match m:
    case None{}: IO.die(Json.Val, 1, "snapshot: " ++ label ++ " returned invalid JSON")
    case Some{value}: IO.pure(Json.Val, value)

def result_json(result: Result<&1, &1, U32 & String, String>, label: String) -> IO(Json.Val):
  match result:
    case Fail{_}: IO.die(Json.Val, 1, "snapshot: " ++ label ++ " read failed")
    case Done{raw}: parsed(Json.parse(raw), label)

def read_json(label: String, command: String) -> IO(Json.Val):
  do IO<Json.Val>:
    result : Result<&1, &1, U32 & String, String> <- X.Proc.run("AZURE_LOGGING_ENABLE_LOG_FILE=false " ++ command ++ " 2>/dev/null")
    result_json(result, label)

def json_or_null(m: Maybe<&2, Json.Val>) -> Json.Val:
  match m:
    case None{}: Json.Null{}
    case Some{v}: v

def at(v: Json.Val, k: String) -> Json.Val:
  json_or_null(Json.get(v, k))

def string(v: Json.Val) -> String:
  match v:
    case Json.Str{s}: s
    case Json.Num{s}: s
    case _: ""

def array(v: Json.Val) -> List<&2, Json.Val>:
  match v:
    case Json.Arr{xs}: xs
    case _: []

def lit(s: String) -> String:
  "\"" ++ S.esc(s) ++ "\""

def quoted(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: lit(x) <> quoted(rest)

def strings(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: string(x) <> strings(rest)

def str_list(v: Json.Val) -> String:
  "[" ++ String.join(quoted(strings(array(v))), ", ") ++ "]"

def resource(+v: Json.Val) -> String:
  "A.Resource{" ++ lit(string(at(v, "name"))) ++ ", " ++ lit(string(at(v, "type"))) ++ ", " ++ lit(string(at(v, "resourceGroup"))) ++ ", " ++ lit(string(at(v, "location"))) ++ "}"

def project(v: Json.Val) -> String:
  "A.Project{" ++ lit(string(at(v, "name"))) ++ "}"

def repository(v: Json.Val) -> String:
  "A.Repository{" ++ lit(string(at(v, "name"))) ++ "}"

def pipeline(+v: Json.Val) -> String:
  "A.Pipeline{" ++ lit(string(at(v, "name"))) ++ ", " ++ lit(string(at(v, "repository"))) ++ ", " ++ lit(string(at(v, "yaml"))) ++ "}"

def connection(+v: Json.Val) -> String:
  "A.ServiceConnection{" ++ lit(string(at(v, "name"))) ++ ", " ++ lit(string(at(v, "type"))) ++ ", " ++ lit(string(at(v, "scheme"))) ++ "}"

def resource_items(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: resource(x) <> resource_items(rest)

def group_names(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: string(at(x, "name")) <> group_names(rest)

def project_items(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: project(x) <> project_items(rest)

def repository_items(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: repository(x) <> repository_items(rest)

def pipeline_items(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: pipeline(x) <> pipeline_items(rest)

def connection_items(xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: connection(x) <> connection_items(rest)

def permission(scope: String, +v: Json.Val) -> String:
  "A.Permission{" ++ lit(scope) ++ ", " ++ str_list(at(v, "actions")) ++ ", " ++ str_list(at(v, "notActions")) ++ "}"

def permission_items(+scope: String, xs: List<&2, Json.Val>) -> List<&2, String>:
  match xs:
    case []: []
    case x <> rest: permission(scope, x) <> permission_items(scope, rest)

type Rows is Data:
  Rows{items: List<&2, String>, count: Nat}

def row_items(r: Rows) -> List<&2, String>:
  match r:
    case Rows{items, _}: items

def row_count(r: Rows) -> Nat:
  match r:
    case Rows{_, count}: count

def add_rows(a: Rows, b: Rows) -> Rows:
  match a b:
    case Rows{as, ac} Rows{bs, bc}:
      Rows{List.append(&2, String, as, bs), Nat.add(ac, bc)}

# Identifiers come from Azure or a project's target fact. Reject shell metacharacters.
def safe_chars(cs: List<&2, Char>) -> Bool:
  match cs:
    case []: True{}
    case +c <> rest:
      (Char.is_lower(c) || Char.is_upper(c) || Char.is_digit(c) ||
       Char.is_eq(c, '-') || Char.is_eq(c, '_') || Char.is_eq(c, '.') ||
       Char.is_eq(c, ':') || Char.is_eq(c, '/')) && safe_chars(rest)

def safe(+s: String) -> Bool:
  Bool.not(String.is_empty(s)) && safe_chars(String.to_list(s))

def require_safe_bool(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit, Unit{})
    case False{}: IO.die(Unit, 1, "snapshot: unsafe or empty " ++ label)

def require_safe(label: String, s: String) -> IO(Unit):
  require_safe_bool(safe(s), label)

def permissions(+subscription: String, groups: List<&2, Json.Val>) -> IO(Rows):
  match groups:
    case []: IO.pure(Rows, Rows{[], 0n})
    case group <> rest:
      do IO<Rows>:
        +name : String = string(at(group, "name"))
        require_safe("resource group", name)
        +url : String = "https://management.azure.com/subscriptions/" ++ subscription ++ "/resourceGroups/" ++ name ++ "/providers/Microsoft.Authorization/permissions?api-version=2015-07-01"
        +data : Json.Val <- read_json("ARM permissions", "az rest --method get --url '" ++ url ++ "' --query 'value[].{actions:actions,notActions:notActions}' -o json")
        more : Rows <- permissions(subscription, rest)
        return add_rows(Rows{permission_items(name, array(data)), List.length(&2, Json.Val, array(data))}, more)

def pipeline_details(+org: String, +project_name: String, xs: List<&2, Json.Val>) -> IO(Rows):
  match xs:
    case []: IO.pure(Rows, Rows{[], 0n})
    case x <> rest:
      do IO<Rows>:
        +id : String = string(at(x, "id"))
        require_safe("pipeline id", id)
        detail : Json.Val <- read_json("DevOps pipeline", "az-devops pipelines show --organization '" ++ org ++ "' --project '" ++ project_name ++ "' --id " ++ id ++ " --query '{name:name,repository:repository.name || configuration.repository.name,yaml:process.yamlFilename || configuration.path}' -o json")
        more : Rows <- pipeline_details(org, project_name, rest)
        return add_rows(Rows{[pipeline(detail)], 1n}, more)

def facts_text(+vlib: String, +org: String, +project_name: String, +resources: List<&2, String>, +groups: List<&2, String>, +permissions: List<&2, String>, +projects: List<&2, String>, +repos: List<&2, String>, +pipelines: List<&2, String>, +connections: List<&2, String>, +arm_identity: String, +devops_identity: String) -> String:
  "import Base\nimport " ++ vlib ++ "/azure.bend as A\n\n# Read-only Azure and Azure DevOps facts. Generated by v snapshot; do not edit.\n" ++
  "def organization() -> String:\n  " ++ lit(org) ++ "\n\ndef devops_project() -> String:\n  " ++ lit(project_name) ++ "\n\n" ++
  "def resources() -> List<&2, A.Resource>:\n  [" ++ String.join(resources, ", ") ++ "]\n\n" ++
  "def resource_groups() -> List<&2, String>:\n  [" ++ String.join(groups, ", ") ++ "]\n\n" ++
  "def permissions() -> List<&2, A.Permission>:\n  [" ++ String.join(permissions, ", ") ++ "]\n\n" ++
  "def projects() -> List<&2, A.Project>:\n  [" ++ String.join(projects, ", ") ++ "]\n\n" ++
  "def repositories() -> List<&2, A.Repository>:\n  [" ++ String.join(repos, ", ") ++ "]\n\n" ++
  "def pipelines() -> List<&2, A.Pipeline>:\n  [" ++ String.join(pipelines, ", ") ++ "]\n\n" ++
  "def service_connections() -> List<&2, A.ServiceConnection>:\n  [" ++ String.join(connections, ", ") ++ "]\n\n" ++
  "def identities() -> List<&2, A.Identity>:\n  [A.Identity{\"azure\", " ++ lit(arm_identity) ++ "}, A.Identity{\"devops\", " ++ lit(devops_identity) ++ "}]\n"

def snapshot(+f: P.Facts) -> IO(Unit):
  do IO<Unit>:
    +org : String = P.azure_organization(f)
    +project_name : String = P.azure_project(f)
    require_safe("DevOps organization", org)
    require_safe("DevOps project", project_name)
    +account : Json.Val <- read_json("Azure account", "az account show --query '{name:user.name,id:id}' -o json")
    +subscription : String = string(at(account, "id"))
    require_safe("subscription", subscription)
    +resources : Json.Val <- read_json("ARM resources", "az resource list --query '[].{name:name,type:type,resourceGroup:resourceGroup,location:location}' -o json")
    +groups : Json.Val <- read_json("ARM resource groups", "az group list --query '[].{name:name}' -o json")
    +grants : Rows <- permissions(subscription, array(groups))
    +projects : Json.Val <- read_json("DevOps projects", "az-devops devops project list --organization '" ++ org ++ "' --query 'value[].{name:name}' -o json")
    +repos : Json.Val <- read_json("DevOps repositories", "az-devops repos list --organization '" ++ org ++ "' --project '" ++ project_name ++ "' --query '[].{name:name}' -o json")
    pipeline_list : Json.Val <- read_json("DevOps pipelines", "az-devops pipelines list --organization '" ++ org ++ "' --project '" ++ project_name ++ "' --query '[].{id:id,name:name}' -o json")
    +pipeline_rows : Rows <- pipeline_details(org, project_name, array(pipeline_list))
    +connections : Json.Val <- read_json("DevOps service connections", "az-devops devops service-endpoint list --organization '" ++ org ++ "' --project '" ++ project_name ++ "' --query '[].{name:name,type:type,scheme:authorization.scheme}' -o json")
    profile : Json.Val <- read_json("DevOps profile", "cat ~/.config/azure-plugin/profiles.json")
    +devops_identity : String = string(at(at(profile, "devops"), "username"))
    X.write_file("azure.bend", facts_text(P.vlib_of(f), org, project_name, resource_items(array(resources)), quoted(group_names(array(groups))), row_items(grants), project_items(array(projects)), repository_items(array(repos)), row_items(pipeline_rows), connection_items(array(connections)), string(at(account, "name")), devops_identity))
    IO.print("snapshot: " ++ Nat.show(List.length(&2, Json.Val, array(resources))) ++ " Azure resources, " ++ Nat.show(row_count(grants)) ++ " permission entries, " ++ Nat.show(List.length(&2, Json.Val, array(groups))) ++ " resource groups; " ++ Nat.show(List.length(&2, Json.Val, array(projects))) ++ " DevOps projects, " ++ Nat.show(List.length(&2, Json.Val, array(repos))) ++ " repos, " ++ Nat.show(row_count(pipeline_rows)) ++ " pipelines, " ++ Nat.show(List.length(&2, Json.Val, array(connections))) ++ " service connections")
