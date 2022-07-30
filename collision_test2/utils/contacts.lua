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

local Foot = ctnative.Vector2()
local Normal = ctnative.Vector2()
local Pos = ctnative.Vector2()
local Velocity = ctnative.Vector2()

--
--
--

local Delta = ctnative.Vector2()
local Intersection = ctnative.Vector2()
local IntersectionFoot = ctnative.Vector2()
local LeftoverVel = ctnative.Vector2()
local ScaledVel = ctnative.Vector2()

--- DOCME
function M.CheckMovingCircles (list, n, center, radius, vel, how)
  local a, best_dsq, seg = vel:LengthSquared(), 1 / 0

  for i = 1, n do
    local cur = list[i]

    if segments.IntersectCircleWithMotion(cur.p1, cur.p2, center, radius, vel, Intersection, IntersectionFoot) then
      Delta:SetDifference(Intersection, center)

      local dsq = Delta:LengthSquared()

      if dsq < best_dsq then
        if dsq > a then
--[[
print("penetrating...",dsq-a,a,ix-cx,iy-cy) -- see below too
print("T",T1,T2)]]
        end

        Foot:Set(IntersectionFoot)
        Pos:Set(Intersection)
      
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
      -- [d - t*v].[d - t*v] = r^2
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
        Pos:Set(p)
        Pos:SubScaled(Delta, scale)
        Foot:Set(p)

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
            Pos:Set(center)
            Pos:AddScaled(vel, t)
            Foot:Set(p)

            seg, best_dsq = cur, dsq
          end
        end
      end
    end
  end

  if seg then
    ScaledVel:SetScaled(vel, .00125 / sqrt(a))
    Pos:Sub(ScaledVel)
--	Fx, Fy = Fx - dvx, Fy - dvy
    LeftoverVel:SetDifference(vel, ScaledVel)
    LeftoverVel:Add(center) -- leftover velocity = destination - intersection
    LeftoverVel:Sub(Pos)

    Normal:SetDifference(Pos, Foot)
    Normal:Normalize()

    local vn = LeftoverVel:DotProduct(Normal)

    Velocity:Set(LeftoverVel) -- slide
    Velocity:SubScaled(Normal, vn)

    if how == "rescale" then -- keep "leftover" speed?
      Velocity:ScaleToLength(LeftoverVel:Length())
    end
  end

  return seg
end

--
--
--

--- DOCME
function M.GetFoot (foot)
    foot:Set(Foot)
end

--
--
--

--- DOCME
function M.GetNormal (normal)
    normal:Set(Normal)
end

--
--
--

--- DOCME
function M.GetPosition (pos)
    pos:Set(Pos)
end

--
--
--

--- DOCME
function M.GetVelocity (vel)
    vel:Set(Velocity)
end

--
--
--

return M