import Base
import ../style/type.bend as S

# A page's elements, each with only what it may have. A control cannot exist without a label: a button
# has its text, a text area its label, so an unlabeled control does not compile. Live regions announce
# what changes in them to screen readers.
type Datum is Data:
  Datum{name: String, value: String}

type Html is Data:
  Text{text: String}
  Main{style: S.Style, children: List<&2, Html>}
  Div{style: S.Style, children: List<&2, Html>}
  Heading{style: S.Style, text: String}
  Paragraph{style: S.Style, children: List<&2, Html>}
  Span{style: S.Style, children: List<&2, Html>}
  Region{id: String, style: S.Style, children: List<&2, Html>}
  Button{id: String, label: String, data: List<&2, Datum>, style: S.Style}
  TextArea{id: String, label: String, placeholder: String, style: S.Style}

type Document is Data:
  Document{title: String, body: List<&2, Html>, script: String}
