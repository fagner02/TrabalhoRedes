extends CharacterBody2D

const initial = Vector2(0,1)
var direction = initial
var speed = 100
var deacelaration = 0
var selecting = true
@onready var player = $"Body"
@onready var selection = $"Body/AnimationPlayer"

func _ready():
	var _rotation = player.rotation
	direction = initial.rotated(_rotation)
	velocity = speed * direction

func _input(event):
	if(event.is_action_pressed("space")) or (event is InputEventScreenTouch and event.is_pressed()):
		if selecting:
			selecting = false
			selection.play("close")
			var _rotation = player.rotation
			direction = -initial.rotated(_rotation)
			velocity = speed * direction
		else: 
			selecting = true
			selection.play("open")

func _process(delta):
	if selecting: 
		player.rotate(deg_to_rad(10))
		return
	var collision = move_and_collide(velocity)
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		player.rotation = velocity.angle()+deg_to_rad(90)
	velocity *= 0.99
	
