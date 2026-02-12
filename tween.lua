local s_format = string.format
local deep_copy = require("deep_copy")
local class_name = require("class_name")
local vararg_concat = require("vararg_concat")
local Logger = require("logger")
local log = Logger.new("Tween")

---@class Tween
---@field private _s_tweeners table<Tweener, boolean> reference store for all the tweeners that hasn't beend stopped
---@field private _s_tweenable_classes table<string, Tweenable>
---@field LoopMode {NONE: 1, FORWARD: 2, BACKWARD: 3}
---@field Easing table<string, TweenEasing>
---@field Direction table<string, TweenDirection>
local M = {
	_s_tweeners = {},
}

---@class Tweener
---@field name string unique identifier
---@field private _generic_key string represents what are we tweening to avoid collisions
---@field private _callback? fun(progress: number): nil update callback
---@field active boolean
---@field private _target? any
---@field private _property? any
---@field private _target_value? any
---@field duration number in seconds
---@field time_left number in seconds
---@field private _custom_callback? TweeningCallback
---@field private _easing_function function
---@field private _parallel_tweener? Tweener
---@field private _chained_tweener? Tweener
---@field private _loop_mode TweenLoopMode
---@field private _loops_amount number|nil how many loops should tweener perform. default is nil (infinite)
---@field private _current_loops_amount? number how many loops left on this tweening
---@field private _s_activity_statuses table<string, boolean> represents active tweenings to avoid collisions
local Tweener = {
	_s_activity_statuses = {}
}
Tweener.mt = {__index = Tweener, __name = "Tweener"}

---@param value boolean
function Tweener:_set_active(value)
	self.active = value
	if self.active then
		Tweener._s_activity_statuses[self._generic_key] = true
	else
		Tweener._s_activity_statuses[self._generic_key] = nil
		M._s_tweeners[self] = nil
	end
end


function Tweener:_generate_keys()
	self._generic_key = vararg_concat("->", self._target, self._property)
	self.name = vararg_concat(": ", self, self._generic_key)
end

---@param target any
---@param property? any if none is specified the target itself is tweeened
---@return Tweener
function Tweener:set_target(target, property)
	if self.active then
		log:warn("Can't set target for a running tween. Stop first")
		return self
	end

	self._target = target
	self._property = property

	self:_generate_keys()

	return self
end

---@param duration number
---@return Tweener
function Tweener:set_duration(duration)
	if self.active then
		log:warn("Can't set duration for a running tween. Stop first")
		return self
	end
	self.duration = duration

	return self
end

---@param target_value any
---@return Tweener
function Tweener:set_target_value(target_value)
	if self.active then
		log:warn("Can't set target value for a running tween. Stop first")
		return self
	end
	self._target_value = target_value

	return self
end

---@alias TweeningCallback fun(tweened_value: any)

--- sets custom callback to be called after tweener update (tick)
--- returns self for builder pattern
---@param value TweeningCallback
---@return Tweener
function Tweener:set_custom_callback(value)
	self._custom_callback = value

	return self
end

--- sets loop mode, determening what happens after the tweener ends. if loop mode is not NONE the tweener won't be gcable
--- returns self for builder pattern
---@param mode TweenLoopMode
---@param loops_amount? number how many times to loop. if nil loops infinitely
---@return Tweener
function Tweener:set_loop_mode(mode, loops_amount)
	if self.active then
		log:warn("Can't set loop mode for a running tween. Stop first")
		return self
	end
	self._loop_mode = mode
	self._loops_amount = loops_amount or nil

	return self
end

---@param easing TweenEasing
---@param direction TweenDirection
---@return function
function Tweener._generate_easing_function(easing, direction)
	return direction(easing)
end

--- sets easing function by combining easing and direction
--- returns self for builder pattern
---@param easing TweenEasing
---@param direction TweenDirection
---@return Tweener
function Tweener:set_easing_function(easing, direction)
	if self.active then
		log:warn("Can't set easing function for a running tween. Stop first")
		return self
	end
	self._easing_function = Tweener._generate_easing_function(easing, direction)

	return self
end

--- makes another tweener execute parallely with this one
--- returns self for builder pattern
---@param value Tweener
function Tweener:parallel(value)
	if not value then
		log:warn(s_format("Trying to add nil parallel tweener to %s)", self.name))
		return self
	end
	local parallel_tweener = self._parallel_tweener
	if parallel_tweener then
		log:warn(s_format("Trying to add parallel tweener %s to %s, which already exists"), value.name, self.name)
		return self
	end

	self._parallel_tweener = value

	return self
