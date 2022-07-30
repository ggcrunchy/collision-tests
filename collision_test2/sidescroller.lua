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
local max = math.max
local min = math.min

-- Modules --
local contacts = require("utils.contacts")
local movement = require("utils.movement")
local platforms = require("utils.platforms")
local region = require("utils.region")
local segment_data = require("utils.segment_data")
local update = require("utils.update")

-- Plugins --
local ctnative = require("plugin.ctnative")

--
--
--

local MovingPlatforms = {}

--
--
--

-- Do some basic setup: add line display objects for the segments and orient the segments in a
-- nice order to make some other operations above easier.
local Segments = segment_data.Init()

for _, sdata in ipairs(Segments) do
	local p1, p2 = sdata.p1, sdata.p2
	local seg = display.newLine(p1.x, p1.y, p2.x, p2.y)

	seg:setStrokeColor(math.random(), math.random(), math.random())

	seg.strokeWidth = 3

	-- Add some state for segments that move.
	local move = sdata.move

	if move then
    MovingPlatforms[#MovingPlatforms + 1] = platforms.MakeMoving(seg, sdata, move)
	end
end

--
--
--

local PlayerPos = ctnative.Vector2(100, 100)

-- Set up the box graphics.
local R = 15

local Box = display.newCircle(PlayerPos.x, PlayerPos.y, R)

Box:setFillColor(0, 0)

Box.strokeWidth = 2

--
--
--

local FloorSegment = false

local function DoMovingParts (delta)
	-- Update moving blocks. We might be on a moving floor, so accumulate any motion and let
	-- the normal movement logic handle anything that results. This logic presumes multiple
	-- simultaneous collisions will be rare, so imposes no specific order among the platforms
	-- and allots each one the full time slice.
	local old_iters, old_too_low = update.SetIterationCount(10), update.SetLowSpeedSquared(1e-6)

	for i = 1, #MovingPlatforms do
		MovingPlatforms[i](Segments, PlayerPos, R, FloorSegment, delta)
	end

	update.SetIterationCount(old_iters)
	update.SetLowSpeedSquared(old_too_low)
end

--
--
--

local HorzVelocity = ctnative.Vector2()
local VertVelocity = ctnative.Vector2()

local Delta = ctnative.Vector2()

local SegmentList = {}

local function DoStaticParts (dx, dy, delta)
	-- Find the list of segments we might possibly hit.
	Delta:SetScaledXY(dx, dy, delta)

	local nsolid, ntotal = region.Gather(SegmentList, PlayerPos, R, Delta, Segments)

	-- Perform updates along each component of motion.
	HorzVelocity:SetZero()

	if 1 + Delta.x^2 ~= 1 then
		movement.Horizontal(PlayerPos, R, SegmentList, Delta.x, nsolid, ntotal, FloorSegment, nil, HorzVelocity)
	end

	return movement.Vertical(PlayerPos, R, SegmentList, Delta.y, nsolid, ntotal, VertVelocity)
end

--
--
--

local V = 0

local WaitTime = 0

local function Hop (amount)
	FloorSegment, V, WaitTime = false, amount, 0
end

--
--
--

local ContactPos, Foot = ctnative.Vector2(), ctnative.Vector2()

local Up = ctnative.Vector2()

local function ProcessHit (hit, delta)
  contacts.GetFoot(Foot)
  contacts.GetPosition(ContactPos)

  Up:SetDifference(ContactPos, Foot)

  if update.GoingUp(Up) then -- is this possibly a floor?
    V, FloorSegment = 0, hit
  else
    V = -update.GetUpComponent(VertVelocity) / delta -- velocity component going "down"
  end
end

--
--
--

local G = 875

local Damping = .975

local function UpdateVelocity (delta)
	-- If we are forgiving a walk off an edge, simply decrement the counter. Otherwise, apply
	-- damping and gravity to the vertical speed.
  -- TODO: (when used) this should only really affect gravity...
	WaitTime = max(WaitTime - delta, 0)

	delta = delta - WaitTime

	if delta > 0 then
		V = V * (1 - Damping * delta)
		V = V + G * delta
	end

  return delta
end

--
--
--

local Jumped

local X = 0

local JumpImpulse = -590

local VelocityModifier = 0

--
--
--

local function Update (delta)
  delta = UpdateVelocity(delta)

  DoMovingParts(delta)

	-- Execute a jump, if one was attempted. This is done after moving platforms since any
	-- logic of theirs that puts us on the floor would abort the jump impulse.
	if Jumped then
		Hop(JumpImpulse)

		Jumped = false
	end

  local hit, did_advance = DoStaticParts(VelocityModifier + X, V, delta)

	if did_advance then
		FloorSegment = false
-- TODO: if WaitTime still matters, would probably involve a check like "if FloorSegment and not hit then"...
-- however, the "player" being a circle actually seems to effect the behavior well enough (at the cost of more slipping)
		if hit then
      ProcessHit(hit, delta)
		end
	end

	-- Usually we damp the movement completely, but some surfaces have their own effect.
	VelocityModifier = movement.ModifyVelocity(HorzVelocity, VelocityModifier, FloorSegment, delta)

	-- Update the box graphic.
	PlayerPos:AssignTo(Box)
end

--
--
--

local Accum = 0

local MaxDelta = 1 / 30

local Step = 1 / 50

local Prev

Runtime:addEventListener("enterFrame", function(event)
  local now = event.time

  if Prev then
    Accum = Accum + min((now - Prev) / 1000, MaxDelta)
  end

	Prev = now

  while Accum > Step do
    Update(Step)

    Accum = Accum - Step
  end
end)

--
--
--

local WalkSpeed = 200

local Keys = { up = true, left = true, right = true }

local IsDown = {} -- avoid repeats on Mac

Runtime:addEventListener("key", function(event)
  if not Keys[event.keyName] then
    return false
  end

  local is_down = event.phase == "down"
  
  if is_down and IsDown[event.keyName] then
    return true
  end

	local dx = 0

	if event.keyName == "left" then
		dx = -WalkSpeed
	elseif event.keyName == "right" then
		dx = WalkSpeed
	end

	if not is_down then
		dx = -dx
  elseif event.keyName == "up" and (FloorSegment or WaitTime > 0) then
    Jumped = true
	end

	X, IsDown[event.keyName] = X + dx, is_down

  return true
end)