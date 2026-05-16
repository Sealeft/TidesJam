extends Area2D

@export var pull_strength := 200.0
@export var spin_strength  := 55.0

var _boats_inside: Array[RigidBody2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boat"):
		_boats_inside.append(body)


func _on_body_exited(body: Node2D) -> void:
	_boats_inside.erase(body)


func _physics_process(_delta: float) -> void:
	for boat: RigidBody2D in _boats_inside:
		var to_center := global_position - boat.global_position
		boat.apply_central_force(to_center.normalized() * pull_strength)
		boat.apply_torque(spin_strength)
