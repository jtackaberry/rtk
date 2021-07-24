-- Copyright 2021 Jason Tackaberry
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local rtk = require('rtk.core')

--- A utility class that renders a general purpose shadow frame.  Useful, for example, to
-- render a shadow around an rtk-based popup menu.
--
-- This is meant more for internal widget implementations but you're free to use this
-- directly.
--
-- Only the frame is rendered based on the `elevation`, not the inner part, so it does
-- not affect the coloring of translucent surfaces drawn over top.
--
-- @warning A bit janky
--   The shadow quality isn't all that it might be.  Consider this a WIP that will see
--   future refinement.
--
-- @example
--   -- Create a red translucent shadow
--   local shadow = rtk.Shadow('red#44')
--   -- Create a crimson colored box that's 50% the window size
--   local spacer = window:add(rtk.Spacer{w=0.5, h=0.5, bg='crimson'})
--   -- When the widget reflows, regenerate the shadow
--   spacer.onreflow = function(self)
--       shadow:set_rectangle(self.calc.w, self.calc.h, 40)
--   end
--   -- And when the is drawn, also draw the spacer at the widget's
--   -- position.
--   spacer.ondraw = function(self, offx, offy, alpha)
--       shadow:draw(self.calc.x + offx, self.calc.y + offy, alpha)
--   end
--
--
-- @class rtk.Shadow
rtk.Shadow = rtk.class('rtk.Shadow')

--- Shadow Type Constants.
--
-- Used with the `type` attribute that indicates the type of shadow.
--
-- @section shadowtypeconst
-- @compact

--- A rectangular shadow
rtk.Shadow.static.RECTANGLE = 0
--- A circular shadow
rtk.Shadow.static.CIRCLE = 1


--- Class API
--
-- @section api

rtk.Shadow.register{
    --- The type of shadow based on whether `set_rectangle()` or `set_circle()` was called.
    -- @type shadowtypeconst
    -- @meta read-only
    type = nil,
    --- The color of the shadow (defaults to `#00000055`)
    -- @type colortype
    -- @meta read/write
    color = '#00000055',
    --- The width that was last passed to `set_rectangle()`
    -- @type number|nil
    -- @meta read-only
    w = nil,
    --- The height that was last passed to `set_rectangle()`
    -- @type number|nil
    -- @meta read-only
    h = nil,
    --- The radius that was last passed to `set_circle`()`
    -- @type number|nil
    -- @meta read-only
    radius = nil,
   --- The computed elevation based on the last call to `set_rectangle()` or `set_circle`()`
    -- @type number|nil
    -- @meta read-only
    elevation = nil,
}

--- Create a new Shadow instance
--
-- @display rtk.Shadow
function rtk.Shadow:initialize(color)
    self.color = color or self.class.attributes.color.default
    self._image = nil
    self._last_draw_params = nil
end

--- Sets a rectangular shadow.
--
-- When this is called, the internal shadow image is re-rendered, so it should only
-- be called when the dimensions actually change, or when you want to change elevation.
--
-- @tparam number w the width of the content box the shadow is wrapping, where
--   the shadow starts around the edges and expands outward beyond the given width
-- @tparam number h like w but for height
-- @tparam number|nil elevation affects the apparent height of object the shadow intends
--   to apply to, which roughly corresponds to the number of pixels the shadow expands
--   out to.
-- @tparam number|nil t number of pixels for the top edge, or uses elevation if nil
-- @tparam number|nil r number of pixels for the right edge, or uses elevation if nil
-- @tparam number|nil b number of pixels for the bottom edge, or uses elevation if nil
-- @tparam number|nil l number of pixels for the left edge, or uses elevation if nil
function rtk.Shadow:set_rectangle(w, h, elevation, t, r, b, l)
    self.type = rtk.Shadow.RECTANGLE
    self.w = w
    self.h = h
    self.tt = t or elevation
    self.tr = r or elevation
    self.tb = b or elevation
    self.tl = l or elevation
    assert(self.tt or self.tr or self.tb or self.tl, 'missing elevation for at least one edge')
    self.elevation = elevation or math.max(self.tt, self.tr, self.tb, self.tl)
    self.radius = nil
    self._check_generate = true
end

--- Sets a circular shadow.
--
-- When this is called, the internal shadow image is re-rendered, so it should only
-- be called when the radius changes, or when you want to change elevation.
--
-- @tparam number radius the radius of the inner content area in pixels, which the shadow
--   will wrap and expand outward from
-- @tparam number|nil elevation affects the apparent height of object the shadow intends
--   to apply to, which roughly corresponds to the number of pixels the shadow expands
--   out to.  If nil, the elevation defaults to 2/3 of the radius.
function rtk.Shadow:set_circle(radius, elevation)
    self.type = rtk.Shadow.CIRCLE
    elevation = elevation or radius/1.5
    if self.radius == radius and self.elevation == elevation then
        return
    end
    self.radius = radius
    self.elevation = elevation
    self._check_generate = true
end

