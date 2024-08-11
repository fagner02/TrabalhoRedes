extends CharacterBody2D

const initial = Vector2(0,1)
var direction = initial
var speed = 100
var selecting = true
@onready var player = $"Body"
@onready var selection = $"Body/AnimationPlayer"

func _ready():
	var _rotation = player.rotation
	direction = initial.rotated(_rotation)
	velocity = speed * direction

func select(new_direction: Vector2, rot, pos, vel):
	player.rotation = rot
	player.position = pos
	velocity = vel
	direction = new_direction
	print("slect")
	
	if selecting:
		selecting = false
		selection.play("close")
	else: 
		selecting = true
		selection.play("open")

func collide(new_direction: Vector2, rot, pos, vel):
	player.rotation = rot
	player.position = pos
	velocity = vel
	direction = new_direction

func _process(_delta):
	if selecting: 
		player.rotate(deg_to_rad(10))
		return
	move_and_collide(velocity)
	velocity *= 0.99
	