end

--- makes another tweener execute after this one
--- returns self for builder pattern
---@param value? Tweener
function Tweener:chain(value)
	if not value then
		log:warn(s_format("Trying to add nil chained tweener to %s)", self.name))
		return value
	end
	local chain_tweener = self._chained_tweener
	if chain_tweener then
		log:warn(s_format("Trying to add chained %s to %s, which already exists"), value.name, self.name)
		return value
	end

	self._chained_tweener = value

	return value
end

---@return string? error
function Tweener:_generate_callback()
	local target = self._target
	local property = self._property
	local target_value = self._target_value
	local custom_callback = self._custom_callback
	local easing_function = self._easing_function
	local tweened_object = property == nil and target or (target and target[property] or nil)
	if not tweened_object then
		return s_format("Can't tween unexisting property %s of %s", tostring(property), tostring(target))
	end
	local tweenable_class = class_name(tweened_object)
	local tweenable = M._s_tweenable_classes[tweenable_class]
	if not tweenable then
		return s_format("Can't tween property %s of %s, unsupported type %s", tostring(property), tostring(target), tweenable_class)
	end
	if tweenable_class ~= class_name(target_value) then
		return s_format("Can't tween property %s of %s, mismatching target and starting types", tostring(property), tostring(target))
	end
	local value_diff = target_value - tweened_object

	local starting_value = deep_copy(tweened_object)
	self._starting_value = starting_value
	local callback
	if custom_callback then
		callback = function(progress)
			local value = tweenable.interpolate(tweened_object, starting_value, value_diff, easing_function, progress)
			log:debug(s_format("Running %s: %s (%s)", self.name, progress, tostring(value)))
			custom_callback(value)
		end
	else
		callback = function(progress)
			local value = tweenable.interpolate(tweened_object, starting_value, value_diff, easing_function, progress)
			log:debug(s_format("Running %s: %s (%s)", self.name, progress, tostring(value)))
			if property then
				target[property] = value
			else
				tweened_object = value
			end
		end
	end
	self._callback = callback
end

--- starts the tweener if there isn't another active tweener for the tweenable value
--- returns self for builder pattern
---@param _force? boolean if true the tweenable won't check collisions and reset loops. for internal usage
---@return Tweener
function Tweener:start(_force)
	log:debug(s_format("Starting %s", self.name))
	local key = self.name
	if Tweener._s_activity_statuses[key] and not _force then
		log:warn(s_format("Can't start %s, property is already being tweened", key))
		return self
	end
	if not (self._target and self.duration and self._target_value) then
		log:warn(s_format("Can't start %s, missing properties", key))
		return self
	end
	local duration = self.duration
	if duration <= 0 then
		log:info("Duration <= 0, nothing to tween")
		return self
	end
	if not _force then
		self._current_loops_amount = 0
	end

	local err = self:_generate_callback()
	if err then
		log:warn(s_format("Couldn't start %s: %s", self.name, err))
		return self
	end
	self:_set_active(true)
	self.time_left = duration

	local parallel_tweener = self._parallel_tweener
	if parallel_tweener then
		log:debug(s_format("%s has parallel %s, starting", self.name, parallel_tweener.name))
		parallel_tweener:start()
	end

	return self
end

--- pauses tween execution until start or stop called
--- returns self for builder pattern
---@return Tweener
function Tweener:pause()
	self:_set_active(false)

	return self
end

--- stops the tweeener if there is no loop mode and removes reference to it
--- returns self for builder pattern
---@param force? boolean if true will stop even if loop mode is not NONE
---@return Tweener
function Tweener:stop(force)
	local starting_value = self._starting_value
	local loops_amount = self._loops_amount
	local current_loops_amount = self._current_loops_amount
	local can_loop = loops_amount
	if loops_amount then
		can_loop = current_loops_amount < loops_amount
	end
	if not force and self._loop_mode ~= M.LoopMode.NONE and can_loop then
		log:debug(s_format("Looping tween %s", self.name))
		self._current_loops_amount = current_loops_amount + 1
		if self._loop_mode == M.LoopMode.FORWARD then
			self._target = starting_value
		else
			self._target = self._target_value
			self._target_value = starting_value
		end
		self:start(true)

		return self
	end
	log:debug(s_format("Stopping %s", self.name))
	self:_set_active(false)
	local chained_tweener = self._chained_tweener
	if chained_tweener then
		log:debug(s_format("%s has chained %s, starting", self.name, chained_tweener.name))
		chained_tweener:start()
	end

	return self
