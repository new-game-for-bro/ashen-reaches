extends Node3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("20252a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7b8389")
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color("555961")
	env.fog_density = 0.018
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = env
	add_child(atmosphere)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_color = Color("c9b4a6")
	sun.light_energy = 0.8
	add_child(sun)
	var layer := CanvasLayer.new()
	add_child(layer)
	var instructions := Label.new()
	instructions.position = Vector2(20, 20)
	instructions.text = "TRAINING ARENA  ·  Move with the joystick; drag to look" if OS.has_feature("mobile") else "ASHEN REACHES  /  TRAINING ARENA\nWASD move  •  Mouse orbit  •  Shift run  •  Space jump  •  C dodge\nLeft click light attack  •  Right click heavy attack  •  Q lock on  •  Esc cursor"
	instructions.add_theme_font_size_override("font_size", 16)
	layer.add_child(instructions)

	# A light scattering of drifting embers makes depth and motion visible.
	var embers := GPUParticles3D.new()
	embers.amount = 32
	embers.lifetime = 5.0
	embers.position = Vector3(0, 3, 0)
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(16, 3, 16)
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.gravity = Vector3(0, 0.1, 0)
	particle_material.initial_velocity_min = 0.05
	particle_material.initial_velocity_max = 0.2
	embers.process_material = particle_material
	var spark := SphereMesh.new()
	spark.radius = 0.035
	spark.height = 0.07
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("cf8654")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.material = glow
	embers.draw_pass_1 = spark
	add_child(embers)
