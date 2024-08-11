extends Node2D

class Peer:
	var connection: PacketPeerUDP
	var ip: String
	var port: String

class Oponent:
	var name: String
	var player: CharacterBody2D
	var score: int
	var hue: float
	var pos: Vector2

class Point:
	var name: String
	var point: Sprite2D

var ip = get_ip()
var initial_port = 5000
var add_to_port = 0
var client = PacketPeerUDP.new()
var udp_server = UDPServer.new()
var is_host = false
var peers: Array[Peer] = []

var points: Array[Point] = []
var oponents: Array[Oponent] = []
var initial_pos = Vector2(100,100)
var hue = 0
var score = 0
var started = false
var finished = false

@onready var background = $"background"
@onready var controls = $"Control"
@onready var bounds = $"StaticBody2D"
@onready var player = $"player"
@onready var background_size = Vector2(background.texture.get_width(), background.texture.get_height())
@onready var screen_size = get_viewport_rect().size

@onready var point_timer = $"PointTimer"
@onready var game_timer = $"GameTimer"
@onready var select_timer = $"SelectTimer"

var playername = ""
var playerscene = preload("res://oponent.tscn")
var pointscene = preload("res://point.tscn")

var rng = RandomNumberGenerator.new()

func _ready():
	initialize()

func initialize():
	ip = get_ip()
	initial_pos = rand_pos()
	player.position = initial_pos
	while (add_to_port < 10):
		if udp_server.listen(initial_port+add_to_port, ip) == OK:
			break
		add_to_port += 1
	game_timer.one_shot = true

func rand_pos(pad = Vector2(50, 50)):
	return (screen_size - (pad*2.0)) * Vector2(rng.randf(), rng.randf())+pad

func restart():
	point_timer.stop()
	udp_server.stop()
	udp_server = UDPServer.new()
	client.close()
	client.close()
	client = PacketPeerUDP.new()
	for oponent in oponents:
		oponent.player.queue_free()
	oponents.clear()
	for point in points:
		point.point.queue_free()
	points.clear()
	peers.clear()
	if not player.selecting:
		player.select()
	started = false
	add_to_port = 0
	score = 0
	is_host = false
	$"%scorebox".visible = false
	$"%result".visible = false
	$"%startmenu".visible = true
	initialize()

func _process(_delta):
	if (get_viewport_rect().size != screen_size):
		screen_size = get_viewport_rect().size
		controls.size = screen_size
		
		var children = bounds.get_children()
		children[0].shape.b.x = screen_size.x
		children[1].shape.b.x = screen_size.x
		children[1].position.y = screen_size.y
		children[2].shape.b.y = screen_size.y
		children[3].shape.b.y = screen_size.y
		children[3].position.x = screen_size.x
		var ratio = Vector2(((screen_size/2.0).length()*2.0)/screen_size.x, ((screen_size/2.0).length()*2.0)/screen_size.y)
		background.scale = ((screen_size/background_size) * ratio)
		background.position = screen_size/2.0
	
	var minutes = floor(game_timer.time_left/60.0)
	var seconds = floor(game_timer.time_left- minutes*60)
	$"%timestamp".text = str(minutes).lpad(2, "0")+":"+str(seconds).lpad(2, "0")
	if game_timer.time_left == 0 and started:
		finished = true
		if (oponents.any(func(x): return x.score > score)):
			$"%result_text".text = "YOU LOST"
		else:
			$"%result_text".text = "YOU WIN"
		$"%result".visible=true
		started = false
	
	udp_server.poll()
 
	if udp_server.is_connection_available() and is_host and not started:
		var connection = udp_server.take_connection()
		connection.get_packet()
		
		var new_peer = Peer.new()
		new_peer.connection = connection
		peers.append(new_peer)
		
		var rpos = rand_pos()
		connection.put_packet(JSON.stringify({
			"action":"connected",
			"players": oponents + [
				{"name":playername,
				"color": hue, 
				"pos": {"x": initial_pos.x, "y": initial_pos.y}}],
			"color": (oponents.size()+1)*0.1,
			"pos": {"x": rpos.x, "y": rpos.y}
		}).to_utf8_buffer())
	get_packets()

func get_packets():
	if (not is_host):
		if client.get_available_packet_count() <= 0:
			return
		var json = client.get_packet().get_string_from_utf8()
		var res = JSON.parse_string(json)

		if (res.action == "connected"):
			client.put_packet(JSON.stringify({
				"action":"add", 
				"name": playername, 
				"color": res.color, 
				"pos": res.pos
			}).to_utf8_buffer())
			player.get_child(0).get_child(0).self_modulate.h = res.color
			player.position = Vector2(res.pos.x, res.pos.y)
			for _player in res.players:
				add_oponent(_player.name, _player.color, Vector2(_player.pos.x, _player.pos.y))
		if (res.action == "add"):
			add_oponent(res.name, res.color, Vector2(res.pos.x, res.pos.y))
		if (res.action == "select"):
			oponent_select(res)
		if (res.action == "collide"):
			oponent_collide(res)
		if (res.action == "point"):
			oponent_point(res)
		if (res.action == "create_point"):
			create_point(Vector2(res.pos.x, res.pos.y), res.name)
		if (res.action == "start"):
			$"%waitingsign".visible = false
			$"%scorebox".visible = true
			started = true
			game_timer.start(res.time)
		return
		
	for peer: Peer in peers:
		if peer.connection.get_available_packet_count() > 0:
			var res = JSON.parse_string(peer.connection.get_packet().get_string_from_utf8())

			if res.action == "connected":
				player.position = initial_pos
			if res.action == "add":
				add_oponent(res.name, res.color, Vector2(res.pos.x, res.pos.y))
				send_packets(res, peer)
			if (res.action == "select"):
				oponent_select(res)
				send_packets(res, peer)
			if (res.action == "collide"):
				oponent_collide(res)
				send_packets(res, peer)
			if res.action == "point":
				oponent_point(res)
				send_packets(res, peer)
			

