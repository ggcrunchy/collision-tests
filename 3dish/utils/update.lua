--- UPDATE OBJECT

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

-- Modules --
local segment_list = require("utils.segment_list")

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Cached module references --
local _GetUpComponent_
local _GoingUp_

-- Exports --
local M = {}

--
--
--

local Iterations = 5

local LowSpeedSquared = 1.75

local OldPos, OldVel = ctnative.Vector2(), ctnative.Vector2()

--- DOCME
function M.Advance (pos, radius, segments, vel, nsolid, ntotal, rescale)
	local n, did_advance, seg = _GoingUp_(vel) and nsolid or ntotal, false
	-- ^^^ This solid / ntotal distinction actually works rather well but snags on vertices on the way down
	-- possible workaround: visit the remaining segments, note any penetrating vertices, ignore them
	-- seems a bit hard to get right, though :/ (How do you clear it? What if they're moving?)
	-- we can get somewhat okay behavior by ignoring the depenetration logic if the segment isn't solid,
	-- but that breaks down if we approach from the side
	-- we could mention that some segments are non-solid and then detect already-penetrated segments,
	-- then just ignore vertices on these?

	for _ = 1, Iterations do
		if vel:LengthSquared() <= LowSpeedSquared then
			break
		end

		local hit = segment_list.CheckMovingCircleHits(segments, n, pos, radius, vel, rescale)

		if not hit then
			pos:Add(vel)

			did_advance = true

			break
		end

		OldPos:Set(pos)
		OldVel:Set(vel)

		segment_list.GetContactPosition(pos)
		segment_list.GetContactVelocity(vel)

		if not (pos:IsAlmostEqualTo(OldPos) and vel:IsAlmostEqualTo(OldVel)) then
			did_advance, seg = true, hit
		end
	end

    return seg, did_advance
end

local Right = ctnative.Vector2(1, 0)

--- DOCME
function M.GetRight (right)
	right:Set(Right)
end

local Up = ctnative.Vector2(0, -1)

--- DOCME
function M.GetUp (up)
	up:Set(Up)
end

--- DOCME
function M.GetUpComponent (vel)
	return vel:DotProduct(Up)
end

--- DOCME
function M.GoingUp (vel)
	return _GetUpComponent_(vel) > 0
end

--- DOCME
function M.SetIterationCount (iterations)
	local old = Iterations

	Iterations = iterations

	return old
end

--- DOCME
function M.SetLowSpeedSquared (low_speed_squared)
	local old = LowSpeedSquared

	LowSpeedSquared = low_speed_squared

	return old
end

-- Cache module members.
_GetUpComponent_ = M.GetUpComponent
_GoingUp_ = M.GoingUp

return M