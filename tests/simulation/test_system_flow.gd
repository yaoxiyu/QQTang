extends Node

var world

func _ready():

	world = SimWorld.new()
	
	var config := SimConfig.new()

	world.bootstrap(config, {})

	for i in 60:
		world.step()
		print("flow %d" % i)

	print("flow ok")
