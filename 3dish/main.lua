--- Experiments driver.

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
local device = require("utils.device")

--
--
--

device.MapAxesToKeyEvents(true)

local ctnative = require("plugin.ctnative")

local CX, CY = display.contentCenterX, display.contentCenterY
local X1, Y1 = CX - 1, CY - 1
local X2, Y2 = CX + 1, CY + 1

local pp = ctnative.Vector3(CX, CY, 100)
local vv = ctnative.Vector3(0, 1, -1)
local plane = ctnative.Plane(pp, vv)

local vertices = {}
local quads = {}

local function Point (x, y, z)
    vertices[#vertices + 1] = ctnative.Vector3(CX + x, CY + y, z)
end

local axis1, axis2 = ctnative.Vector3(), ctnative.Vector3()

local function Quad (a, b, c, d,ee)
    local corner = vertices[b]

    axis1:SetDifference(corner, vertices[c])
    axis2:SetDifference(corner, vertices[a])

    local cross = axis1:CrossProduct(axis2) -- TODO: output to vector...
    local plane = ctnative.Plane(corner, cross)

    quads[#quads + 1] = { a, b, c, d, plane = plane,ee=ee }
end

local function RectXZ0 (x, z, w, h, y)
    local n = #vertices

    y = y or 0

    Point(x, y, z)
    Point(x, y, z + h)
    Point(x + w, y, z + h)
    Point(x + w, y, z)

    Quad(n + 1, n + 2, n + 3, n + 4)
end

RectXZ0(-200, -50, 100, 100)
RectXZ0(-50, -50, 100, 100)
RectXZ0(100, -150, 100, 300)
RectXZ0(250, -150, 100, 100)
RectXZ0(250, -25, 100, 100)
--quads[#quads].ee="ee"
RectXZ0(-50, -50, 100, 100, 500)
--quads[#quads].ee="ee"

local nverts = #vertices

Point(200, 200, 50)
Point(200, 200, -50)
Quad(nverts, nverts - 1, nverts + 1, nverts + 2)
quads[#quads].ee="ee"

for _, v in ipairs(quads) do
    local rect = display.newRect(CX, CY, 3, 3)

    for i = 1, 4 do
        rect:setFillVertexColor(i, math.random(), math.random(), math.random())
    end

    v.rect = rect
end

local results = {}

for i = 1, 4 do
    results[i] = ctnative.Vector3()
end

local pos = ctnative.Vector3(90 + CX, 0, 10)
local radius = 10

local cc = display.newCircle(0, 0, 1)

local cresult = ctnative.Vector3()
local rdummy = ctnative.Vector3()
local vel = ctnative.Vector3()

cc:setFillColor(math.random(), math.random(), math.random())

local ss = display.newText("", CX, 50, native.systemFontBold, 20)

timer.performWithDelay(100, function(event)

    vv.x = math.sin(event.time / 2400)
    vv.y = math.cos(event.time / 3100)

    plane:SetNormal(vv)

    --pp.y = 200 * math.sin(event.time / 2000)

    plane:SetPosition(pp)

    local t = math.min(event.time / 1000, 5)
pos.y = -100 + CY
vel.y = 300
    
local hit = 1 / 0
    for i = 1, #quads do
        local q = quads[i]
if q.ee=="ee" then
        local isx, tt = q.plane:GetIntersectionWith(pos, vel)

        if isx and tt < hit then
            hit = tt
        end
end
    end

if hit < t then
--print("!", t,hit)
    t = hit
else
end

    pos.y = -100 + CY + t * 300

    rdummy:Set(pos)

    rdummy.x = rdummy.x + radius

    plane:GetProjectionOfPoint(pos, cresult)

    cc.x, cc.y = cresult.x, cresult.y

    plane:GetProjectionOfPoint(rdummy, cresult)

    cc.path.radius = cresult.x - cc.x
--ss.text = ("POS: (%f, %f), CIRCLE: (%f, %f; r = %f)"):format(vv.x, vv.y, cc.x, cc.y, cc.path.radius)
    for _, v in ipairs(quads) do
        for i = 1, 4 do
            plane:GetProjectionOfPoint(vertices[v[i]], results[i])
        end

        local qpath = v.rect.path

        qpath.x1, qpath.y1 = results[1].x - X1, results[1].y - Y1
        qpath.x2, qpath.y2 = results[2].x - X1, results[2].y - Y2
        qpath.x3, qpath.y3 = results[3].x - X2, results[3].y - Y2
        qpath.x4, qpath.y4 = results[4].x - X2, results[4].y - Y1
    end

end, 0)