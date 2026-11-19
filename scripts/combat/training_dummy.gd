extends StaticBody3D

var health: int = 100
@onready var label: Label3D = $Label3D

func _ready() -> void:
	add_to_group("training_targets")
	_update_label()

func hit(amount: int) -> void:
	health -= amount
	if health <= 0:
		health = 100
	_update_label()

func _update_label() -> void:
	label.text = "TRAINING DUMMY\nHP %d / 100" % health
