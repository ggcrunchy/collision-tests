--- Moving platform logic.

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

-- Modules --
local contacts = require("utils.contacts")
local movement = require("utils.movement")
local region = require("utils.region")
local update = require("utils.update")

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Exports --
local M = {}

--
--
--

local PlatformSegmentList = {}

local DepenetrationScale = .00325 -- TODO: .00125 seemed to be enough for push, but needs to be at least nearly this high for slopes...
-- ^^^^ maybe we could just back up a full radius plus some epsilon, augmenting the velocity likewise?

local TooManySteps = 10 -- TODO?: ...and this to climb the slope

local TooLittleMovementSquared = .0625

local OldPos = ctnative.Vector2()

local Displacement = ctnative.Vector2()

local NudgedPos, PosDelta, PosDest = ctnative.Vector2(), ctnative.Vector2(), ctnative.Vector2()
local NudgedDisplacement = ctnative.Vector2()
local DepenetrationNudge = ctnative.Vector2()

local ToGo = ctnative.Vector2()

local UpDelta = ctnative.Vector2()

local MotionDelta = ctnative.Vector2()

-- Segments that make up the platform currently being stepped --
local Platform = {}

local SegmentList = {}

--
--
--

--- DOCME
function M.MakeMoving (seg, sdata, params)
		local p1, p2 = params.pos1 or 0, params.pos2 or 0
		local ap1, ap2, duration, dir = abs(p1), abs(p2), params.t, not not params.dir
		local t, dp_dt = ap1 * duration / (ap1 + ap2), (p2 - p1) / duration
		local motion = ctnative.Vector2(params.dx or 0, params.dy or 0)

		motion:Normalize()

		return function(segments, pos, radius, fseg, dt, total)
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

			local nsolid, ntotal = region.Gather(PlatformSegmentList, pos, radius, NudgedDisplacement, Platform)

			NudgedDisplacement:Negate()

			-- Handle any interactions that result from their movement.
			local n = update.GoingUp(NudgedDisplacement) and nsolid or ntotal

			if n > 0 and not Displacement:IsAlmostZero() then
				NudgedPos:SetSum(pos, DepenetrationNudge)

				local hit = contacts.CheckMovingCircles(PlatformSegmentList, n, NudgedPos, radius, NudgedDisplacement)

				if hit or fseg == sdata then
					if hit then -- pushed by platform
						contacts.GetPosition(PosDest) -- the object might be hit immediately, at the nudged position, making it
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
							end

							OldPos:Set(pos)

							nsolid, ntotal = region.Gather(SegmentList, pos, radius, ToGo, segments)

							movement.Horizontal(pos, radius, SegmentList, ToGo.x, nsolid, ntotal, fseg, "rescale")

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
					end

					if 1 + PosDelta.y^2 ~= 1 then
						UpDelta.y = PosDelta.y + DepenetrationNudge.y
						nsolid, ntotal = region.Gather(SegmentList, pos, radius, UpDelta, segments)

						movement.Vertical(pos, radius, SegmentList, UpDelta.y, nsolid, ntotal)
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

--
--
--

return M