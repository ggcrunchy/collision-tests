--- Surface utilities.

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
local pairs = pairs

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Exports --
local M = {}

--
--
--

--
function M.AddToFloor (surface, object)
    local touched_objects = surface.m_touched_objects or {}
	local is_new = not touched_objects[object]

	if is_new then
		surface.m_touched_objects, touched_objects[object] = touched_objects, true
	end

	return is_new
end

--
function M.IsPassThroughSurface (object)
    local sdata = object._data

    return sdata ~= nil and not sdata.is_solid
end

--
function M.IsSolidSurface (object)
    local sdata = object._data

    return not not (sdata and sdata.is_solid)
end

--
function M.IsSurface (object)
    return object._data ~= nil
end

--
function M.MoveTouchedObjects (surface)
    local motion = surface.m_motion

    motion:Negate()

    local touched_objects = surface.m_touched_objects

    if touched_objects then
        for object in pairs(touched_objects) do
            local vx, vy = object:getLinearVelocity()

            object:setLinearVelocity(vx + 2 * motion.x, vy + 2 * motion.y) -- multiplied by 2 since we are first subtracting the previous motion;
                                                                           -- we increment like this to preserve any non-platform motion
                                                                           -- TODO: this handles back-and-forth platforms, but not anything that
                                                                           -- changes direction, so those would do a -motion, + new motion thing
        end
    end

    surface:setLinearVelocity(motion.x, motion.y)
end

local Foot = ctnative.Vector2()
local Origin = ctnative.Vector2()
local Pos = ctnative.Vector2()
local Ray = ctnative.Vector2()
local ToPos = ctnative.Vector2()
local Up = ctnative.Vector2(0, -1)

--
function M.ObjectHeightSquared (surface, object)
	Pos:SetFrom(object)
	Origin:SetFrom(surface)
	Ray:SetFrom(surface, "dx", "dy")
	Foot:SetProjectionOfPointOntoRay(Pos, Origin, Ray)
	ToPos:SetDifference(Pos, Foot)

	local hsquared = ToPos:LengthSquared()

	return ToPos:DotProduct(Up) >= 0 and hsquared or -hsquared
end

--
function M.RemoveFromFloor (surface, object)
    local touched_objects = surface.m_touched_objects
    local is_touching = touched_objects and touched_objects[object]

    if is_touching then
        touched_objects[object] = nil
    end

    return is_touching or false
end

return M