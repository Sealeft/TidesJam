extends Node

## Peak force the tide can apply (pixels/second²)
@export var max_tide_strength := 110.0
## Minimum seconds the tide holds its direction before picking a new one
@export var tide_hold_min := 7.0
## Maximum seconds the tide holds its direction before picking a new one
@export var tide_hold_max := 14.0
## How quickly the tide shifts toward its new direction (higher = faster transition)
@export var tide_lerp_speed := 0.9

var tide_vec  := Vector2.ZERO
var _target_vec := Vector2.ZERO
var _hold_timer := 0.0

# --- Delivery state ---
var _islands        : Array   = []
var _pickup_island  : Node2D  = null
var _deliver_island : Node2D  = null
var _score          := 0
var _awaiting_pickup := true

@onready var boat          : RigidBody2D = $Boat
@onready var tide_hud      : Control     = $HUDLayer/TideHUD
@onready var mission_label : Label       = $HUDLayer/DeliveryHUD/MissionLabel
@onready var health_label  : Label       = $HUDLayer/DeliveryHUD/HealthLabel
@onready var score_label   : Label       = $HUDLayer/DeliveryHUD/ScoreLabel


func _ready() -> void:
	_pick_new_target()
	# Children call _ready before the parent, so islands are already in their group
	_islands = get_tree().get_nodes_in_group("islands")
	for island: Node2D in _islands:
		island.boat_docked.connect(_on_island_docked)
	_start_new_delivery()


func _physics_process(delta: float) -> void:
	_update_tide(delta)
	boat.apply_central_force(tide_vec)


func _process(_delta: float) -> void:
	tide_hud.update_tide(tide_vec)
	if boat.has_cargo:
		health_label.text = "Cargo: %d%%" % int(boat.cargo_health * 100)


func _update_tide(delta: float) -> void:
	_hold_timer -= delta
	if _hold_timer <= 0.0:
		_pick_new_target()
	tide_vec = tide_vec.lerp(_target_vec, tide_lerp_speed * delta)


func _pick_new_target() -> void:
	var angle    := randf() * TAU
	var strength := randf_range(max_tide_strength * 0.2, max_tide_strength)
	_target_vec  = Vector2.from_angle(angle) * strength
	_hold_timer  = randf_range(tide_hold_min, tide_hold_max)


# --- Delivery loop ---

func _start_new_delivery() -> void:
	if _islands.size() < 2:
		mission_label.text = "No islands found!"
		return
	var shuffled := _islands.duplicate()
	shuffled.shuffle()
	_pickup_island   = shuffled[0]
	_deliver_island  = shuffled[1]
	_awaiting_pickup = true
	for isl: Node2D in _islands:
		isl.set_status("")
	_pickup_island.set_status("[PICKUP]")
	_update_mission_label()


func _on_island_docked(island: Node2D) -> void:
	# Pick up cargo
	if _awaiting_pickup and island == _pickup_island and not boat.has_cargo:
		boat.load_cargo()
		_pickup_island.set_status("")
		_deliver_island.set_status("[DELIVER HERE]")
		_awaiting_pickup = false
		_update_mission_label()
		return

	# Deliver cargo
	if not _awaiting_pickup and island == _deliver_island and boat.has_cargo:
		var health_bonus := int(boat.cargo_health * 3)
		_score += 1 + health_bonus
		boat.unload_cargo()
		for isl: Node2D in _islands:
			isl.set_status("")
		mission_label.text = "Delivered!  +" + str(1 + health_bonus)
		health_label.text  = ""
		score_label.text   = "Score: %d" % _score
		await get_tree().create_timer(1.5).timeout
		_start_new_delivery()


func _update_mission_label() -> void:
	score_label.text = "Score: %d" % _score
	health_label.text = ""
	if _awaiting_pickup:
		mission_label.text = "Pick up at: " + _pickup_island.island_name
	else:
		mission_label.text = "Deliver to: " + _deliver_island.island_name
