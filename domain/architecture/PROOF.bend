import Base
import ../../general/rose/ops.bend as RO
import ./type.bend as A
import ./ops.bend as O
import ./system/type.bend as S
import ./environment/type.bend as En
import ./LAWS.bend as Laws

def Laws.first_key_is_system(a):
  match a:
    case A.Architecture{s, env}:
      match s env:
        case S.System{k, n, d, cs, ns, r} En.Environment{ps, xs, ks, inv, ag}:
          {==}
