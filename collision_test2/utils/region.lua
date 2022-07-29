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

-- Plugins --
local ctnative = require("plugin.ctnative")

-- Exports --
local M = {}

--
--
--

local GatherRegion = ctnative.AABox2()

--- DOCME
function M.Gather (list, center, radius, delta, source)
  -- Begin with a region around the circle, augmenting with the motion range plus a tolerance.
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

--
--
--

return M