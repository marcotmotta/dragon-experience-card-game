extends Effect
class_name GainTargetStatsEffect

func execute_state(resolver, source, target = null) -> void:
	if target and target.get('kind') == GameEnums.EntityKind.MINION:
		source.gain_status(target.current_attack, target.current_health)
		resolver.emit(Events.stat_buffed(source.id, target.current_attack, target.current_health))
