import Base

# How an element looks: typed declarations, and the conditions some of them apply under. A style becomes
# one generated class, so there are no selectors to write and no cascade to fight.
type Length is Data:
  Px{n: Nat}
  Percent{n: Nat}

type Color is Data:
  Rgb{r: Nat, g: Nat, b: Nat}
  Transparent{}

type Font is Data:
  Sans{}
  Mono{}

type Direction is Data:
  Row{}
  Column{}

type Decl is Data:
  Padding{length: Length}
  Margin{length: Length}
  Gap{length: Length}
  Background{color: Color}
  Foreground{color: Color}
  Border{width: Length, color: Color}
  Radius{length: Length}
  FontSize{length: Length}
  Family{font: Font}
  Weight{n: Nat}
  Width{length: Length}
  MaxWidth{length: Length}
  MinHeight{length: Length}
  Flex{direction: Direction}
  Centered{}
  Pointer{}
  Underline{color: Color}

# Hover and Focus are the element's own states; Dark is the system's dark mode; Below is a screen narrower
# than the length.
type Condition is Data:
  Hover{}
  Focus{}
  Dark{}
  Below{width: Length}

type Rule is Data:
  When{condition: Condition, decls: List<&2, Decl>}

type Style is Data:
  Style{decls: List<&2, Decl>, rules: List<&2, Rule>}
