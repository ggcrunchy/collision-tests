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
local max = math.max
local min = math.min
local sqrt = math.sqrt

-- Modules --
local segment_data = require("utils.segment_data")
local segment_list = require("utils.segment_list")
local update = require("utils.update")

-- Plugins --
local ctnative = require("plugin.ctnative")

--
--
--

-- Boundary of "player" object --
local PlayerPos = ctnative.Vector2(100, 100)

-- Left- or right-movement speed, e.g. for walking --
local WalkSpeed = 200

-- Vertical impulse applied to jump --
local JumpImpulse = -590

-- Gravity --
local G = 875

-- Damping applied to vertical speed --
local Damping = .975

-- Set up the box graphics.
local R = 15

local Box = display.newCircle(PlayerPos.x, PlayerPos.y, R)

Box:setFillColor(0, 0)

Box.strokeWidth = 2

-- Floor segment, if available; else false --
local OnFloor = false

-- Vertical speed --
local V = 0

-- How many frames are left to forgive walking off edge --
local WaitTime = 0

-- Collection of nearby segments --
local SegmentList = {}

-- Apply a vertical impulse to perform a hop
local function Hop (amount)
	OnFloor, V, WaitTime = false, amount, 0
end

-- Segments that make up the platform currently being stepped --
local Platform = {}

local AuxHorz, AuxVert

do
	local Edge = ctnative.Vector2()
	local OldPos, OldRight = ctnative.Vector2(), ctnative.Vector2()
	local Right = ctnative.Vector2()
	local Velocity = ctnative.Vector2()

	function AuxHorz (pos, radius, segments, dx, nsolid, ntotal, fseg, push, hvel)
		update.GetRight(OldRight)
		Right:Set(OldRight)
		
		local check_hit

		if push and ntotal == 1 then
			fseg = segments[1]
		end

		if fseg then -- follow floor direction
			Edge:SetDifference(fseg.p2, fseg.p1)

			if not Right:IsAlmostOrthogonalTo(Edge) then
				local sense = Right:DotProduct(Edge)

				Right:SetNormalized(Edge)

				if sense < 0 then
					Right:Negate()
				end

				check_hit = true

				if push then
					dx = dx / abs(Right.x) -- want to go X units along axis, not across the floor
				end
			end
		end

		local vel = hvel or Velocity

		vel:SetScaled(Right, dx)
		OldPos:Set(pos)

		local hit = update.Advance(pos, radius, segments, vel, nsolid, ntotal, push)

		if hit and check_hit and hit ~= fseg then 	-- we ran into something, so try the floor-unaware version;
													-- the "jump" that tends to happen is actually better here
													-- TODO: could check if the segments are attached, if necessary
			pos:Set(OldPos)
			vel:SetScaled(OldRight, dx)

			update.Advance(pos, radius, segments, vel, nsolid, ntotal, push)
		end
	end

	function AuxVert (pos, radius, segments, dy, nsolid, ntotal, vvel)
		local vel = vvel or Velocity

		update.GetUp(vel)
		vel:ScaleBy(-dy)

		return update.Advance(pos, radius, segments, vel, nsolid, ntotal, "friction")
	end
end

-- Currently active moving platforms --
local MovingPlatforms = {}

-- --
local PlatformSegmentList = {}

-- --
local DepenetrationScale = .00325 -- TODO: .00125 seemed to be enough for push, but needs to be at least nearly this high for slopes...
-- ^^^^ maybe we could just back up a full radius plus some epsilon, augmenting the velocity likewise?

-- --
local TooManySteps = 10 -- TODO?: ...and this to climb the slope

-- --
local TooLittleMovementSquared = .0625

local OldPos = ctnative.Vector2()

local Displacement = ctnative.Vector2()

local NudgedPos, PosDelta, PosDest = ctnative.Vector2(), ctnative.Vector2(), ctnative.Vector2()
local NudgedDisplacement = ctnative.Vector2()
local DepenetrationNudge = ctnative.Vector2()

local ToGo = ctnative.Vector2()

local UpDelta = ctnative.Vector2()

