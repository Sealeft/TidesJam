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
var _delivery_count  := 0
var _last_tier       := 0
var _started         := false
var _dead            := false

@onready var boat          : RigidBody2D = $Boat
@onready var tide_hud      : Control     = $HUDLayer/TideHUD
@onready var mission_label : Label       = $HUDLayer/DeliveryHUD/MissionLabel
@onready var health_label  : Label       = $HUDLayer/DeliveryHUD/HealthLabel
@onready var hull_label    : Label       = $HUDLayer/DeliveryHUD/HullLabel
@onready var score_label       : Label       = $HUDLayer/DeliveryHUD/ScoreLabel
@onready var start_screen      : ColorRect   = $MenuLayer/StartScreen
@onready var death_screen      : ColorRect   = $MenuLayer/DeathScreen
@onready var death_score_label : Label       = $MenuLayer/DeathScreen/DeathScoreLabel



func _ready() -> void:
	_pick_new_target()
	# Children call _ready before the parent, so islands are already in their group
	_islands = get_tree().get_nodes_in_group("islands")
	for island: Node2D in _islands:
		island.boat_docked.connect(_on_island_docked)
	boat.boat_sunk.connect(_on_boat_sunk)
	boat.cargo_lost.connect(_on_cargo_lost)
	_start_new_delivery()
	AudioManager.play("res://Audio/OceanAmbience.wav")


func _physics_process(delta: float) -> void:
	if not _started or _dead:
		return
	_update_tide(delta)
	boat.apply_central_force(tide_vec)


func _process(_delta: float) -> void:
	if not _started:
		return
	tide_hud.update_tide(tide_vec)
	hull_label.text = "Hull: %d%%" % int(boat.boat_health * 100)
	if boat.has_cargo:
		health_label.text = "Cargo: %d%%" % int(boat.cargo_health * 100)
	else:
		health_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not _started and not _dead:
		_start_game()
	elif _dead:
		get_tree().reload_current_scene()


func _start_game() -> void:
	_started = true
	start_screen.visible = false


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
	if not _started or _dead:
		return
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
		_delivery_count += 1
		var tier_up := _apply_difficulty()
		boat.unload_cargo()
		# Reward careful delivery with a small hull repair
		boat.boat_health = minf(1.0, boat.boat_health + 0.12)
		for isl: Node2D in _islands:
			isl.set_status("")
		if tier_up:
			mission_label.text = "Delivered! +%d  — Tide rising!" % (1 + health_bonus)
		else:
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


## Scales tide difficulty based on number of completed deliveries.
## Returns true when a new difficulty tier is reached.
func _apply_difficulty() -> bool:
	var tier := _delivery_count / 3   # integer division — new tier every 3 deliveries
	max_tide_strength = minf(110.0 + tier * 18.0, 300.0)
	tide_hold_min     = maxf(7.0  - tier * 0.6,   2.5)
	tide_hold_max     = maxf(14.0 - tier * 1.2,   5.0)
	if tier > _last_tier:
		_last_tier = tier
		return true
	return false


func _on_boat_sunk() -> void:
	_dead = true
	death_score_label.text = "Score: %d" % _score
	death_screen.visible   = true


func _on_cargo_lost() -> void:
	boat.unload_cargo()
	_awaiting_pickup = true
	for isl: Node2D in _islands:
		isl.set_status("")
	_pickup_island.set_status("[PICKUP]")
	mission_label.text = "Cargo lost! Return to: " + _pickup_island.island_name
	health_label.text  = ""
	
func get_current_destination() -> Node2D:
	if _awaiting_pickup:
		return _pickup_island
	else:
		return _deliver_island
