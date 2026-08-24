extends TestCase
## RngService: seeded determinism (charter §34 — reproducible combat).

const RngScript: GDScript = preload("res://autoload/rng_service.gd")


func test_same_seed_same_sequence() -> void:
	var a: Node = RngScript.new()
	var b: Node = RngScript.new()
	a.set_seed(12345)
	b.set_seed(12345)
	for _i in 50:
		assert_eq(a.randi_range(1, 1000), b.randi_range(1, 1000), "int sequence diverged")
	assert_almost_eq(a.randf(), b.randf(), 0.0000001, "float sequence diverged")
	a.free()
	b.free()


func test_different_seed_diverges() -> void:
	var a: Node = RngScript.new()
	var b: Node = RngScript.new()
	a.set_seed(1)
	b.set_seed(2)
	var identical: bool = true
	for _i in 20:
		if a.randi_range(1, 1000000) != b.randi_range(1, 1000000):
			identical = false
	assert_false(identical, "different seeds produced identical sequences")
	a.free()
	b.free()


func test_randi_range_stays_in_bounds() -> void:
	var rng: Node = RngScript.new()
	rng.set_seed(777)
	for _i in 200:
		var value: int = rng.randi_range(3, 7)
		assert_true(value >= 3 and value <= 7, "randi_range out of bounds: %d" % value)
	rng.free()


func test_chance_zero_never_true() -> void:
	var rng: Node = RngScript.new()
	rng.set_seed(42)
	for _i in 100:
		assert_false(rng.chance(0.0), "chance(0) returned true")
	rng.free()
