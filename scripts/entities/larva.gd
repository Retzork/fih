class_name Larva
extends SimEntity
## Sexy::Larva (P2.10 §5.5, `Larva::Update FUN_004F2930`). The same class family as the
## missiles (`Sexy::Missle` derives from it) but a different update: a falling mode and a
## shells-payout mode. Its gameplay identity is still open (Q-0023) - no spawn site was
## found - so the port models the recovered update as a shells pickup: the falling mode
## despawns at y < 64, the payout mode lerps to (550,30) by 1/7 per tick and pays shells
## when y drops below 40 (`Tank+0x4A8` + `FUN_0053C1E0` in the binary).
##
## The click hit test is `Larva::HitTest FUN_004D82A0`: kind 1 deflects, kind 0 is
## destroyed, kind 2 cannot be clicked.
##
## Not yet spawned by any system: the port exposes the entity and the click order so the
## spawner can be bound when one is found, rather than inventing a spawn site.

enum Mode { FALL, PAYOUT }

## `+0x5D` mode byte: 0 fall, 1 shells lerp.
var larva_mode := Mode.FALL
## Projectile-style kind for the hit test (0 destroy, 1 deflect, 2 not clickable).
var hit_kind := 0
var vx := 0.0
var vy := 0.0
## Emitted when the payout mode reaches the corner; the level routes it to shells.
signal shells_payout(larva)
## A 2-px burst at the click point (destroy/deflect), like the projectile's.
signal burst_requested(at: Vector2)

const FALL_DESPAWN_Y := 64.0
const PAYOUT_TARGET := Vector2(550.0, 30.0)
const PAYOUT_DIVISOR := 7.0
const PAYOUT_DESPAWN_Y := 40.0
const WRAP_X := 530.0
const HIT_BOX := 60.0
const BALL_HIT_OFFSET := Vector2(10.0, 10.0)
const DEFLECT_CENTER := 40.0
const DEFLECT_DIVISOR := -5.0
const DEFLECT_LIMIT := 1.0


static func create(pos: Vector2, mode: int = Mode.FALL, vy_: float = 1.5, kind: int = 0) -> Larva:
	var larva := Larva.new()
	larva.position = pos
	larva.larva_mode = mode
	larva.vy = vy_
	larva.hit_kind = kind
	return larva


func image_id() -> String:
	return "IMAGE_ENERGYBALL"


func _advance() -> void:
	if larva_mode == Mode.PAYOUT:
		position.x += (PAYOUT_TARGET.x - position.x) / PAYOUT_DIVISOR
		position.y += (PAYOUT_TARGET.y - position.y) / PAYOUT_DIVISOR
		if position.y < PAYOUT_DESPAWN_Y:
			shells_payout.emit(self)
			despawn()
		return
	# Mode 0: the binary literal `y -= vy` (P2.10 §5.5): the larva moves toward the top
	# and despawns at `y < 64`; `x > 530` wraps to 530.
	position.y -= vy
	if position.x > WRAP_X:
		position.x = WRAP_X
	if position.y < FALL_DESPAWN_Y:
		despawn()


## `Larva::HitTest` (P2.10 §5.4). Returns true when the click was consumed.
func hit_test(click: Vector2) -> bool:
	if dead:
		return false
	if hit_kind == 2:
		return false
	if hit_kind == 1:
		var box := Rect2(position + BALL_HIT_OFFSET, Vector2(HIT_BOX, HIT_BOX))
		if box.has_point(click):
			vx = clampf(((click.x - position.x) - DEFLECT_CENTER) / DEFLECT_DIVISOR,
				-DEFLECT_LIMIT, DEFLECT_LIMIT)
			vy = clampf(((click.y - position.y) - DEFLECT_CENTER) / DEFLECT_DIVISOR,
				-DEFLECT_LIMIT, DEFLECT_LIMIT)
			burst_requested.emit(click - Vector2(DEFLECT_CENTER, DEFLECT_CENTER))
			return true
		return false
	var center_box := Rect2(
		position - Vector2(HIT_BOX * 0.5, HIT_BOX * 0.5), Vector2(HIT_BOX, HIT_BOX))
	if center_box.has_point(click):
		burst_requested.emit(click - Vector2(DEFLECT_CENTER, DEFLECT_CENTER))
		despawn()
		return true
	return false
