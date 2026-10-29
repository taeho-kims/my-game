class_name GoldenSlime
extends Slime
## Golden slime: a normal slime with a gold body that drops a rich burst of coins when killed.
##
## Implements design/game-brief.md (MVP 7) via production/epics/slime-nodaji/story-007-run-events.md.
## Values: the "golden" section of assets/data/run_events.json.


## Applies the event rules: kill coins from `golden_config` and the rich (gem/silver heavy) drop.
func apply_event(golden_config: Dictionary) -> void:
	drop_count = int(golden_config["kill_coins"])
	rich_drop = true
