class_name AttributeBlock
extends Resource
## The 8 primary attributes (charter §13). Pure data — every derived stat
## is computed in ProgressionCalculator, never here and never ad hoc in UI.

@export_range(1, 200) var strength: int = 5
@export_range(1, 200) var agility: int = 5
@export_range(1, 200) var attack: int = 5
@export_range(1, 200) var defence: int = 5
@export_range(1, 200) var vitality: int = 5
@export_range(1, 200) var stamina: int = 5
## Intelligence/Arcana in the design doc — "arcana" in code.
@export_range(1, 200) var arcana: int = 5
@export_range(1, 200) var charisma: int = 5


func duplicate_block() -> AttributeBlock:
	return duplicate(true) as AttributeBlock
