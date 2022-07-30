--- Collision-related movement logic.

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
local min = math.min
local sqrt = math.sqrt

-- Modules --
local update = require("utils.update")

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Exports --
local M = {}

--
--
--

local Edge = ctnative.Vector2()
local OldPos, OldRight = ctnative.Vector2(), ctnative.Vector2()
local Right = ctnative.Vector2()
local Velocity = ctnative.Vector2()

--
--
--

--- DOCME
function M.Horizontal (pos, radius, segments, dx, nsolid, ntotal, fseg, how, hvel)
  update.GetRight(OldRight)
  Right:Set(OldRight)
  
  local check_hit

  if how == "rescale" and ntotal == 1 then
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

      if how == "rescale" then
        dx = dx / abs(Right.x) -- want to go X units along axis, not across the floor
      end
    end
  end

  local vel = hvel or Velocity

  vel:SetScaled(Right, dx)
  OldPos:Set(pos)
HH=true
  local hit = update.Advance(pos, radius, segments, vel, nsolid, ntotal, how)

  if hit and check_hit and hit ~= fseg then 	-- we ran into something, so try the floor-unaware version;
                        -- the "jump" that tends to happen is actually better here
                        -- TODO: could check if the segments are attached, if necessary
    pos:Set(OldPos)
    vel:SetScaled(OldRight, dx)

    update.Advance(pos, radius, segments, vel, nsolid, ntotal, how)
  end
HH=false
end

--
--
--

local TooQuickSquared = 80 -- this (and the damping) could probably be properties of different built-in ice types

--- DOCME
function M.ModifyVelocity (velocity, cur, seg, delta)
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

--
--
--

--- DOCME
function M.Vertical (pos, radius, segments, dy, nsolid, ntotal, vvel)
  local vel = vvel or Velocity

  update.GetUp(vel)
  vel:ScaleBy(-dy)

  return update.Advance(pos, radius, segments, vel, nsolid, ntotal, "friction")
end

--
--
--

return M