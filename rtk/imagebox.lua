-- Copyright 2017-2022 Jason Tackaberry
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
local log = require('rtk.log')


--- A widget that wraps an `rtk.Image`.
--
-- `rtk.Image` is a low-level class for managing images and those objects can't be added
-- to containers, but `rtk.ImageBox` are proper widgets and can be.
--
-- @example
--   -- Create an ImageBox widget with photo.jpg that's located in an img
--   -- directory up from the current script.
--   local img = rtk.ImageBox{rtk.Image():load('../img/photo.jpg'), border='2px black'}
--   -- Add the image centered to the window
--   window:add(img, {halign='center', valign='center'})
--   -- Just a bit of fun ...
--   img.onclick = function()
--       img:animate{'scale', dst=0.2, easing='out-bounce', duration=2}
--   end
--
-- @class rtk.ImageBox
-- @inherits rtk.Widget
-- @see rtk.Image
rtk.ImageBox = rtk.class('rtk.ImageBox', rtk.Widget)

rtk.ImageBox.register{
    [1] = rtk.Attribute{alias='image'},

    --- The image (default nil).
    --
    -- This is typically an `rtk.Image`, but a string can also be provided which refers to
    -- an icon name (without file extension) in an icon path previously registered with
    -- `rtk.add_image_search_path()`. See `rtk.Image.icon()` for more details.
    --
    -- This attribute may be passed as the first positional argument during initialization.
    -- (In other words, `rtk.ImageBox{img}` is equivalent to `rtk.ImageBox{image=img}`.)
    --
    -- If `image` is nil, nothing is drawn and the ImageBox takes up no space in its container.
    -- The `image` attribute can be assigned later.
    --
    -- @type rtk.Image|string|nil
    -- @meta read/write
    image = rtk.Attribute{
        -- Can't use rtk.Reference() because rtk.Entry isn't a superclass
        calculate=rtk.Entry.attributes.icon.calculate,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- Forces a scale for the image (default nil).
    --
    -- By default (nil), images will shrink to fit their container (while preserving
    -- aspect), but will not grow beyond their native size.  Assigning `scale=1` (or any
    -- other value) will fix the image at the given size.  This means `rtk.scale` is
    -- also ignored when the `scale` attribute is defined.
    --
    -- However, the `w` and `h`, and `maxw` and `maxh` attributes, if defined, will take
    -- precedence and override `scale`.  Similarly, if adding to a container and setting
    -- either @{rtk.Container.fillw|fillw} or @{rtk.Container.fillh|fillh} cell attributes
    -- to true will also override `scale`.
    --
    -- @type number|nil
    -- @meta read/write
    scale = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- The aspect ratio of the rendered image (default nil).
    --
    -- By default (nil), the image's native aspect ratio is used.  The drawn aspect
    -- ratio can be overridden by setting this attribute.
    --
    -- If both `w` and `h` are defined, the aspect ratio dictated by those attributes will
    -- override `aspect`. Likewise, if both @{rtk.Container.fillw|fillw} and
    -- @{rtk.Container.fillh|fillh} cell attributes are set to true, the aspect will be
    -- overridden.  However if only one of these is set, the aspect ratio will be
    -- preserved.
    --
    -- @type number|nil
    -- @meta read/write
    aspect = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_FULL,
    },
}

function rtk.ImageBox:initialize(attrs, ...)
    rtk.Widget.initialize(self, attrs, self.class.attributes.defaults, ...)
end

