class_name CharacterNavigator
extends KinematicBody2D
# For controlling individual characters in the party
# includes pathfinding using NavigationAgent2D

export var nav_agent_radius : float = 0.2
export var nav_optimize_path : bool = false
export var nav_avoidance_enabled : bool = true
export var character_speed_multiplier : float = 20.0
export var inkName = "Name"

var nav_agent : NavigationAgent2D
var velocity : Vector2

# final navigation destination position/point
var nav_destination : Vector2
# next navigation destination position/point
var next_nav_position : Vector2
# The normal path to the destination
var character_nav_path : Array = []
var character_real_nav_path : Array = [] # The actual path being calcuated during travel, used in the draw function

const walk_speed : float = 3500.0

var _velocity : Vector2 = Vector2()
var _direction_facing : Vector2 = Vector2()
var _current_idle_sprite : String = "DownIdle"

onready var _animation_player = $AnimationPlayer


# BELOW:
# Author : Shaun Harbison
# MIT License : 2022

func _ready() -> void:
	velocity = Vector2.ZERO 
	nav_agent = $NavigationAgent2D
	
	nav_agent.connect("path_changed", self, "character_path_changed")
	nav_agent.connect("target_reached", self, "character_target_reached_reached")
	nav_agent.connect("navigation_finished", self, "character_navigation_finished")
	nav_agent.connect("velocity_computed", self, "character_velocity_computed")
	
	nav_agent.max_speed = character_speed_multiplier
	nav_agent.radius = nav_agent_radius
	nav_agent.avoidance_enabled = nav_avoidance_enabled
	
	nav_destination = global_position
	next_nav_position = global_position
	
	nav_agent.set_target_location(nav_destination)


func npc_process():
	next_nav_position = nav_agent.get_next_location()
	character_real_nav_path.push_back(next_nav_position) # for draw function
	
	var desired_velocity = global_position.direction_to(next_nav_position) * character_speed_multiplier
	
	# set_velocity will trigger a callback from velocity_computed signal
	nav_agent.set_velocity(desired_velocity)


func set_navigation_position(nav_position_to_set : Vector2) -> void:
	nav_destination = nav_position_to_set
	
	# set the new character target location
	nav_agent.set_target_location(nav_destination)
	
	# calculate a new map path with the server using character nav agent map and new nav destination
	character_nav_path = Navigation2DServer.map_get_path(
			nav_agent.get_navigation_map(),
			global_position, nav_destination,
			nav_optimize_path
			)
			
	character_real_nav_path.clear() # clear the old real nav path, used for draw function


func character_velocity_computed(calculated_velocity : Vector2) -> void:
	velocity = calculated_velocity
	
	# check if nav agent target is reached
	if !nav_agent.is_target_reached():
		velocity = move_and_slide(velocity)
		
	else:
		# if reached target, stand at the closest point in the navigation map
		global_position = Navigation2DServer.map_get_closest_point(nav_agent.get_navigation_map(), global_position)


func character_path_changed() -> void:
	# TODO, implement this function to add behavior for character
	pass


func character_target_reached_reached() -> void:
	# TODO, implement this function to add behavior for character
	# currently using is_target_reached() in character_velocity_computed()
	pass


func character_navigation_finished() -> void:
	# TODO, implement this function to add behavior for character
	pass

# END OF SHARED CODE

# Play respective directional animations
func animate_up():
	_animation_player.play("Up")
	_current_idle_sprite = "UpIdle"


func animate_down():
	_animation_player.play("Down")
	_current_idle_sprite = "DownIdle"


func animate_left():
	_animation_player.play("Left")
	_current_idle_sprite = "LeftIdle"


func animate_right():
	_animation_player.play("Right")
	_current_idle_sprite = "RightIdle"


func animate_idle():
	_animation_player.play(_current_idle_sprite)

# set sprite animation of this character
func set_sprite(sprite):
	$Sprite.set_texture(sprite)


func move_character_by_vector(directionVector : Vector2):
	if directionVector.length() == 0: #not moving, _current_idle_sprite and return early
		animate_idle()
		return
	
	directionVector = directionVector.normalized()
	_direction_facing = directionVector

	#play the correct animation based movement direction angle
	if abs(directionVector.x) >= abs(directionVector.y):
		#x mag is greater, use left/right animations
		if directionVector.x > 0:
			animate_right()
			
		else:
			animate_left()
			
	else:
		if directionVector.y > 0:
			animate_up()
			
		else:
			animate_down()
			
	_velocity = directionVector * walk_speed * get_physics_process_delta_time()
	_velocity = move_and_slide(_velocity)

