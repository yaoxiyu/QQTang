extends Node

func _ready():

	var buffer = InputBuffer.new()

	var frame = buffer.consume_or_build_for_tick(
		10,
		[0,1]
	)
	if frame != null:
		print("input true")
	else:
		print("input false")
