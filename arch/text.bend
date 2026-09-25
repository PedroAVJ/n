import Base
import ../lib/text.bend as T
import ./canvas.bend as N

# This architecture as Markdown, in topological order.
def main() -> IO(Unit):
  IO.print(T.markdown(N.system()))
