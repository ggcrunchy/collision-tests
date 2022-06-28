--- Character controller logic.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local abs = math.abs
--local min = math.min
local pairs = pairs
local sqrt = math.sqrt

-- Modules --
local segments = require("data.segments")

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Cached module references --
local _CanJump_

-- Unique member keys --
local _config = {}
local _pivot = {}
local _touch_count = {}

-- Exports --
local M = {}

--
--
--

local function GetConfig (player)
    return player[_config]
end

--
function M.ApplyMovement (player, dx, wants_to_jump)
    local config, vx, vy = GetConfig(player), player:getLinearVelocity()

	-- Execute a jump, if one was attempted. This is done after moving platforms since any
	-- logic of theirs that puts us on the floor would abort the jump impulse.
	if wants_to_jump then
        player:setLinearVelocity(vx, 0) -- TODO: this also picks up any motion from the platform...
		player:applyForce--[[LinearImpulse]](0, config.jump_impulse, player.x, player.y)
	end

	local pivot, enable_motor = player[_pivot], false

    if _CanJump_(player) then
        dx = dx * config.walk_speed

		local speed = sqrt(vx^2 + vy^2)
       	local vnew = abs(dx)--abs(speed - dx)
-- TODO: angular -> linear, i.e. 2 * pi * r...
        if vnew <= config.max_walk_speed or vnew < speed then
            pivot.motorSpeed, enable_motor = -dx, true
        end
    else
        dx = dx * config.air_speed

       	local vnew = abs(vx + dx)

        if vnew <= config.max_air_speed or vnew < abs(vx) then
        	player:applyForce--[[LinearImpulse]](dx, 0, player.x, player.y)
        end
    end

    pivot.isMotorEnabled = enable_motor
end

--
function M.CanJump (player)
    return player[_touch_count] ~= 0
end

--
function M.SetConfig (player, config)
    player[_config] = config
end

--
function M.SetPivot (player, pivot)
	player[_pivot] = pivot
end

--
function M.StopTouchingFloor (player)
    local count = player[_touch_count] - 1

	player[_touch_count] = count

    if count == 0 then
        player.gravityScale = GetConfig(player).falling_gravity_scale
    end
end

--
function M.TouchFloor (player)
    player[_touch_count] = (player[_touch_count] or 0) + 1

	player.gravityScale = 1
end

_CanJump_ = M.CanJump

return M