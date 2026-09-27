import Base

# Markup: elements with attributes and children, and text. HTML, SVG and XML are all markup; a typed
# language (like domain/app/html) lowers into it to be printed.
type Attribute is Data:
  Attribute{name: String, value: String}

type Node is Data:
  Element{tag: String, attributes: List<&2, Attribute>, children: List<&2, Node>}
  Void{tag: String, attributes: List<&2, Attribute>}
  Text{text: String}
  Raw{text: String}
