local Tween = require("illarn.tween")
local Logger = require("illarn.logger")
local log = Logger.new("Tween Testing")

local running = true
local FPS = 60

local stop_on_fail = false
local function test_assert(test, condition)
	if not condition then
		log:error("Test failed", test.name)
		assert(not stop_on_fail)
		test.result = false
		return
	end
	test.result = true
end

Tween.logger.level = Logger.LogLevel.VERBOSE
local case_id = 1
local tests = {
	time_acc = {
		name = "Time Accuracy",
		case = function(self)
			FPS = 1000
			local value = {x = 0}
			local begin_time = os.clock()
			local run_time = 1
			Tween.new_property_tweener(value, "x", 1, run_time):start():on_finish(function()
				running = false
				test_assert(self, math.abs(os.clock() - begin_time - run_time) < 0.1)
			end)
			FPS = 60
		end,
		result = false,
		runned = false
	},
	value_acc = {
		name = "Result Value Accuracy",
		case = function(self)
			FPS = 10
			local value = {x = 0}
			local expected_value = 1
			Tween.new_property_tweener(value, "x", 1, 1):start():on_finish(function()
				running = false
				test_assert(self, math.abs(expected_value - value.x) < 0.001)
			end)
			FPS = 60
		end,
		result = false,
		runned = false
	},
	chain = {
		name = "Chained Tweening",
		case = function(self)
			local value = {x = 0, y = 0}
			local begin_time = os.clock()
			local run_time = 2
			Tween.new_property_tweener(value, "x", 1, run_time/2)
				:chain(Tween.new_property_tweener(value, "y", 1, run_time/2)
					:on_finish(function()
						running = false
						test_assert(self, (math.abs(os.clock() - begin_time - run_time) < 0.1) and (math.abs(1 - value.y) < 0.001))
					end))
				:start()
			end,
		result = false,
		runned = false
	},
	parallel = {
		name = "Parallel Tweening",
		case = function(self)
			local value = {x = 0, y = 0}
			local begin_time = os.clock()
			local run_time = 1
			Tween.new_property_tweener(value, "x", 1, run_time)
				:parallel(Tween.new_property_tweener(value, "y", 1, run_time)
					:on_finish(function()
						running = false
						print(os.clock() - begin_time - run_time)
						test_assert(self, (math.abs(os.clock() - begin_time - run_time) < 0.1) and (math.abs(1 - value.y) < 0.001))
					end))
				:start()
			end,
		result = false,
		runned = false
	},
	collision = {
		name = "Collision Avoidance",
		case = function(self)
			local value = {x = 0}
			local result = true
			Tween.new_property_tweener(value, "x", 1, 1)
				:on_finish(function ()
					running = false
					test_assert(self, result)
				end)
				:start()
			Tween.new_property_tweener(value, "x", 1, 1)
				:set_custom_callback(function()
					result = false
				end)
				:start()
			end,
		result = false,
		runned = false
	},
	loop = {
		name = "Tween Looping",
		case = function(self)
			local value = {x = 0, y = 0}
			local counter1 = 0
			local counter2 = 0
			local result = true
			Tween.new_property_tweener(value, "x", 1, 1)
				:set_loop_mode(Tween.LoopMode.FORWARD, 3)
				:on_loop(function ()
					counter1 = counter1 + 1
				end)
				:on_finish(function ()
					result = counter1 == 3 and math.abs(value.x - 1) < 0.001
					test_assert(self, result)
					running = false
				end)
				:start()
			Tween.new_property_tweener(value, "y", 1, 1)
				:set_loop_mode(Tween.LoopMode.BACKWARD, 3)
				:on_loop(function ()
					counter2 = counter2 + 1
				end)
				:on_finish(function ()
					result = counter2 == 3 and math.abs(value.y) < 0.001
					test_assert(self, result)
					running = false
				end)
				:start()
			end,
		result = false,
		runned = false
	}
}

local function _update(delta)
	Tween._update(delta)
end

local tests_to_run = {
	tests.time_acc,
	tests.value_acc,
	tests.chain,
	tests.parallel,
	tests.collision,
	tests.loop
}

local function next_test()
	local test = tests_to_run[case_id]
	if not test then
		log:info("Testing ended")
		for _, v in pairs(tests) do
			if not v.runned then
				log:info("⚫", v.name, "didn't run ")
			else
				log:info(v.result and "✅" or "❌", v.name, v.result and "passed" or "failed")
			end
		end
		return
	end
	running = true
	log:info("Starting test", test.name)
	test.case(test)
	case_id = case_id + 1
	test.runned = true
	update_loop()
end

function update_loop()
	while running do
		local start = os.clock()
		while os.clock() <= (start + 1/FPS) do end
		local dt = os.clock() - start
		_update(dt)
	end
	next_test()
end

log:info("Testing starting")
next_test()
