import Base
import ../lib/text.bend as T
import ./canvas.bend as N

# This architecture as Markdown: its graph from the one start, depth first.
def main() -> IO(Unit):
  IO.print(T.markdown(N.system(), {==}))