function rtk.ImageBox:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, rescale, viewport, window)
    local calc = self.calc
    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp = self:_get_content_size(
        boxw, boxh,
        fillw, fillh,
        clampw, clamph,
        self.scale or 1
    )
    local dstw, dsth = 0, 0
    local hpadding = lp + rp
    local vpadding = tp + bp
    local image = calc.image
    if image then
        if rescale then
            image:refresh_scale()
        end
        local scale = (self.scale or 1) * rtk.scale.value / image.density
        local native_aspect = image.w / image.h
        local aspect = calc.aspect or native_aspect
        dstw = w or (fillw and (boxw - hpadding))
        dsth = h or (fillh and (boxh - vpadding))

        -- We'll constrain the target image to the bounding box the if scale hasn't been forced
        -- and we have flexibility in one of the dimensions to resize to maintain aspect.
        local constrain = self.scale == nil and not w and not h
        if dstw and not dsth then
            -- We use the box width as the basis to calculate aspect-preserved height only when
            -- height isn't clamped.
            dsth = math.min(clamph and boxw or math.inf, dstw) / aspect
        elseif not dstw and dsth then
            -- Similar to above, use box height only if width isn't clamped.
            dstw = math.min(clampw and boxh or math.inf, dsth) * aspect
        elseif not dstw and not dsth then
            -- Widget does not request specific width or height so use intrinsic size.
            dstw = image.w * scale / (native_aspect / aspect)
            dsth = image.h * scale
        end
        if constrain then
            if dstw + hpadding > boxw then
                dstw = boxw - hpadding
                dsth = dstw / aspect
            end
            if dsth + vpadding > boxh then
                dsth = boxh - vpadding
                dstw = dsth * aspect
            end
        end
        self.iscale = dstw / image.w

        -- Write out as the calculated variants the actual aspect and image scale we
        -- arrived at.
        calc.aspect = aspect
        calc.scale = self.iscale
    else
        -- No image defined.
        self.iscale = 1.0
    end
    -- Image dimensions (sans padding), which may overflow the box.
    self.iw = math.round(math.max(0, dstw))
    self.ih = math.round(math.max(0, dsth))

    -- Images support clipping, so we respect our bounding box when clamping is requested.
    calc.w = (fillw and boxw) or math.min(clampw and boxw or math.inf, self.iw + hpadding)
    calc.h = (fillh and boxh) or math.min(clamph and boxh or math.inf, self.ih + vpadding)
    -- Finally, apply min/max and round to ensure alignment to pixel boundaries.
    calc.w = math.round(rtk.clamp(calc.w, self.minw, self.maxw))
    calc.h = math.round(rtk.clamp(calc.h, self.minh, self.maxh))
end

-- Precalculate positions for _draw()
function rtk.ImageBox:_realize_geometry()
    local calc = self.calc
    local tp, rp, bp, lp = self:_get_padding_and_border()
    local ix, iy
    if calc.halign == rtk.Widget.LEFT then
        ix = lp
    elseif calc.halign == rtk.Widget.CENTER then
        ix = lp + math.max(0, calc.w - self.iw - lp - rp) / 2
    elseif calc.halign == rtk.Widget.RIGHT then
        ix = math.max(0, calc.w - self.iw - rp)
    end
    if calc.valign == rtk.Widget.TOP then
        iy = tp
    elseif calc.valign == rtk.Widget.CENTER then
        iy = tp + math.max(0, calc.h - self.ih - tp - bp) / 2
    elseif calc.valign == rtk.Widget.BOTTOM then
        iy = math.max(0, calc.h - self.ih - bp)
    end
    self._pre = {ix=ix, iy=iy}
end

function rtk.ImageBox:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    local x, y = calc.x + offx, calc.y + offy

    if not self.image or y + calc.h < 0 or y > cliph or calc.ghost then
        -- Widget would not be visible on current drawing target
        return
    end

    local pre = self._pre
    self:_handle_drawpre(offx, offy, alpha, event)
    self:_draw_bg(offx, offy, alpha, event)
    calc.image:blit{
        -- Destination pos
        dx=x + pre.ix, dy=y + pre.iy,
        -- Destination dimensions
        dw=self.iw, dh=self.ih,
        alpha=calc.alpha * alpha,
        -- Clip
        clipw=calc.w,
        cliph=calc.h,
    }
    self:_draw_borders(offx, offy, alpha)
    self:_handle_draw(offx, offy, alpha, event)
end