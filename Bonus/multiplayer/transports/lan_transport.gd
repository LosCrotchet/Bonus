class_name LanTransport
extends RefCounted

const MAX_CLIENTS := 3

var peer: ENetMultiplayerPeer
var last_error := OK


func create_server(port: int) -> ENetMultiplayerPeer:
	close()
	peer = ENetMultiplayerPeer.new()
	last_error = peer.create_server(port, MAX_CLIENTS)
	return peer if last_error == OK else null


func create_client(address: String, port: int) -> ENetMultiplayerPeer:
	close()
	peer = ENetMultiplayerPeer.new()
	last_error = peer.create_client(address, port)
	return peer if last_error == OK else null


func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	last_error = OK
