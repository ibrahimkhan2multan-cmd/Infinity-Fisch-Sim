extends SceneTree
## Headless test runner:
##   godot --headless --path game -s res://tests/run_tests.gd
## Loads every res://tests/cases/test_*.gd, calls run(t) on each and exits with
## a non-zero code if any check failed (used by the GitHub workflow).

var checks := 0
var failures: Array[String] = []
var _current := ""


func check(cond: bool, message: String) -> void:
	checks += 1
	if not cond:
		failures.append("[%s] %s" % [_current, message])
		print("  FAIL: ", message)


func approx(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps


func _initialize() -> void:
	var dir := DirAccess.open("res://tests/cases")
	if dir == null:
		print("No test cases directory.")
		quit(1)
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and (f.ends_with(".gd") or f.ends_with(".gd.remap")):
			files.append(f.trim_suffix(".remap"))
	files.sort()
	for f in files:
		_current = f
		print("== ", f)
		var script: GDScript = load("res://tests/cases/" + f)
		if script == null or not script.can_instantiate():
			failures.append("[%s] could not load (parse error)" % f)
			print("  FAIL: could not load ", f)
			continue
		var inst: Object = script.new()
		if inst.has_method("run"):
			await inst.call("run", self)
		else:
			failures.append("[%s] has no run(t)" % f)
	print("")
	print("Checks: %d  Failures: %d" % [checks, failures.size()])
	for m in failures:
		print("  - ", m)
	quit(1 if failures.size() > 0 else 0)
