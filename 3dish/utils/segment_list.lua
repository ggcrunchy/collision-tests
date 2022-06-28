--- Collision-related operations on lists of segments.

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
local sqrt = math.sqrt

-- Modules --
local qf = require("math.quadratic_formula")
local segments = require("math.segments")

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Exports --
local M = {}

--
--
--

do
	local GatherRegion = ctnative.AABox2()

	--
	function M.Gather (list, center, radius, delta, source)
		-- Begin with a region around the circle, with some tolerance. Refine it to account for motion.
		GatherRegion:SetFromCircle(center, radius + .01)
		GatherRegion:Augment(delta)

		-- Gather the segments not trivially outside, putting any solid ones up front.
		local nsolid, ntotal = 0, 0

		for i = 1, #source do
			local seg = source[i]

			if not GatherRegion:CanTriviallyRejectSegment(seg.p1, seg.p2) then
				if seg.is_solid then
					if nsolid < ntotal then -- neither empty nor all solid?
						list[nsolid + 1], seg = seg, list[nsolid + 1]
					end

					nsolid = nsolid + 1
				end

				list[ntotal + 1], ntotal = seg, ntotal + 1
			end
		end

		return nsolid, ntotal
	end
end

local ContactFoot = ctnative.Vector2()
local ContactPos = ctnative.Vector2()
local ContactVelocity = ctnative.Vector2()

do
	local Delta = ctnative.Vector2()
	local Foot = ctnative.Vector2()
	local Intersection = ctnative.Vector2()
	local LeftoverVel = ctnative.Vector2()
	local Normal = ctnative.Vector2()
	local ScaledVel = ctnative.Vector2()

	--- DOCME
	function M.CheckMovingCircleHits (list, n, center, radius, vel, keep_speed)
		local a, best_dsq, seg = vel:LengthSquared(), 1 / 0

		for i = 1, n do
			local cur = list[i]

			if segments.IntersectCircleWithMotion(cur.p1, cur.p2, center, radius, vel, Intersection, Foot) then
				Delta:SetDifference(Intersection, center)

				local dsq = Delta:LengthSquared()

				if dsq < best_dsq then
					if dsq > a then
	--[[
	print("penetrating...",dsq-a,a,ix-cx,iy-cy) -- see below too
	print("T",T1,T2)]]
					end

					ContactPos:Set(Intersection)
					ContactFoot:Set(Foot)
				
					seg, best_dsq = cur, dsq
				end
			end
		end

		local r2 = radius^2

		for i = 1, n do
			local cur = list[i]

			for j = 1, 2 do
				local p = j == 1 and cur.p1 or cur.p2

				-- Moving circle-point intersection:
				-- [p - (c + t*v)].[p - (c + t*v)] = r^2
				-- d: p - c
				-- [d + t*v].[d + t*v] = r^2
				-- After grouping:
				-- a: v.v
				-- b: -2*v.d
				-- c: d.d - r^2
				Delta:SetDifference(p, center)

				local dlen_sq = Delta:LengthSquared()
				local c = dlen_sq - r2

				if c < 0 then -- endpoint has penetrated circle?
					local scale = radius / sqrt(dlen_sq)
	--print("!!!!!",best_dsq and best_dsq>a) -- leave this for now in case it's still a problem
					ContactPos:Set(p)
					ContactPos:SubScaled(Delta, scale)
					ContactFoot:Set(p)

					seg, best_dsq = cur, 0
				else
					local b = -vel:DotProduct(Delta)
					local t = qf.Quadratic_TwoB_PositiveA_GetFirst(a, b, c) or -1
					local t2 = t^2

					if 1 + t2 == 1 then
						t = 0
					end

					if t >= 0 and t <= 1 then
						local dsq = t2 * a -- [I - c].[I - c] | I = p + t*v

						if dsq < best_dsq then
							ContactPos:Set(center)
							ContactPos:AddScaled(vel, t)
							ContactFoot:Set(p)

							seg, best_dsq = cur, dsq
						end
					end
				end
			end
		end

		if seg then
			ScaledVel:SetScaled(vel, .00125 / sqrt(a))
			ContactPos:Sub(ScaledVel)
--	Fx, Fy = Fx - dvx, Fy - dvy
			LeftoverVel:SetDifference(vel, ScaledVel)
			LeftoverVel:Add(center) -- leftover velocity = destination - intersection
			LeftoverVel:Sub(ContactPos)

			Normal:SetDifference(ContactPos, ContactFoot)

			local vn = LeftoverVel:DotProduct(Normal) / Normal:LengthSquared()

			ContactVelocity:Set(LeftoverVel) -- slide
			ContactVelocity:SubScaled(Normal, vn)

			if keep_speed then -- keep "leftover" speed?
				ContactVelocity:ScaleToLength(LeftoverVel:Length())
			end
	--[[
			TODO: friction
			-- ^^ actually this probably belongs elsewhere, say in update
			local f=.9
	Vx,Vy=f*Vx,f*Vy]]
		end

		return seg
	end
end

--- DOCME
function M.GetContactFoot (foot)
    foot:Set(ContactFoot)--XY(Fx, Fy)
end

--- DOCME
function M.GetContactPosition (pos)
    pos:Set(ContactPos)--XY(Px, Py)
end

--- DOCME
function M.GetContactVelocity (vel)
    vel:Set(ContactVelocity)--XY(Vx, Vy)
end

return M