local MotionDelta = ctnative.Vector2()

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
		local p1, p2 = move.pos1 or 0, move.pos2 or 0
		local ap1, ap2, duration, dir = abs(p1), abs(p2), move.t, not not move.dir
		local t, dp_dt = ap1 * duration / (ap1 + ap2), (p2 - p1) / duration
		local motion = ctnative.Vector2(move.dx or 0, move.dy or 0)

		motion:Normalize()

		MovingPlatforms[#MovingPlatforms + 1] = function(pos, radius, fseg, dt, total)
			-- Step the platform along its path.
			local now = t + (dir and dt or -dt)

			if now <= 0 or now >= duration then
				now, dir = max(0, min(now, duration)), not dir  -- n.b. throwing away fragments of time, so inadequate for
																-- anything that needs accurate timing; could use mod?
																-- A challenge with doing it the right way is that the platform
																-- might turn around, complicating the possible interactions
			end

			Displacement:SetScaled(motion, (now - t) * dp_dt)

			if sdata == fseg then -- we are on this segment: let its motion carry us along
				MotionDelta:Set(Displacement)
			else
				MotionDelta:SetZero()
			end

			-- Update the platform visually.
			-- TODO: allow more segments, e.g. for compound shapes (or rather, use a better object than a line)
			seg.x, seg.y = seg.x + Displacement.x, seg.y + Displacement.y

			-- Gather any segments near our platform.
			-- TODO: ditto
			Platform[1] = sdata

			DepenetrationNudge:SetScaled(Displacement, DepenetrationScale)
			NudgedDisplacement:SetSum(Displacement, DepenetrationNudge)

			local nsolid, ntotal = segment_list.Gather(PlatformSegmentList, pos, radius, NudgedDisplacement, Platform)

			NudgedDisplacement:Negate()

			-- Handle any interactions that result from their movement.
			local n = update.GoingUp(NudgedDisplacement) and nsolid or ntotal
local aa
			if n > 0 and not Displacement:IsAlmostZero() then
				NudgedPos:SetSum(pos, DepenetrationNudge)

				local hit = segment_list.CheckMovingCircleHits(PlatformSegmentList, n, NudgedPos, radius, NudgedDisplacement)

				if hit or fseg == sdata then
					if hit then -- pushed by platform
						segment_list.GetContactPosition(PosDest) -- the object might be hit immediately, at the nudged position, making it
																 -- subject to the platform's full displacement; otherwise, some distance
																 -- must be covered and we only apply what remains

						PosDest:Add(Displacement)
						PosDelta:SetDifference(PosDest, NudgedPos)
					else -- on floor
						PosDelta:Set(Displacement)

						PosDest:Set(pos)
						PosDest:AddXY(PosDelta.x, 0)
					end

					if hit ~= fseg then -- was this segment the floor? if not, throw away any motion we assumed
										-- TODO: pushed by moving wall while on moving platform...
						MotionDelta:SetZero()
					end

					if 1 + PosDelta.x^2 ~= 1 then
						local xdest, moved = PosDest.x, true -- TODO: assumes x is horizontal...

						for _ = 1, TooManySteps do -- catch-all
							if moved then
								ToGo.x = xdest - pos.x
							else -- "stuck", so see if aiming further will do any good, e.g. pushing us over a step
								ToGo:ScaleBy(2)
aa=true
							end

							OldPos:Set(pos)

							nsolid, ntotal = segment_list.Gather(SegmentList, pos, radius, ToGo, Segments)

							AuxHorz(pos, radius, SegmentList, ToGo.x, nsolid, ntotal, fseg, true)

							if 1 + (xdest - pos.x)^2 == 1 then -- TODO?: check whether at least past xdest along forward, to handle overshot?
								break
							else
								OldPos:Sub(pos)

								moved = OldPos:LengthSquared() > TooLittleMovementSquared -- not just shifting direction?
							end

							-- if stuck
								-- handle obstruction:
									-- break it... (remove from list and continue)
									-- ...or take damage and add it to ignore list for a while...
									-- ...or get squished! (cancel loop)
									-- etc.
						end
if aa then
--	print("N",step)
end
					end

					if 1 + PosDelta.y^2 ~= 1 then
						UpDelta.y = PosDelta.y + DepenetrationNudge.y
						nsolid, ntotal = segment_list.Gather(SegmentList, pos, radius, UpDelta, Segments)

						AuxVert(pos, radius, SegmentList, UpDelta.y, nsolid, ntotal)
						-- TODO: ditto from horizontal, mutatis mutandis
					end
				end
			end

			-- Update the data itself, along with the time step. Report any floor motion.
			sdata.p1:Add(Displacement)
			sdata.p2:Add(Displacement)
			total:Add(MotionDelta)

			t = now
		end
	end
end

-- Update the character per frame.
local X, Prev = 0

local TooQuickSquared = 80 -- this (and the damping) could probably be properties of different built-in ice types

local ModifyVelocity

do
	local Right = ctnative.Vector2()

	function ModifyVelocity (velocity, cur, seg, delta)
		if seg then
			local stype = seg.type

			if stype == "conveyer" then -- probation, but seems fine
				return seg.momentum
			elseif stype == "ice" then -- WIP!
				if 1 + delta^2 ~= 1 then
					update.GetRight(Right)

					local vlen_sq = min(velocity:LengthSquared(), TooQuickSquared)
					local damped = seg.damping * sqrt(vlen_sq)
					local dir_damped = velocity:DotProduct(Right) > 0 and damped or -damped -- "right" or "left"?

					return dir_damped / delta
				else
					return cur
				end
      elseif stype == "sticky" then -- TODO
        return cur
			end
		end

		return 0
	end
end

-- Did we try to jump? --
local Jumped

local VelocityModifier = 0

local HorzVelocity = ctnative.Vector2()
local VertVelocity = ctnative.Vector2()

local ContactPos, Foot = ctnative.Vector2(), ctnative.Vector2()

local Up2 = ctnative.Vector2()

local Delta = ctnative.Vector2()

local MotionFromPlatforms = ctnative.Vector2()

Runtime:addEventListener("enterFrame", function(event)
	-- Get the time elapsed since the last frame.
	Prev = Prev or event.time

	local delta = (event.time - Prev) / 1000

	Prev = event.time

	-- Update moving blocks. We might be on a moving floor, so accumulate any motion and let
	-- the normal movement logic handle anything that results. This logic presumes multiple
	-- simultaneous collisions will be rare, so imposes no specific order among the platforms
	-- and allots each one the full time slice.
	local old_iters, old_too_low = update.SetIterationCount(10), update.SetLowSpeedSquared(1e-6)

	MotionFromPlatforms:SetZero()

	for i = 1, #MovingPlatforms do
		MovingPlatforms[i](PlayerPos, R, OnFloor, delta, MotionFromPlatforms)
	end

	update.SetIterationCount(old_iters)
	update.SetLowSpeedSquared(old_too_low)

	-- Execute a jump, if one was attempted. This is done after moving platforms since any
	-- logic of theirs that puts us on the floor would abort the jump impulse.
	if Jumped then
		Hop(JumpImpulse)

		Jumped = false
	end

	-- Find the list of segments we might possibly hit.
	Delta:Set(MotionFromPlatforms)
	Delta:AddScaledXY(VelocityModifier + X, V, delta)

	local nsolid, ntotal = segment_list.Gather(SegmentList, PlayerPos, R, Delta, Segments)

	-- Perform updates along each component of motion.
	HorzVelocity:SetZero()

	if 1 + Delta.x^2 ~= 1 then
		AuxHorz(PlayerPos, R, SegmentList, Delta.x, nsolid, ntotal, OnFloor, nil, HorzVelocity)
	end

	local hit, did_advance = AuxVert(PlayerPos, R, SegmentList, Delta.y, nsolid, ntotal, VertVelocity)
  
	update.SetLowSpeedSquared(old_too_low)

-- TODO: if WaitTime still matters, would probably involve a check like "if OnFloor and not hit then"...
-- however, the "player" being a circle actually seems to effect the behavior well enough (at the cost of more slipping)
	if did_advance then
		OnFloor = nil

		if hit then
			segment_list.GetContactFoot(Foot)
			segment_list.GetContactPosition(ContactPos)

			Up2:SetDifference(ContactPos, Foot)

			if update.GoingUp(Up2) then -- is this possibly a floor?
				-- ^^^ TODO: omit steep / vertical walls (dot product, e.g. as somewhere above)
--[=[
-- FROM EARLIER CODE:
-- Squared steep angle cosine --
local CosAngleSq = math.cos(math.rad(75))^2

-- Avoid too-steep slopes being used as attachments
local function IsLowEnough (seg)
	local dxsq = (seg.x2 - seg.x1)^2
	local casq = dxsq / (dxsq + (seg.y2 - seg.y1)^2)

	return casq > CosAngleSq
end
]=]
				V, OnFloor = 0, hit
			else
        V = -update.GetUpComponent(VertVelocity) / delta -- velocity component going "down"
      end
		end
	end

	-- If we are forgiving a walk off an edge, simply decrement the counter. Otherwise, apply
	-- damping and gravity to the vertical speed.
	WaitTime = max(WaitTime - delta, 0)

	delta = delta - WaitTime

	if delta > 0 then
		V = V * (1 - Damping * delta)
		V = V + G * delta
	end

	-- Usually we damp the movement completely, but some surfaces have their own effect.
	VelocityModifier = ModifyVelocity(HorzVelocity, VelocityModifier, OnFloor, delta)

	-- Update the box graphic.
	PlayerPos:AssignTo(Box)
end)

-- Install some controls.
Runtime:addEventListener("key", function(event)
	local dx = 0

	if event.keyName == "up" then
		if (OnFloor or WaitTime > 0) and event.phase == "down" then
			Jumped = true
		end
	elseif event.keyName == "left" then
		dx = -WalkSpeed
	elseif event.keyName == "right" then
		dx = WalkSpeed
	else
		return
	end

	if event.phase == "up" then
		dx = -dx
	end

	X = X + dx
end)