--- Draws the shadow on the current drawing target.
--
-- @tparam number x the x coordinate of the *inner* content box that the shadow wraps
-- @tparam number y the y coordinate of the *inner* content box that the shadow wraps
-- @tparam number|nil alpha the opacity of the shadow, which applies a multiplier to the
--  calculated shadow opacity derived from elevation (default 1.0)
function rtk.Shadow:draw(x, y, alpha)
    if self.radius then
        self:_draw_circle(x, y, alpha or 1.0)
    else
        self:_draw_rectangle(x, y, alpha or 1.0)
    end
end

-- Rendering the shadow can be expensive, so we go through some lengths to avoid
-- regenerating it if none of the parameters have changed at time of draw.
function rtk.Shadow:_needs_generate()
    if self._check_generate == false then
        return false
    end
    local params = self._last_draw_params
    local gen =
        not params or
        self.w ~= params.w or
        self.h ~= params.h or
        self.tt ~= params.tt or
        self.tr ~= params.tr or
        self.tb ~= params.tb or
        self.tl ~= params.tl or
        self.elevation ~= params.elevation or
        self.radius ~= params.radius
    if gen then
        self._last_draw_params = {
            w = self.w,
            h = self.h,
            tt = self.tt,
            tr = self.tr,
            tb = self.tb,
            tl = self.tl,
            elevation = self.elevation,
            radius = self.radius
        }
    end
    self._check_generate = false
    return gen
end

function rtk.Shadow:_draw_circle(x, y, alpha)
    local pad = self.elevation*3
    if self:_needs_generate() then
        local radius = math.ceil(self.radius)
        local sz = (radius + 2 + pad) * 2
        if not self._image then
            self._image = rtk.Image(sz, sz)
        else
            self._image:resize(sz, sz, true)
        end
        self._image:pushdest()
        rtk.color.set(self.color)

        -- Draw concentric circles outward with diminishing opacity.  If we use non-filled
        -- circles the shadow has artifacts, so we need to use filled circles.  But then
        -- each circle lay
        -- FIXME: this code is hasty and experimental
        local a = 0.65 - 0.5*(1 - 1/self.elevation)
        -- The ln of our widest radius.
        local inflection = radius
        local origin = -math.log(1/(pad))
        for i = radius + pad, 1, -1 do
            if i > inflection then
                gfx.a2 = -math.log((i - inflection)/(pad))/origin*a
            else
                -- gfx.a2 = 1 - i/(radius+1)--*(0.65-a)
            end
            -- gfx.a2 = -0.3 * math.log(i/(radius+pad))
            gfx.circle(pad + radius , pad + radius, i, 1, 1)
        end
        gfx.a2 = 1
        gfx.set(0, 0, 0, 1)
        self._image:popdest()
        self._needs_draw = false
    end
    self._image:draw(x - pad, y - pad, alpha)
end

function rtk.Shadow:_draw_rectangle(x, y, alpha)
    local tt, tr, tb, tl = self.tt, self.tr, self.tb, self.tl
    local pad = math.max(tl, tr, tt, tb)
    if self:_needs_generate() then
        local w = self.w + (tl + tr) + pad*2
        local h = self.h + (tt + tb) + pad*2
        if not self._image then
            self._image = rtk.Image(w, h)
        else
            self._image:resize(w, h, true)
        end
        -- Draw concentric rounded (and filled) rectangles with different target alphas to create
        -- the shadow.
        self._image:pushdest()
        rtk.color.set(self.color)
        -- We use gfx.a2 to control alpha (as we draw filled rectangles concentrically, it prevents
        -- the alpha channel from stacking up on each layer), so preserve the alpha from the user
        -- supplied color to use as an alpha multiplier, and set gfx.a to full opacity.
        local a = gfx.a
        gfx.a = 1
        for i = 0, pad do
            gfx.a2 = a * (i+1)/pad
            rtk.gfx.roundrect(pad + i , pad + i, self.w + tl + tr - i*2, self.h + tt + tb - i*2, self.elevation, 0)
        end
        self._image:popdest()
        self._needs_draw = false
    end
    if tr > 0 then
        -- Right edge
        self._image:blit{
            sx=pad + tl + self.w,
            sw=tr + pad,
            sh=h,
            dx=x + self.w,
            dy=y - tt - pad,
            alpha=alpha
        }
    end
    if tb > 0 then
        -- Bottom edge
        self._image:blit{
            sy=pad + tt + self.h,
            sw=self.w + tl + pad,
            sh=tb + pad,
            dx=x - tl - pad,
            dy=y + self.h,
            alpha=alpha
        }
    end
    if tt > 0 then
        -- Top edge
        self._image:blit{
            sx=0,
            sy=0,
            sw=self.w + tl + pad,
            sh=pad + tt,
            dx=x - tl - pad,
            dy=y - tt - pad,
            alpha=alpha
        }
    end
    if tl > 0 then
        -- Left edge
        self._image:blit{
            sx=0,
            sy=pad + tt,
            sw=pad + tl,
            sh=self.h,
            dx=x - tl - pad,
            dy=y,
            alpha=alpha
        }
    end
end