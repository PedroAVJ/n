import Base

# An Azure resource the system declares: its name, type and resource group.
type Resource is Data:
  Resource{name: String, kind: String, group: String}

# An Azure subscription and its Azure DevOps project, and the resources declared in it.
type Azure is Data:
  Azure{organization: String, project: String, resources: List<&2, Resource>}

# What Azure grants the signed-in user on a scope (a resource group): ARM action patterns, and those
# excluded from them. Patterns use '*' for any characters.
type Permission is Data:
  Permission{scope: String, actions: List<&2, String>, not_actions: List<&2, String>}

# Someone signed in to Azure: the profile (azure for ARM, devops for Azure DevOps) and their identity.
type Identity is Data:
  Identity{profile: String, name: String}

# What Azure says, read-only: who is signed in, the resources and resource groups, the signed-in user's
# permissions on each group, and the reads that failed.
type Observed is Data:
  Observed{identities: List<&2, Identity>, resources: List<&2, Resource>, groups: List<&2, String>, permissions: List<&2, Permission>, unread: List<&2, String>}