func send_packets(data, _peer = null):
	for peer: Peer in peers:
		if peer != _peer or _peer == null:
			peer.connection.put_packet(JSON.stringify(data).to_utf8_buffer())

func create_point(_pos = null, _name = null):
	if _pos == null:
		_pos = rand_pos()
		_name = "point"
		
	var point = Point.new()
	point.point = pointscene.instantiate()
	point.point.position = _pos
	add_child(point.point)
	point.point.name = _name 
	point.name = point.point.name
	points.append(point)
	return [_pos, point.name]

func consume_point(_name):
	score+=1
	$"%score".text = "score: "+str(score)
	var point = points.filter(func(x): return x.name == _name)[0]
	var packet = {
		"action": "point",
		"player": playername,
		"name":  point.name
	}
	point.point.queue_free()
	points.erase(point)
	if is_host:
		send_packets(packet)
	else:
		client.put_packet(JSON.stringify(packet).to_utf8_buffer())

func oponent_point(res):
	oponents.filter(func(x): return x.name == res.player)[0].score+=1
	var list = points.filter(func(x): return x.name == res.name)
	if list.size() == 0:
		return
	var point = list[0]
	point.point.queue_free()
	points.erase(point)
	
func oponent_select(res):
	var list = oponents.filter(func(x): return x.name == res.player)
	if list.size() == 0:
		return
	var oponent = list[0]
	oponent.player.select(
		Vector2(res.new_direction.x, res.new_direction.y), 
		res.rot, 
		Vector2(res.pos.x, res.pos.y),
		Vector2(res.vel.x, res.vel.y)
	)

func oponent_collide(res):
	var list = oponents.filter(func(x): return x.name == res.player)
	if list.size() == 0:
		return
	var oponent = list[0]
	oponent.player.collide(
		Vector2(res.new_direction.x, res.new_direction.y), 
		res.rot, 
		Vector2(res.pos.x, res.pos.y),
		Vector2(res.vel.x, res.vel.y)
	)

func send_select(new_direction: Vector2, rot, pos: Vector2, vel):
	var packet = {
		"from": ":",
		"action": "select",
		"new_direction": {"x": new_direction.x, "y": new_direction.y},
		"pos": {"x": pos.x, "y":pos.y},
		"rot": rot,
		"vel": {"x":vel.x, "y": vel.y},
		"player": playername
	}
	if is_host:
		send_packets(packet)
	else:
		client.put_packet(JSON.stringify(packet).to_utf8_buffer())

func send_collide(new_direction: Vector2, rot, pos: Vector2, vel):
	var packet = {
		"from": ":",
		"action": "collide",
		"new_direction": {"x": new_direction.x, "y": new_direction.y},
		"pos": {"x": pos.x, "y":pos.y},
		"rot": rot,
		"vel": {"x":vel.x, "y": vel.y},
		"player": playername
	}
	if is_host:
		send_packets(packet)
	else:
		client.put_packet(JSON.stringify(packet).to_utf8_buffer())

func add_oponent(_name, _color, _pos):
	var new_oponent = Oponent.new()
	new_oponent.player = playerscene.instantiate()
	new_oponent.player.position = _pos
	new_oponent.player.get_child(0).get_child(0).self_modulate.h = _color
	new_oponent.name = _name
	new_oponent.pos = _pos
	new_oponent.hue = _color
	add_child(new_oponent.player)
	oponents.append(new_oponent)

func _on_button_join_host():
	var code: String = $"%iptext".text
	if code.length() < 4:
		return
	var dest = ".".join(ip.split(".").slice(0, 2))+"."+\
		".".join([0, 2].map(func(num): return str(code.substr(num, 2).hex_to_int())))

	$"%startmenu".visible = false
	$"%waitingsign".visible = true
	client.connect_to_host(dest, initial_port+int(code.substr(4,1)))
	client.put_packet(JSON.stringify({"action":"connect", "name":playername}).to_utf8_buffer())

func _on_button_create_host():
	is_host = true
	print("ip: ", ip)
	var res = "".join(Array(ip.split(".").slice(2, 6)).map(func(num): return ("%x" % int(num)).lpad(2, "0"))).to_upper()
	
	$"%startmenu".visible = false
	$"%hostmenu".visible = true
	$"%code".text = res+str(add_to_port)

func  get_ip():
	var _ip: String

	for address in IP.get_local_interfaces():
		if address["friendly"].to_lower().begins_with("w"):
			_ip = address["addresses"].filter(func(x: String): return x.split(".").size() == 4)[0]
			break

	return _ip

func _on_name_text_changed():
	playername = $"%name".text
	pass 

func _on_start_pressed():
	player.visible = true
	$"%hostmenu".visible=false
	$"%scorebox".visible = true
	started = true
	var time =  int($"%time".text)
	send_packets({
		"from": ":",
		"action": "start",
		"time": time
	})
	point_timer.start(2)
	game_timer.start(time)
	pass

func _on_point_timeout():
	var values = create_point()
	var _pos = values[0]
	send_packets({
		"action": "create_point",
		"pos": {"x": _pos.x, "y": _pos.y},
		"name": values[1]
	})
	
