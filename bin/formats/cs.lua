--[[
Copyright (c) 2010 Andreas Krinke

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--]]

local string = string
local format = string.format
local gmatch = string.gmatch
local gsub = string.gsub
local lower = string.lower
local match = string.match

local concat = table.concat
local tonumber = tonumber
local unpack = unpack

return {
  image = {
    pre = [[
public void Draw$basename(Context cr, int x, int y, float width, float height, double[] rgba) {
	ImageSurface temp_surface;
	Context old_cr;
	Pattern pattern = null;
	Matrix matrix = cr.Matrix;
	
	cr.Save();
	float w = $width;
	float h = $height;
	float scale = Math.Min(width / w, height / h);
	matrix.Translate(x + Math.Max(0, (width - w * scale) / 2), y + Math.Max(0, (height - h * scale) / 2));
	matrix.Scale(scale, scale);
	cr.Matrix = matrix;
]],

    post = [[
	cr.Restore();
}
]]
  },
  
  surface = {
    pre = [[
	old_cr = cr;
	temp_surface = new ImageSurface(Format.Argb32, $width, $height);
	cr = new Context(temp_surface);]],
  },
  
  fill   = {post = "	cr.FillPreserve();\n	if (pattern!= null) pattern.Dispose();\n"},
  stroke = {post = "	cr.StrokePreserve();\n	if (pattern!= null) pattern.Dispose();\n"},
  paint  = {post = "	cr.Paint();\n"},
  mask   = {},
  
  operator        = function(state, value) return format("	cr.Operator = Operator.%s;", gsub(value, "OVER", "Over")) end,
  tolerance       = "	cr.Tolerance = $value;",
  antialias       = function(state, value) return format("	cr.Antialias = Antialias.%s;", gsub(value, "ANTIALIAS_DEFAULT", "Default")) end,
  ["fill-rule"]   = function(state, value) return format("	cr.FillRule = FillRule.%s;", gsub(value, "WINDING", "Winding")) end,
  ["line-width"]  = "	cr.LineWidth = $value;",
  ["miter-limit"] = "	cr.MiterLimit = $value;",
  ["line-cap"]    = function(state, value) return format("	cr.LineCap = LineCap.%s;", gsub(value, "LINE_CAP_BUTT", "Butt")) end,
  ["line-join"]   = function(state, value) return format("	cr.LineJoin = LineJoin.%s;", gsub(value, "LINE_JOIN_MITER", "Miter")) end,

  linear          = "	pattern = new LinearGradient($x1, $y1, $x2, $y2);",
  radial          = "	pattern = new RadialGradient($x1, $y1, $r1, $x2, $y2, $r2);",
  solid           = function(state, value) return format("	pattern = new SolidPattern(rgba[0], rgba[1], rgba[2], rgba[3]);") end,
  ["color-stop"]  = function(state, value) return format("	pattern.AddColorStop(%s);", gsub(value, " ", ",")) end,
  extend          = "	pattern.Extend = Extend.$value;",
  filter          = "	pattern.Filter = Filter.$value;",
  
  ["source-pattern"] = {
    post = function(state, value)
      if state.last_environment == "surface" then
        return [[
	cr.Dispose();
	cr = old_cr;
	cr.SetSource(temp_surface, 0, 0);
	temp_surface.Dispose();]]
      else
        return [[
	cr.SetSource(pattern);
	]]
      end
    end
  },
  
  ["mask-pattern"] = {
    post = function(state, value)
      if state.last_environment == "surface" then
        return [[
	cr.MaskSurface(temp_surface, 0, 0);
	temp_surface.Dispose();]]
      else
        return [[
	cr.Mask(pattern);
	pattern.Dispose();]]
      end
    end
  },
  
  path = function(state, value)
    local s = {"	cr.NewPath();"}
    local stack = {}
    for x in gmatch(value, "%S+") do
      local n = tonumber(x)
      if n then
        stack[#stack+1] = x
      else
        if x == "m" then
          s[#s+1] = format("	cr.MoveTo(%s, %s);", unpack(stack))
        elseif x == "l" then
          s[#s+1] = format("	cr.LineTo(%s, %s);", unpack(stack))
        elseif x == "c" then
          s[#s+1] = format("	cr.CurveTo(%s, %s, %s, %s, %s, %s);", unpack(stack))
        elseif x == "h" then
          s[#s+1] = "	cr.ClosePath();"
        end
        stack = {}
      end
    end
    return concat(s, "\n")
  end,      
  
  matrix = function(state, value) 
    local s = format("matrix = new Matrix(%s);\n", gsub(value, " ", ","))
    if state.last_environment == "surface" then
      return s .. [[
	matrix.x0 = 0;
	matrix.y0 = 0;
	cr.Matrix = matrix;]]
    else
      return s .. "pattern.Matrix = matrix;"
    end
  end
}
