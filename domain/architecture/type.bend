import Base
import ./system/type.bend as S
import ./environment/type.bend as En

# An architecture: a software system in its environment.
type Architecture is Data:
  Architecture{system: S.System, environment: En.Environment}

# What each key in an architecture is, for drawing it.
type Level is Data:
  PersonLevel{}
  SystemLevel{}
  ContainerLevel{}
  ComponentLevel{}
  ExternalLevel{}

type Element is Data:
  Element{name: String, description: String, technology: String, level: Level}
