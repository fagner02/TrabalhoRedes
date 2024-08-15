extends CharacterBody2D

const initial = Vector2(0,1)
var direction = initial
var speed = 100
var selecting = true
@onready var player = $"."
@onready var selection = $"outline/AnimationPlayer"

func _ready():
	var _rotation = player.rotation
	direction = initial.rotated(_rotation)
	velocity = speed * direction

func select(new_direction: Vector2, rot, pos, vel, _selecting):
	selecting = _selecting
	player.rotation = rot
	player.position = pos
	velocity = vel
	direction = new_direction
	print("slect:", selecting, velocity)
	
	if selecting:
		print("close")
		selecting = false
		selection.play("close")
	else: 
		print("open")
		selecting = true
		selection.play("open")
	
	

func collide(new_direction: Vector2, rot, pos, vel):
	player.rotation = rot
	player.position = pos
	velocity = vel
	direction = new_direction

func _process(_delta):
	if selecting == false:
		print("isss: ", selecting)
	if selecting:
		player.rotate(deg_to_rad(10))
		return
	move_and_collide(velocity)
	velocity *= 0.99
	
