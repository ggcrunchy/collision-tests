--- Object to change the course of platforms.

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

-- Solar2D globals --
local display = display

-- Solar2D modules --
local physics = require("physics")

-- Unique member keys --
local _target = {}

-- Exports --
local M = {}

--
--
--

-- TODO?: generalize
local DetectorRadius, DetectorCategory = 3, 0x2
local Body = { categoryBits = DetectorCategory, isSensor = true, radius = DetectorRadius }

--
function M.AddObject (seg, t)
	local motion = seg.m_motion
	local change = display.newCircle(seg.x + motion.x * t, seg.y + motion.y * t, DetectorRadius)
-- ^^ TODO: not very flexible, designed around test...
	physics.addBody(change, Body)

	change.gravityScale, change.isVisible = 0, false

    change[_target] = seg

	return change
end

local DetectorBody = { maskBits = DetectorCategory, radius = DetectorRadius }

--
function M.GetDetectorBody ()
    return DetectorBody
end

--
function M.MakeCollisionListener (element, func)
    return function(event)
        local seg = event.target 

        if event.selfElement == element and event.other[_target] == seg then
            func(seg, event.phase)
        end
    end
end

return M