end

---@param dt number
function Tweener:_update(dt)
	if self.active then
		local time_left = self.time_left

		self._callback(1 - time_left / self.duration)
		self.time_left = time_left - dt
		if time_left <= 0 then
			self:stop()
		end
	end
end

---@param target? any
---@param property? any
---@param target_value? any
---@param duration? number
---@return Tweener
function Tweener._new(target, property, target_value, duration)
	local t = setmetatable({
		active = false,
		_target = target,
		_property = property,
		_target_value = target_value,
		duration = duration,
		time_left = 0,
		_loop_mode = M.LoopMode.NONE,
		_loops_amount = nil,
		_easing_function = Tweener._generate_easing_function(M.Easing.LINEAR, M.Direction.IN),
	}, Tweener.mt)

	t:_generate_keys()
	M._s_tweeners[t] = true

	return t
end

---@class TweenEasing : function
M.Easing = {
	LINEAR = function(t)
		return t
	end,

	SQUARE = function(t)
		return t * t
	end,

	CUBIC = function(t)
		return t * t * t
	end,

	QUART = function(t)
		return t * t * t * t
	end,

	QUINT = function(t)
		return t * t * t * t * t
	end,

	SINE = function(t)
		return 1 - math.cos(t * math.pi / 2)
	end,

	EXPO = function(t)
		if t == 0 then return 0 end
		return 2 ^ (10 * (t - 1))
	end,

	CIRC = function(t)
		return 1 - math.sqrt(1 - t * t)
	end,

	BACK = function(t)
		local s = 1.70158
		return t * t * ((s + 1) * t - s)
	end,

	ELASTIC = function(t)
		if t == 0 or t == 1 then return t end
		local p = 0.3
		local s = p / (2 * math.pi) * math.asin(1)
		return -(2 ^ (10 * (t - 1))) * math.sin((t - s) * (2 * math.pi) / p)
	end,

	BOUNCE = function(t)
		if t < 1/2.75 then
			return 7.5625 * t * t
		elseif t < 2/2.75 then
			t = t - 1.5/2.75
			return 7.5625 * t * t + 0.75
		elseif t < 2.5/2.75 then
			t = t - 2.25/2.75
			return 7.5625 * t * t + 0.9375
		else
			t = t - 2.625/2.75
			return 7.5625 * t * t + 0.984375
		end
	end
}

---@class TweenDirection : function
M.Direction = {
	IN = function(f)
		return f
	end,

	OUT = function(f)
		return function(t)
			return 1 - f(1 - t)
		end
	end,

	INOUT = function(f)
		return function(t)
			if t < 0.5 then
				return f(t * 2) / 2
			else
				return (1 - f((1 - t) * 2)) / 2 + 0.5
			end
		end
	end
}

---@class TweenLoopMode : integer
---@type table<string, TweenLoopMode>
M.LoopMode = {
	NONE = 1,
	FORWARD = 2,
	BACKWARD = 3
}

---@alias Tweenable {
	---interpolate: (fun(tweened_object: any, starting_value: any, value_diff: any, easing_function: function, progress: number): any),
	---}
M._s_tweenable_classes = {
	number = {
		interpolate = function(_, starting_value, value_diff, easing_function, progress)
			return starting_value + value_diff * easing_function(progress)
		end
	},
	vec = {
		interpolate = function(tweenable_value, starting_value, value_diff, easing_function, progress)
			-- TODO: Replace this with your implementation. Example:
			-- local size = #tweenable_value
			-- for i = 1, size do
			-- 	tweenable_value[i] = starting_value[i] + value_diff[i] * easing_function(progress)
			-- end
			--
			-- return tweenable_value
		end
	}
}

---@param target any what will we tween
---@param property any target[property]. pass nil for tween to target itself
---@param target_value any what value should property be in the end
---@param duration number in seconds
---@return Tweener?
function M.new_property_tweener(target, property, target_value, duration)
	local result = Tweener._new(target, property, target_value, duration)

	return result
end

---@return Tweener
function M.new_blank_tweener()
	local result = Tweener._new()

	return result
end

---@param dt number
function M._update(dt)
	local tweeners = M._s_tweeners
	for tweener in pairs(tweeners) do
		tweener:_update(dt)
	end
end

-- TODO: Attach to your update here. Example:
-- update:add_callback(M._update)

return M
