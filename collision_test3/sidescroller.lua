--- Side-scroller tests, preparatory to a more ambitious top-down generalization.

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
local sqrt = math.sqrt

-- Modules --
local change_course = require("utils.change_course")
local controller = require("utils.controller")
local segments_data = require("data.segments")
local surface = require("utils.surface")

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Solar2D modules --
local physics = require("physics")

--
--
--

physics.start()
--physics.setDrawMode("debug")

-- Boundary of "player" object --
local PlayerPos = ctnative.Vector2(100, 100)

-- Set up the box graphics.
local R = 15

local Box = display.newCircle(PlayerPos.x, PlayerPos.y, R)

physics.addBody(Box, { friction = 0, bounce = 0, radius = R, isSensor = true })

Box.gravityScale, Box.isFixedRotation = 1.75, true

Box:setFillColor(0, 0)

Box.strokeWidth = 2

local R2 = 9

local Feet = display.newCircle(PlayerPos.x, PlayerPos.y + R - R2, R2)

physics.addBody(Feet, { friction = 1.2, bounce = 0, radius = R2 })

local pivot = physics.newJoint("pivot", Feet, Box, Feet.x, Feet.y)

Feet.isVisible, pivot.maxMotorTorque = false, 1e6
Feet.m_owner = Box

controller.SetConfig(Box, require("data.player_config"))
controller.SetPivot(Box, pivot)

local KinematicSegmentBody = { --[[bounce = 0, ]]friction = 2.7 }
local StaticSegmentBody = { --[[bounce = 0, ]]friction = 2.7 }

local ChangePath = change_course.MakeCollisionListener(2,
	function(seg, phase)
		if phase == "began" and not seg.m_ignore then
			surface.MoveTouchedObjects(seg)
		elseif phase == "ended" then
			seg.m_ignore = nil
		end
	end
)

-- Do some basic setup: add line display objects for the segments and orient the segments in a
-- nice order to make some other operations above easier.
local Segments = segments_data.Init()

for _, sdata in ipairs(Segments) do
	local p1, p2 = sdata.p1, sdata.p2
	local cx, cy = (p1.x + p2.x) / 2, (p1.y + p2.y) / 2
	local dx, dy = p2.x - p1.x, p2.y - p1.y
	local length = sqrt(dx^2 + dy^2)

	local seg = display.newRect(cx, cy, length, 5)

	seg.rotation = math.deg(math.atan2(dy, dx))

	seg:setFillColor(math.random(), math.random(), math.random())

if sdata.move then
	physics.addBody(seg, "kinematic", KinematicSegmentBody, change_course.GetDetectorBody())
else
	physics.addBody(seg, "static", StaticSegmentBody)
end

seg._data = sdata

seg.dx, seg.dy = dx, dy

	-- Add some state for segments that move.
	local move = sdata.move

	if move then
		local p1, p2 = move.pos1 or 0, move.pos2 or 0
		local ap1, ap2, duration, dir = abs(p1), abs(p2), move.t, not not move.dir
		local t, dp_dt = ap1 * duration / (ap1 + ap2), (p2 - p1) / duration
		local motion = ctnative.Vector2(move.dx or 0, move.dy or 0)
		-- ^^ TODO: allow more flexibility, e.g. multi-stage paths, series of platforms that loop (fading out and reappearing at start), etc.
		-- for that matter, triggered (possibly one-shot) states
		-- TODO: curved paths...?

		motion:ScaleToLength(dp_dt)

		seg.m_ignore = t <= 1e-8 -- ignore course change if spawned on a guide object
		seg.m_motion = motion -- TODO: should probably assign a (possibly modified, maybe immutable thereafter) copy of this to each guide object

		change_course.AddObject(seg, -t)
		change_course.AddObject(seg, duration - t)

		if not dir then
			motion:Negate()
		end

		seg:addEventListener("collision", ChangePath)
		seg:setLinearVelocity(motion.x, motion.y)
	end
end

-- Update the character per frame.
local X, CanJump = 0

Runtime:addEventListener("enterFrame", function()
	controller.ApplyMovement(Box, X, CanJump)

	CanJump = false
end)

-- Install some controls.
Runtime:addEventListener("key", function(event)
	local dx = 0

	if event.keyName == "up" then
		if event.phase == "down" then
			CanJump = controller.CanJump(Box)
		end
	elseif event.keyName == "left" then
		dx = -1
	elseif event.keyName == "right" then
		dx = 1
	else
		return
	end

	if event.phase == "up" then
		dx = -dx
	end

	X = X + dx
end)

Feet:addEventListener("preCollision", function(event)
	local seg = event.other

	if surface.IsPassThroughSurface(seg) then
		if surface.ObjectHeightSquared(seg, event.target--[[.m_owner]]) <= 0 then
			event.contact.isEnabled = false
		end
	end
end)

Feet:addEventListener("collision", function(event)
	local seg = event.other

	if surface.IsSurface(seg) then
		local pos = event.target.m_owner

		if event.phase == "began" then
			event.contact.bounce = 0

			if surface.ObjectHeightSquared(seg, pos) < 0 then -- todo : meant for walls, ceilings, etc.
				event.contact.friction = .2
			elseif surface.AddToFloor(seg, pos) then
				controller.TouchFloor(pos)
			end
		elseif event.phase == "ended" then
			if surface.RemoveFromFloor(seg, pos) then
				controller.StopTouchingFloor(pos)
			end
		end
	end
end)