extends Control
# DialogueBox, attached to Root node
# Gets input from DialogueBox UI (via UpdateController)
# Sends input to InkPlayer
# Tells DialogueEngine to make new prefabs based on InkPlayer's output
# Adds newly produced prefabs to DialogueBox UI

# Entry Prefab Types
export var _entry_prefab_normal = preload("res://assets/ui/prefabs/dialoguebox_entrynormal.tscn")
export var _entry_prefab_dialogue = preload("res://assets/ui/prefabs/dialoguebox_entrydialogue.tscn")
export var _entry_prefab_choices = preload("res://assets/ui/prefabs/dialoguebox_entrychoices.tscn")
export var _choice_prefab = preload("res://assets/ui/prefabs/dialoguebox_entrychoices_choice.tscn")

# Choice Entry Vars
var _current_choice_strings
var is_displaying_choices
var _current_choice_index = 0
var _current_choice_entry
var _current_choice_entry_choices

# Story state save file location 
var _save_file_path = "res://saves"
var _ink_story

onready var background_panel_node = $Panel
onready var _scroll_node = $Panel/MarginContainer/ScrollContainer
onready var _vertical_layout_node = $Panel/MarginContainer/ScrollContainer/VBoxContainer
onready var _ink_player = $InkPlayer


func _ready():
	_ink_story = _ink_player.story
	
	#Hide dialoguebox and delete placeholders
	Globals.delete_children(_vertical_layout_node)
	background_panel_node.set_visible(false)


# Opening the player as-is
# tell _ink_player to open knot with name that matches pathstring
func open_at_knot(pathstring):
	_ink_player.SetVariable("currentPartyChar", Globals.PartyObject.get_leader_inkname())
	_ink_player.SetVariable("currentWorld", Globals.get_world_inkname())
	
	_ink_player.ChoosePathString(pathstring)
	proceed()


# change which choice is currently highlighted
# changevalue: 1 if we're going down, -1 if we're going up
func toggle_choice_selections(changeValue):
	_current_choice_entry_choices[_current_choice_index].set_highlighted(false)
	#move to new choice
	_current_choice_index = wrapi(_current_choice_index + changeValue, 0, _current_choice_strings.size())
	_current_choice_entry_choices[_current_choice_index].set_highlighted(true)
	
	Globals.SoundManager.play_sound(Globals.SoundManager.choice_select_sound)


# select the currently highlighted choice
func select_current_choice():
	_ink_player.ChooseChoiceIndex(_current_choice_index)
	_current_choice_entry.queue_free() #remove the choicebox
	is_displaying_choices = false
	proceed()


# proceeding to the next string that ink should return
func proceed():
	if !_ink_player.get_CanContinue() && !_ink_player.get_HasChoices():
		clear_and_reset_ui()
		
	elif !_ink_player.get_HasChoices(): #create normal text entry
		_ink_player.Continue()
		print_state()
		
		var currentLine = _ink_player.get_CurrentText()
		
		if currentLine.substr(0, 1) == "&":
			RoomEngine.PlaneManager.shift_planes()
			currentLine = currentLine.trim_prefix('&')
			
		check_entry_type(currentLine)
		
	#_scroll_node to bottom when new message appears (make this tween later)
	yield(get_tree(), "idle_frame")
	_scroll_node.set_v_scroll(_scroll_node.get_v_scrollbar().max_value)


# Parses entryText for special characters, determines what type of entry this is
# Entries are normal, dialogue, or choice
# Call corresponding functionality for type of entry
func check_entry_type(entryText):
		if entryText.substr(0, 1) == ":": #this is a name for the choice entry nametag; not an entry to put in
			var chooserName = entryText.substr(1).strip_escapes()
			_ink_player.Continue()
			is_displaying_choices = true
			display_choices(chooserName)
		
		elif ":" in entryText: #if line contains a name, parse name and dialogue after
			var newDialogue = DialogueEngine.create_entry_dialogue(entryText, _entry_prefab_dialogue, _entry_prefab_normal)
			_vertical_layout_node.add_child(newDialogue)
		
		else: #it's a normal text entry
			var newText = DialogueEngine.create_entry(entryText.strip_escapes(), _entry_prefab_normal)
			_vertical_layout_node.add_child(newText)


#initialize the choice-selection of a new choice entry prefab
func display_choices(chooserName):
	_current_choice_strings = _ink_player.get_CurrentChoices()
	
	if _current_choice_strings.size() <= 0: #TO AVOID CRASHING
		return
	
	var newChoiceEntry = DialogueEngine.create_entry_choices(_current_choice_strings, chooserName, _entry_prefab_choices, _choice_prefab)

	_current_choice_index = 0
	_current_choice_entry_choices = newChoiceEntry.get_choices()
	_current_choice_entry_choices[_current_choice_index].set_highlighted(true)
	_vertical_layout_node.add_child(newChoiceEntry)
	_current_choice_entry = newChoiceEntry


# parse json story state from ink player; print the stuff we care about
func print_state():
	var splitstate = _ink_player.GetState().json_escape().split("\\")
	
	var i = 0
	var addVariables = false
	var variables = ""
	
	print("----------\nINK STATE:")
	
	for item in splitstate:
		if "cPath" in item:
			print("cPath: " + splitstate[i + 2] + '"')
		
		elif "variablesState" in item:
			addVariables = true
			
		if addVariables:
			if "}" in item:
				addVariables = false
				print(variables + "}")
				
			else:
				var variableLine = item.trim_prefix('"')
				if "^" in variableLine:
					variables += variableLine.trim_prefix("^")
				else:
					variables += variableLine
					
		i += 1
		
	print("----------")


# Clear and reset the UI panel
func clear_and_reset_ui():
	background_panel_node.set_visible(false)
	Globals.delete_children(_vertical_layout_node)
	Globals.GameMode = Globals.GameModes.WALK