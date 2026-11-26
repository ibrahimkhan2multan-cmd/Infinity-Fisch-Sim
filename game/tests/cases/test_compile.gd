extends RefCounted
## Every script under res://scripts must compile. (A parse error in one file
## silently breaks everything that depends on it, so check them all.)


func run(t) -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	t.check(files.size() > 40, "found the script files (%d)" % files.size())
	var bad := 0
	for f in files:
		var s: Variant = load(f)
		# a script with a parse error still loads, but cannot be instantiated
		if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate():
			bad += 1
			t.check(false, "does not compile: " + f)
	t.check(bad == 0, "all scripts compile")


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_collect(dir + "/" + sub, out)
	for f in d.get_files():
		var name := f.trim_suffix(".remap")
		if name.ends_with(".gd"):
			out.append(dir + "/" + name)
