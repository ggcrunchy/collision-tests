--- Segment data for side-scroller test.

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
local assert = assert

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Exports --
local M = {}

--
--
--

-- Test level --
local Segments = {
	{ x1 = 300, x2 = 500, y = 350 },
	{ x1 = 400, x2 = 475, y = 340 },
	{ x1 = 400, x2 = 475, y = 240, is_solid = true },
	{ x1 = 50, y1 = 300, x2 = 200, y2 = 400 },
	{ x1 = 150, x2 = 250, y = 175 },
	{ x = 250, y1 = 25, y2 = 175 },
	{ x1 = 50, y1 = 600, x2 = 200, y2 = 700 },
	{ x1 = 200, y1 = 700, x2 = 400, y2 = 500 },
	{ x1 = -50, y1 = 800, x2 = 200, y2 = 950 },
	{ x1 = 200, x2 = display.contentWidth + 50, y = 950, type = --"conveyer", momentum = -250 },
														 "ice", damping = .675 },
	{ x1 = 400, x2 = 450, y = 940 },
	{ x = 200, y1 = 400, y2 = 500, is_solid = true },
	{ x1 = 420, x2 = 490, y = 500, move = { dy = 1, pos1 = 0, pos2 = 300, t = 5, dir = true } },
	{ x1 = 200, x2 = 350, y = 800, move = { dx = 1, pos1 = -100, pos2 = 200, t = 3, dir = true } },
	{ x1 = 400, x2 = 475, y = 140, is_solid = true, move = { dx = 3, dy = 1, pos1 = -50, pos2 = 30, t = 3 } },
	{ x1 = 100, x2 = 150, y = 500, move = { dx = 1, pos1 = -100, pos2 = 200, t = 2 } },
	{ x = 300, y1 = 850, y2 = 950, move = { dx = 1, pos1 = -100, pos2 = display.contentWidth - 300, t = 8 }}
}

--
--
--

---
function M.Init ()
  for i = 1, #Segments do
    local sdata = Segments[i]

    if sdata.x then
      assert(not (sdata.x1 or sdata.x2), "Inconsistent x-coordinates")

      sdata.x1, sdata.x2, sdata.x = sdata.x, sdata.x
    end

    if sdata.y then
      assert(not (sdata.y1 or sdata.y2), "Inconsistent y-coordinates")

      sdata.y1, sdata.y2, sdata.y = sdata.y, sdata.y
    end

    if sdata.x2 < sdata.x1 then
      sdata.x1, sdata.x2 = sdata.x2, sdata.x1
      sdata.y1, sdata.y2 = sdata.y2, sdata.y1
    end

    sdata.p1, sdata.x1, sdata.y1 = ctnative.Vector2(sdata.x1, sdata.y1)
    sdata.p2, sdata.x2, sdata.y2 = ctnative.Vector2(sdata.x2, sdata.y2)
  end

  return Segments
end

--
--
--

return M