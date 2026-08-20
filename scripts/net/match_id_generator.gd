class_name MatchIdGenerator
extends RefCounted


static func generate() -> String:
	return "m_%d_%d" % [Time.get_unix_time_from_system(), randi()]
