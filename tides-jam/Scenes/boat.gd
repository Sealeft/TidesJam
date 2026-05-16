extends RigidBody2D

signal boat_sunk
signal cargo_lost

@export var paddle_force  := 520.0
@export var turn_force    := 320.0
@export var max_speed     := 320.0

# Directional drag — hull resists sideways movement much more than forward.
# Values are higher than before to compensate for the removed built-in linear/angular damp.
@export var water_linear_drag  := 1.8    # forward/back  (was ~1.75 total with old linear_damp=1.5)
@export var water_lateral_drag := 5.0    # side-to-side  (hull feel — much stronger)
@export var water_angular_drag := 2.2    # rotation      (was ~2.0 with old angular_damp)

@export var boat_mass      := 1.5
@export var turn_stability := 0.8

# Wave rocking — gentle oscillating torque simulating surface chop
@export var wave_rock_strength := 7.0
@export var wave_rock_period   := 3.4   # seconds per full rock cycle

# Micro-drift — tiny random nudges for choppy water texture
@export var chop_strength  := 12.0
@export var chop_interval  := 0.35   # average seconds between nudges

# Cargo — extra mass slows the boat and reduces top speed; crashes damage cargo
@export var cargo_mass             := 1.5
@export var cargo_speed_penalty    := 0.05  # fraction of max_speed lost when loaded
@export var damage_speed_threshold := 60.0  # px/s — below this, crashes don't damage
@export var damage_sensitivity     := 0.4   # cargo damage fraction from a full-speed crash
@export var hull_damage_sensitivity := 0.25  # hull damage fraction from a full-speed crash

@onready var left_oar:  Marker2D = $LeftOar
@onready var right_oar: Marker2D = $RightOar

var has_cargo    := false
var cargo_health := 1.0   # 0.0 – 1.0
var boat_health  := 1.0   # 0.0 – 1.0

var _wave_time        := 0.0
var _chop_timer       := 0.0
var _speed_last_frame := 0.0


func _ready() -> void:
	mass = boat_mass
	add_to_group("boat")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Cache pre-integration speed for collision damage checks
	_speed_last_frame = linear_velocity.length()

	var left    := Input.is_action_pressed("move_left")
	var right   := Input.is_action_pressed("move_right")
	var reverse := Input.is_action_pressed("move_back")

	_wave_time  += delta
	_chop_timer -= delta

	apply_rowing(left, right, reverse)
	apply_wave_rock()
	apply_chop()
	apply_water_drag(delta)
	clamp_velocity()


func apply_rowing(left: bool, right: bool, reverse: bool) -> void:
	var forward_dir := Vector2.UP.rotated(rotation)
	var dir_mult    := -0.8 if reverse else 1.0

	# S alone (no oar) → both oars backward
	if reverse and not left and not right:
		apply_central_force(forward_dir * paddle_force * -0.8)
		return

	# BOTH → strong force in current direction (forward or back)
	if left and right:
		apply_central_force(forward_dir * paddle_force * dir_mult)
		return

	# LEFT ONLY → forward/back + turn
	if left and not right:
		apply_force(
			forward_dir * paddle_force * 0.6 * dir_mult,
			left_oar.global_position - global_position
		)
		var torque_dir := -1.0 if reverse else 1.0
		apply_torque(turn_force * turn_stability * torque_dir)
		return

	# RIGHT ONLY → forward/back + turn
	if right and not left:
		apply_force(
			forward_dir * paddle_force * 0.6 * dir_mult,
			right_oar.global_position - global_position
		)
		var torque_dir := 1.0 if reverse else -1.0
		apply_torque(turn_force * turn_stability * torque_dir)


func apply_wave_rock() -> void:
	apply_torque(sin(_wave_time * TAU / wave_rock_period) * wave_rock_strength)


func apply_chop() -> void:
	if _chop_timer > 0.0:
		return
	apply_central_force(Vector2.from_angle(randf() * TAU) * chop_strength)
	_chop_timer = randf_range(chop_interval * 0.5, chop_interval * 1.5)


func apply_water_drag(delta: float) -> void:
	var fwd  := Vector2.UP.rotated(rotation)
	var side := fwd.rotated(PI * 0.5)

	var fwd_vel  := linear_velocity.dot(fwd)
	var side_vel := linear_velocity.dot(side)

	fwd_vel  *= 1.0 - water_linear_drag  * delta
	side_vel *= 1.0 - water_lateral_drag * delta

	linear_velocity = fwd * fwd_vel + side * side_vel
	angular_velocity *= 1.0 - water_angular_drag * delta


func clamp_velocity() -> void:
	var limit := max_speed * (1.0 - cargo_speed_penalty) if has_cargo else max_speed
	if linear_velocity.length() > limit:
		linear_velocity = linear_velocity.normalized() * limit


# --- Cargo ---

func load_cargo() -> void:
	has_cargo    = true
	cargo_health = 1.0
	mass = boat_mass + cargo_mass


func unload_cargo() -> void:
	has_cargo = false
	mass = boat_mass


func _on_body_entered(_body: Node) -> void:
	if _speed_last_frame <= damage_speed_threshold:
		return
	var impact := (_speed_last_frame - damage_speed_threshold) / (max_speed - damage_speed_threshold)

	# Hull takes damage from every collision
	boat_health = maxf(0.0, boat_health - impact * hull_damage_sensitivity)
	if boat_health <= 0.0:
		boat_sunk.emit()
		return

	# Cargo takes additional damage only when loaded
	if has_cargo:
		cargo_health = maxf(0.0, cargo_health - impact * damage_sensitivity)
		if cargo_health <= 0.0:
			cargo_lost.emit()
