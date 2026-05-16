extends StaticBody2D

@export var speed := 75.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x -= speed * delta


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Barrel"):
		queue_free()
