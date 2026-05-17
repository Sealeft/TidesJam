extends Node2D


@export var barrel_direction := true #true = left, false = right
@onready var barrel_scene := preload("res://Scenes/barrel.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_barrel_spawn_timer_timeout() -> void:
	spawn_barrel()

func spawn_barrel() -> void:
	var barrel = barrel_scene.instantiate()
	barrel.dir = barrel_direction
	add_child(barrel)
	
	var offset = Vector2(randf_range(-100, 100), randf_range(-1200, 1200))
	barrel.global_position = global_position + offset
