# Tween for Lua/LuaJIT

Tweening library that provides property interpolation with easing, parallel/sequential chaining and loop support

## [Demonstration](examples/love2d/main.lua)
```bash
love examples/love2d
```
<video src="https://github.com/user-attachments/assets/fee718c6-baf3-4cc9-9f96-58a4636154f5" width="800" height="600" width="100%" controls></video>

## Installation
[Luarocks](https://luarocks.org/modules/illarn/illarn-tween)
```
luarocks install illarn-tween
```

## Setup

```lua
local tween = require("illarn.tween")

-- Before using the library you have to attach its update callback. Example:
update:add_callback(tween._update)
-- Or
function update(dt)
  tween._update(dt)
end

-- To support custom classes add them to the _s_tweenable_classes. Example:
table.insert(tween.s_tweenable_classes, {
  vec = {
    interpolate = function(tweenable_value, starting_value, value_diff, easing_function, progress)
      tweenable_value.x = starting_value.x + value_diff.x * easing_function(progress)
      tweenable_value.y = starting_value.y + value_diff.y * easing_function(progress)
      tweenable_value.z = starting_value.z + value_diff.z * easing_function(progress)
      tweenable_value.w = starting_value.w + value_diff.w * easing_function(progress)

      return tweenable_value
    end
  }
})
```

## Usage

```lua
local Tween = require("illarn.tween")

-- Basic property tween
local my_tweener = tween.new_property_tweener(obj, "x", 100, 2.0)
    :set_easing_function(tween.Easing.SINE, tween.Direction.OUT)
    :start()


-- Blank tweener with custom callback
local custom = tween.new_blank_tweener()
    :set_target(obj, "y")
    :set_target_value(250)
    :set_duration(1.5)
    :set_custom_callback(function(value)
        print("Tweened value:", value)
    end)
    :start()

-- Chaining and parallel execution
local first = tween.new_property_tweener(obj, "alpha", 0, 1.0)
local second = tween.new_property_tweener(obj, "scale", 2.0, 0.5)
local third = tween.new_property_tweener(obj, "rotation", 180, 1.0)

first:parallel(second)  -- Run simultaneously
first:chain(third)      -- Run after first completes
first:start()

-- Looping
local looped = tween.new_property_tweener(obj, "x", 500, 1.0)
    :set_loop_mode(tween.LoopMode.FORWARD, 3)  -- Loop 3 times
    :start()

-- Control
my_tweener:pause()
my_tweener:stop()
```

## Easing Functions
`LINEAR`, `SQUARE`, `CUBIC`, `QUART`, `QUINT`, `SINE`, `EXPO`, `CIRC`, `BACK`, `ELASTIC`, `BOUNCE`

## Directions
`IN`, `OUT`, `INOUT`

## Loop Modes
`NONE`, `FORWARD`, `BACKWARD`
