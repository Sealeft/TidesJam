extends Node2D

@export var orbit_radius := 80.0

var world: Node

@onready var arrow_sprite = $ArrowSprite
@onready var boat = get_parent()

func _ready():
	world = get_tree().current_scene

	# Ignore parent's transform/rotation
	top_level = true

func _process(_delta):

	var target = world.get_current_destination()

	if target == null:
		return

	# Direction from boat to destination
	var dir = boat.global_position.direction_to(
		target.global_position
	)

	# Position arrow around boat in WORLD space
	global_position = boat.global_position + dir * orbit_radius

	# Rotate arrow toward destination
	arrow_sprite.global_rotation = dir.angle() + deg_to_rad(135)
