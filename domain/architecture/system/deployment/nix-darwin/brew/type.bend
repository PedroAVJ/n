import Base

# One Homebrew entry. Mas: a Mac App Store app by name and id. Other: a raw Brewfile line (uv, npm).
type Brew is Data:
  Tap{name: String}
  Formula{name: String}
  Cask{name: String}
  Mas{name: String, id: String}
  Other{line: String}
