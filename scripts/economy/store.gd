class_name Store
extends RefCounted
## The twelve store items (P2.5 §2, `FUN_00538100`/`FUN_00549380`).
##
## `id` is the original item id; `price` is the wiki/EV-0060 figure where one is known, otherwise 0
## and the row still comes from the save's own price array. `kind` says what the purchase does:
##
##   fish          -> spawn a fish of `species`
##   food_quality  -> `DAT_005e89dc++`, capped at 2
##   food_quantity -> `DAT_005df58c++`, capped at 9
##   weapon        -> `+0x3E4++`, capped at 0xC (P2.5 §2)
##   unavailable   -> the effect needs a body/aspect that is not ported yet (Q-0049)
##
## Q-0049 records everything this table cannot yet promise: the breeder, the three pet
## purchases and the egg piece/random-pet/end-level row have no implementation, and the binary's own
## initial price arrays were never located (`§3` of the note), so the prices here are the wiki's.

const KIND_FISH := "fish"
const KIND_FOOD_QUALITY := "food_quality"
const KIND_FOOD_QUANTITY := "food_quantity"
const KIND_WEAPON := "weapon"
const KIND_STAR_POTION := "star_potion"
const KIND_UNAVAILABLE := "unavailable"

const FOOD_QUALITY_MAX := 2
const FOOD_QUANTITY_MAX := 9
## `Tank+0x3E4 < 0xC` is the weapon upgrade's guard in the buy hub.
const WEAPON_MAX := 0xC
const PRICE_CLAMP := 99999

const ITEMS := {
	0: {"name": "Guppy", "price": 100, "kind": KIND_FISH, "species": 0},
	1: {"name": "Breeder", "price": 0, "kind": KIND_UNAVAILABLE},
	2: {"name": "Food Quality", "price": 200, "kind": KIND_FOOD_QUALITY},
	3: {"name": "Food Quantity", "price": 300, "kind": KIND_FOOD_QUANTITY},
	4: {"name": "Carnivore", "price": 0, "kind": KIND_FISH, "species": 1},
	5: {"name": "Star Potion", "price": 0, "kind": KIND_STAR_POTION},
	6: {"name": "Starcatcher", "price": 750, "kind": KIND_UNAVAILABLE},
	7: {"name": "Guppycruncher", "price": 750, "kind": KIND_UNAVAILABLE},
	8: {"name": "Beetlemuncher", "price": 2000, "kind": KIND_UNAVAILABLE},
	9: {"name": "Ultravore", "price": 0, "kind": KIND_FISH, "species": 2},
	10: {"name": "Weapon", "price": 0, "kind": KIND_WEAPON},
	11: {"name": "Egg", "price": 99999, "kind": KIND_UNAVAILABLE},
}


static func item(id: int) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: int) -> String:
	return String(item(id).get("name", "Empty"))


## A store row for `id`, as the twelve 17-byte rows are shaped (`slot`, price, base, increment,
## present). `SetStorePrice` clamps to 99999 (P2.5 §3).
static func row_for(id: int) -> Dictionary:
	var price := mini(int(item(id).get("price", 0)), PRICE_CLAMP)
	return {"slot": id, "price": price, "base": price, "increment": 0, "present": 0}


## Mode-4 price inflation (P2.5 §3): a row's price grows by its `increment` (`+0x374`) per tick and
## never exceeds `SetStorePrice`'s 99,999 clamp. Rows with a zero increment never move.
static func inflate(row: Dictionary, ticks: int) -> void:
	var step := int(row.get("increment", 0))
	if step == 0 or ticks <= 0:
		return
	row["price"] = mini(int(row.get("price", 0)) + step * ticks, PRICE_CLAMP)


## A price of 0 is the table's "not recovered" marker (P2.5 §3 never located the binary's own arrays),
## not a free item - no item in the wiki figures costs nothing. A row that carries a price (from a
## save or from challenge inflation) is sellable even when the table has no figure for its item,
## and so is a row whose 0 is a **recovered** price (tank 5's egg, P2.6 §3, marked `free`).
static func price_known(row: Dictionary) -> bool:
	return int(row.get("price", 0)) > 0 or bool(row.get("free", false))


## Whether the purchase's effect can be applied by the port today.
static func is_available(id: int) -> bool:
	var data := item(id)
	return not data.is_empty() and String(data.get("kind", KIND_UNAVAILABLE)) != KIND_UNAVAILABLE
