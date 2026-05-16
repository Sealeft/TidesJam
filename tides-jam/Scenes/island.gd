extends Node2D

signal boat_docked(island: Node2D)

@export var island_name := "Island"

@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	add_to_group("islands")
	$DockZone.body_entered.connect(_on_body_entered)
	set_status("")


func set_status(text: String) -> void:
	if text == "":
		status_label.text = island_name
	else:
		status_label.text = island_name + "\n" + text


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boat"):
		boat_docked.emit(self)
