class_name BossPudding
extends Slime
## Boss pudding: a big crowned slime that falls into the field centre, hops slowly and drops a rich
## burst of coins. It does not count toward the normal slime population cap.
##
## Implements design/game-brief.md (MVP 7) via production/epics/slime-nodaji/story-007-run-events.md.
## Values: the "boss" section of assets/data/run_events.json (halved for the 640x360 base).

var _crown_color: Color = Color.WHITE
var _crown_rects: Array = []


## Applies the event rules from the "boss" config: coins, slow fixed hop speed, wide hp bar and crown.
## Call after `setup` (the slime config is copied so the shared one stays untouched).
func apply_event(boss_config: Dictionary) -> void:
	drop_count = int(boss_config["kill_coins"])
	rich_drop = true
	counts_toward_cap = false
	hp_bar_lift = boss_config["hp_bar_lift"]
	_cfg = _cfg.duplicate()
	_cfg["hop_speed_min"] = boss_config["hop_speed"]
	_cfg["hop_speed_max"] = boss_config["hop_speed"]
	_cfg["hp_bar_width"] = boss_config["hp_bar_width"]
	_crown_color = Color.html(boss_config["crown_color"])
	_crown_rects = boss_config["crown_rects"]


func _draw_decoration(body_top: float) -> void:
	for rect: Array in _crown_rects:
		draw_rect(Rect2(float(rect[0]), body_top + float(rect[1]), float(rect[2]), float(rect[3])), _crown_color)
