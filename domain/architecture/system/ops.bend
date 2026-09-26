import Base
import ./type.bend as S
import ./release/type.bend as Rl
import ./release/ops.bend as RlO
import ../ops.bend as O

def release(s: S.System) -> Rl.Release:
  match s:
    case S.System{_, _, _, _, _, r}:
      r

# Everything the system is made of ships in a declared package or plugin: what is not published cannot
# be used.
def components_published(+s: S.System) -> Bool:
  match s:
    case S.System{_, _, _, cs, _, +r}:
      O.all_listed(O.all_component_keys(cs), List.append(&2, String, RlO.shipped_components(RlO.packages(r)), RlO.plugin_components(RlO.plugins(r))))
