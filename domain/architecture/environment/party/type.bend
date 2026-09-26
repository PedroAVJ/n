import Base
import ../../relationship/type.bend as Rel

type OrgKind is Data:
  Business{}
  Nonprofit{}
  Community{}

# Someone who owns or uses a system: a person, an organization, or a team inside one (named by `of`).
type Party is Data:
  Human{key: String, name: String, description: String, uses: List<&2, Rel.Relationship>}
  Organization{key: String, name: String, description: String, kind: OrgKind, uses: List<&2, Rel.Relationship>}
  Team{key: String, name: String, description: String, of: String, uses: List<&2, Rel.Relationship>}
