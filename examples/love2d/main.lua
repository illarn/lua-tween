local Tween = require("illarn.tween")

local pos_sine = {x = 100, y = 100}
local pos_bounce = {x = 100, y =100}
local pos_back = {x = 100, y = 100}
local pos_elastic = {x = 100, y = 100}
local target_y = 300
local duration = 2.0

-- Simple Animations
Tween.new_property_tweener(pos_sine, "y", target_y, duration)
	:set_easing_function(Tween.Easing.SINE, Tween.Direction.OUT)
	:set_loop_mode(Tween.LoopMode.BACKWARD)
	:parallel(Tween.new_property_tweener(pos_bounce, "y", target_y, duration)
		:set_easing_function(Tween.Easing.BOUNCE, Tween.Direction.IN)
		:set_loop_mode(Tween.LoopMode.BACKWARD)
		:parallel(Tween.new_property_tweener(pos_back, "y", target_y, duration)
			:set_easing_function(Tween.Easing.BACK, Tween.Direction.INOUT)
			:set_loop_mode(Tween.LoopMode.BACKWARD)
			:parallel(Tween.new_property_tweener(pos_elastic, "y", target_y, duration)
				:set_easing_function(Tween.Easing.ELASTIC, Tween.Direction.IN)
				:set_loop_mode(Tween.LoopMode.BACKWARD)
			)
		)
	):start()

local size_complex = 0
local size_complex_target = 10
local pos_complex = {x = 100, y = 500}
local target_complex = {x = 700, y = 400}

-- Complex Animation
Tween.wait(2.8):parallel(
	Tween.new_property_tweener(size_complex, nil, size_complex_target, 0.2)
	:set_custom_callback(function(tweened_value)
			size_complex = tweened_value
		end)
		:chain(Tween.wait(0.3)
			:chain(Tween.new_property_tweener(pos_complex, "x", target_complex.x, 1.2)
				:set_easing_function(Tween.Easing.CUBIC, Tween.Direction.OUT)
				:parallel(Tween.new_property_tweener(pos_complex, "y", target_complex.y, 0.5)
					:set_easing_function(Tween.Easing.CIRC, Tween.Direction.OUT)
					:chain(Tween.new_property_tweener(pos_complex, "y", pos_complex.y, 0.5)
						:set_easing_function(Tween.Easing.BOUNCE, Tween.Direction.IN)
					)
				)
				:chain(Tween.new_property_tweener(size_complex_target, nil, size_complex, 0.2)
					:set_custom_callback(function(tweened_value)
						size_complex = tweened_value
					end)
				)
			)
		)
	)
	:on_finish(function (self)
		-- Restart all the parallels on finish (deep loop)
		self:stop(true)
		self:start()
	end)
	:start()

function love.update(dt)
	Tween._update(dt)
end

function love.draw()
	love.graphics.print("Sine", 50, 10)
	love.graphics.circle("fill", 80, pos_sine.y, 10)
	love.graphics.print("Bounce", 250, 10)
	love.graphics.circle("fill", 280, pos_bounce.y, 10)
	love.graphics.print("Back", 450, 10)
	love.graphics.circle("fill", 480, pos_back.y, 10)
	love.graphics.print("Elastic", 650, 10)
	love.graphics.circle("fill", 680, pos_elastic.y, 10)

	love.graphics.print("Complex Animation", 50, 400)
	love.graphics.circle("fill", pos_complex.x, pos_complex.y, size_complex)
end
