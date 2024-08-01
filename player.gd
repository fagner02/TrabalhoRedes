extends CharacterBody2D

const initial = Vector2(0,1)
var direction = initial
var speed = 100
var selecting = true
@onready var player = $"Body"
@onready var selection = $"Body/AnimationPlayer"
@export var pos = Vector2(0,0)

func _ready():
	var _rotation = player.rotation
	direction = initial.rotated(_rotation)
	velocity = speed * direction

func select(new_direction: Vector2):
	if selecting:
		selecting = false
		selection.play("close")
		direction = new_direction
		velocity = speed * direction
		player.rotation = velocity.angle()+deg_to_rad(90)
	else: 
		selecting = true
		selection.play("open")

func _process(_delta):
	if selecting: 
		player.rotate(deg_to_rad(10))
		return
	var collision = move_and_collide(velocity)
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		player.rotation = velocity.angle()+deg_to_rad(90)
	velocity *= 0.99
	
