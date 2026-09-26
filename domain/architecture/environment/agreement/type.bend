import Base

# One of the organization's people, by their identity in its directory.
type Person is Data:
  Person{key: String, identity: String}

# What a person may do in a scope (an Azure resource group): action patterns; none means no access.
type Grant is Data:
  Grant{person: String, scope: String, actions: List<&2, String>}

type Budget is Data:
  Budget{person: String, what: String, amount: Nat, unit: String}

# The agreement between the organization and its people: its directory domain, who they are, and
# what each is granted and budgeted.
type Agreement is Data:
  Agreement{domain: String, people: List<&2, Person>, grants: List<&2, Grant>, budgets: List<&2, Budget>}
