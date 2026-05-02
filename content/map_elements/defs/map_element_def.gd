extends Resource
class_name MapElementDef

const LOGIC_TYPE_STATIC_DECORATION := 1
const LOGIC_TYPE_ANIMATED_DECORATION := 2
const LOGIC_TYPE_BREAKABLE := 3
const LOGIC_TYPE_INTERACTIVE := 4
const LOGIC_TYPE_BREAKABLE_INTERACTIVE := 5

@export var element_id: int = 0
@export var display_name: String = ""
@export var theme_id: int = 0
@export var theme_name: String = ""
@export var elem_number: int = 0
@export var logic_type: int = 0
@export var interact_type: int = 0
@export var source_dir: String = ""
@export var stand_file: String = ""
@export var die_file: String = ""
@export var trigger_file: String = ""
@export var content_hash: String = ""
