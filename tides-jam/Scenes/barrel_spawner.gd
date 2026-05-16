extends Node2D

@onready var barrel_scene := preload("res://Scenes/barrel.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_barrel_spawn_timer_timeout() -> void:
	spawn_barrel()

func spawn_barrel() -> void:
	var barrel = barrel_scene.instantiate()
	add_child(barrel)
	
	var offset = Vector2(randf_range(-100, 100), randf_range(-500, 500))
	barrel.global_position = global_position + offset
