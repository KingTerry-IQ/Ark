extends SceneTree

## Operator-only. Kindles the selected chain from the revenue wallet.
## There is no button for this in the window.
##
##   Godot --headless --path . --script res://tools/kindle.gd -- mon
##
## The chain argument is mon, sol, or rh. It spends createTable fees.


func _init() -> void:
	_go()


func _go() -> void:
	var chain := "mon"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		chain = Costs.code(str(args[0]))
	var iq := IQClient.new()
	root.add_child(iq)
	# request() fails until the client has entered the tree.
	await process_frame
	if not await iq.discover("Ark"):
		print("No host. ", iq.last_error)
		quit(1)
		return
	print("Kindling %s as %s" % [chain, iq.app_label])
	var cabinet := Cabinet.new(iq, chain)
	if not await cabinet.kindle():
		print(cabinet.last_error)
		quit(1)
		return
	print("Kindled %s." % chain)
	quit(0)
