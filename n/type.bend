import Base

# N, by Pedro Antonio Villanueva Juarez · https://github.com/PedroAVJ/n
#
# N: a static type checker for `.n` source. A `.n` file is source code in any code (English,
# Spanish, a diagram); N elaborates it into Bend terms, typed against V's modules, and reports
# type errors. Where a span has more than one reading, that is a type error the author resolves
# by choosing the reading they meant; where context settles it, N may fix it itself.
# U is N's feelings stage: it runs after N and owns only the rules about feelings.

# ---- source ----
# A span of a `.n` file, by character offsets: [start, end).
type Span is Data:
  Span{start: Nat, end: Nat}

# One reading of a span: the Bend term it elaborates to, as text.
type Reading is Data:
  Reading{span: Span, term: String}

# ---- stages ----
# Each question has exactly one owner: N checks the language, then U checks feelings.
type Stage is Data:
  N{}
  U{}

# ---- type errors ----
# Ambiguous: the span has several readings and nothing settles which one is meant.
# Inconsistent: two readings cannot both hold.
# Unconfirmed: the author has not confirmed that the reading is what they meant.
type Diagnostic is Data:
  Ambiguous{stage: Stage, span: Span, readings: List<&2, Reading>}
  Inconsistent{stage: Stage, a: Reading, b: Reading, why: String}
  Unconfirmed{stage: Stage, reading: Reading}
