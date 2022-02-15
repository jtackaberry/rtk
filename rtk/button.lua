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


--- Standard push button, supporting icon and/or label, with or without button surface.
--
-- @code
--   -- Creates a button with an icon from the path registered by
--   -- rtk.add_image_search_path() with the icon positioned to the right of the label.
--   local b = rtk.Button{icon='info', label='Hello world', iconpos='right'}
--   b.onclick = function()
--      -- Toggles between a circle and rectangular button when clicked.
--      b:attr('circular', not b.circular)
--   end
--   container:add(b)
--
-- @class rtk.Button
-- @inherits rtk.Widget
rtk.Button = rtk.class('rtk.Button', rtk.Widget)


--- Flat Constants.
--
-- Used with the `flat` attribute to control whether and how a raised button
-- surface will be drawn.
--
-- @section flatconst
-- @compact

--- The button surface is always drawn (alias of `false`)
-- @meta 'raised'
rtk.Button.static.RAISED = false

--- The button surface is not drawn when in its normal state, but *is* drawn when
-- the mouse hovers over or clicks the button (alias of `true`)
-- @meta 'flat'
rtk.Button.static.FLAT = true

--- Applies only when `tagged` is true, and causes only the label portion of the
-- button to be flat, while the the tag (button icon) is drawn with a raised surface.
-- However if the mouse hovers over the button or clicks it, the label is drawn raised.
-- @meta 'label'
rtk.Button.static.LABEL = 2


--- Class API
--- @section api
rtk.Button.register{
    [1] = rtk.Attribute{alias='label'},
    --- Optional text label for the button (default nil).  Can be combined with `icon`.
    --
    -- This attribute may be passed as the first positional argument during initialization.
    -- (In other words, `rtk.Button{'Foo'}` is equivalent to `rtk.Button{label='Foo'}`.)
    --
    -- ![](../img/button-label-only.png)
    -- @type string|nil
    -- @meta read/write
    label = rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},

    --- Optional icon for the button (default nil).  If a string is provided,
    -- `rtk.Image.icon()` will be called to fetch the image, otherwise an
    -- `rtk.Image` object can be used directly.
    --
    -- ![](../img/button-icon-only.png)
    --
    -- ![](../img/button-icon-and-label.png)
    -- @type rtk.Image|string|nil
    -- @meta read/write
    icon = rtk.Attribute{
        -- Ensure icon gets calculated after color, as calculated color value influences
        -- whether we use light or dark icons.
        priority=true,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=function(self, attr, value, target)
            if type(value) == 'string' then
                -- Icon is a stringified icon name, so use background color of icon to determine
                -- light vs dark icon style.
                local color = self.color
                -- If flat is enabled (and not just label only) then use the theme
                -- background color to determine icon style.
                if self.calc.flat == rtk.Button.FLAT then
                    -- TODO: if we really want to be clever, check to see if the icon needs to also
                    -- have a different style when the surface is drawn during mouseover.
                    color = rtk.theme.bg
                end
                local style = rtk.color.get_icon_style(color, rtk.theme.bg)
                if self.icon and self.icon.style == style then
                    -- Style didn't change
                    return self.icon
                end
                local img = rtk.Image.icon(value, style)
                if not img then
                    img = rtk.Image.make_placeholder_icon(24, 24, style)
                end
                return img
            else
                return value
            end
        end,
    },

    --- If true, wraps the label (if defined) to fit within the button's bounding box (default false).
    --
    -- ![](../img/button-wrapped-label.png)
    -- @type boolean
    -- @meta read/write
    wrap = rtk.Attribute{
        default=false,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- Button surface color, which defaults to the theme's @{rtk.themes.button|`button`} value if
    -- nil (default).
    --
    -- ![](../img/button-red-surface.png)
    -- @type colortype|nil
    -- @meta read/write
    color = rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.button
        end,
        calculate=function(self, attr, value, target)
            local color = rtk.Widget.attributes.bg.calculate(self, attr, value, target)
            -- Determine if it's dark or light, otherwise use the current theme.
            local luma = rtk.color.luma(color, rtk.theme.bg)
            local dark = luma < rtk.light_luma_threshold
            local theme = rtk.theme
            if dark ~= theme.dark then
                -- The current theme doesn't work for the given color luma.
                theme = dark and rtk.themes.dark or rtk.themes.light
            end
            self._theme = theme
            if not self.textcolor then
                -- Could be from another theme, so explicitly convert it to RGBA table
                target.textcolor = {rtk.color.rgba(theme.button_label)}
            end
            return color
        end,
    },

    --- Text color when label is drawn over button surface, where a nil value is adaptive
    -- based on `color` luminance (default nil).  If nil,
    -- @{rtk.themes.button_label|button_label} from the current theme will be used if it's
    -- compatible with the luma, otherwise @{rtk.themes.button_label|button_label} from
    -- either the built-in `light` or `dark` themes (depending on what's called for) will
    -- be used.
    -- @type colortype|nil
    -- @meta read/write
    textcolor = rtk.Attribute{
        -- We don't include a default for textcolor because we want to keep it as nil to
        -- enable the logic to assign textc olor based on button luma.
        default=nil,
        calculate=rtk.Reference('bg'),
    },

    --- Text color for `flat` buttons (when the label is not drawn over top a button surface),
    -- which defaults to current theme @{rtk.themes.text|text color} if nil (default)
    -- @type colortype|nil
    -- @meta read/write
    textcolor2 = rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.text
        end,
        calculate=rtk.Reference('bg'),
    },

    --- Whether the icon should be positioned to the left or right of the `label`
    -- (default @{rtk.Widget.LEFT|left}).  Values are as with `rtk.Widget.halign`
    -- but only @{rtk.Widget.LEFT|left} or @{rtk.Widget.LEFT|right} are supported.
    --
    -- ![](../img/button-icon-right.png)
    -- @type alignmentconst
    -- @meta read/write
    iconpos = rtk.Attribute{
        default=rtk.Widget.LEFT,
        calculate=rtk.Reference('halign'),
    },

    --- If true, draws the button with a "tagged" icon which is always anchored to the
    -- right or left of the button (depending on `iconpos`) and is drawn with a slightly
    -- darker surface compared to the label (default false).  If flat is true, only the
    -- label portion is flat until hovering or clicked.
    --
    -- Tagged buttons will always use the widget padding on both sides of the icon,
    -- depending on whether `iconpos` has the icon on the left or right of the button. If
    -- on the left, then the icon will use `lpadding` on either side.  If right, the icon
    -- will use `rpadding` on either side.  This ensures the icon is always visually
    -- centered.
    --
    -- For tagged buttons, since the icon is always anchored to the far edge, the `halign`
    -- attribute only controls the centering of the label within the label's portion of
    -- the button.  Meanwhile for untagged buttons, `halign` will adjust both icon and
    -- label position.
    --
    -- Tagged buttons require that both `icon` and `label` are set.
    --
    -- ![](../img/button-tagged.png)
    --
    -- ![](../img/button-tagged-icon-right.png)
    -- @type boolean
    -- @meta read/write
    tagged = false,

    --- If true, no raised button surface will be drawn underneath the icon and label unless
    -- the mouse is hovering over the button or clicking (default false).  If false, a surface
    -- is always rendered.  A special value `'label'` applies when `tagged` is true, where
    -- the button will render a flat label unless hovered/clicked.
    --
    -- ![](../img/button-tagged-flat-label.gif)
    --
    -- If you want to keep the surface but just want to get rid of the default gradient,
    -- use the `gradient` attribute instead and set it to 0.  Here, flat means something
    -- else.
    --
    -- @type flatconst|boolean|string
    -- @meta read/write
    flat = rtk.Attribute{
        default=rtk.Button.RAISED,
        calculate={
            raised=rtk.Button.RAISED,
            flat=rtk.Button.FLAT,
            label=rtk.Button.LABEL,
            [rtk.Attribute.NIL]=rtk.Button.RAISED,
        },
    },

    --- For `tagged` buttons, this is the the opacity of the black overlay that is
    -- drawn above the icon area (default is @{rtk.themes.button_tag_alpha|from the theme}).
    -- @type number
    -- @meta read/write
    tagalpha = nil,
    --- Whether button surfaces should ever be rendered at all, even when the mouse
    -- hovers over or clicks (default true).  False here implies that `flat` is true.
    --
    -- This is used by some widgets that implement button-like behavior even though
    -- they aren't buttons, such as `rtk.CheckBox`.
    -- @type boolean
    -- @meta read/write
    surface = true,

    --- For untagged buttons (`tagged` is false) this is the distance in pixels between the
    -- icon and the label, while for tagged buttons, it's the distance between the tag
    -- edge and the label edge (default 10).
    -- @type number
    -- @meta read/write
    spacing = rtk.Attribute{
        default=10,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- Multiplier for gradient on button surfaces (default 1). 1 means to use the
    -- @{rtk.themes.button_normal_gradient|default gradient from the theme}. Larger values
    -- increase the contrast of the gradient, while values less than 1 decrease the
    -- contrast of the gradient, where 0 is a completely flat color.  Negative values risk
    -- creating an irreparable rift in the fabric of spacetime, with repercussions analogous
    -- to taunting [Happy Fun Ball](https://www.youtube.com/watch?v=GmqeZl8OI2M).
    --
    -- You can also adjust this globally by setting @{rtk.themes.button_gradient_mul|button_gradient_mul}
    -- in the current theme by calling `rtk.set_theme_overrides()`.
    -- @type number
    -- @meta read/write
    gradient = 1,

    --- If true, this is an icon-only circular button (labels are not supported) (default false).
    --
    -- ![](../img/button-circular.png)
    -- @type boolean
    -- @meta read/write
    circular = rtk.Attribute{
        default=false,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- The elevation of the drop shadow for `circular` buttons with values 0-15 where 0 disables
    -- the shadow, 1 draws a sharper, smaller drop shadow and 15 draws a fainter, larger
    -- shadow (default 3).
    -- @type number
    -- @meta read/write
    elevation = rtk.Attribute{
        default=3,
        calculate=function(self, attr, value, target)
            return rtk.clamp(value, 0, 15)
        end
    },

    --- If true, always draws the button as if the mouse were hovering over it (default
    -- false).  Useful for programmatically indicating a focus or selection.
    -- @type boolean
    -- @meta read/write
    hover = false,

    --- The name of the font face (e.g. `'Calibri`'), which uses the @{rtk.themes.button_font|global button
    -- default} if nil (default nil).
    -- @type string|nil
    -- @meta read/write
    font = rtk.Attribute{
        default=function(self, attr)
            return self._theme_font[1]
        end,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- The pixel size of the button font (e.g. 18), which uses the @{rtk.themes.button_font|global button
    -- default} if nil (default nil).
    -- @type number|nil
    -- @meta read/write
    fontsize = rtk.Attribute{
        default=function(self, attr)
            return self._theme_font[2]
        end,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- Scales `fontsize` by the given multiplier (default 1.0). This is a convenient way to adjust
    -- the relative font size without specifying the exact size.
    -- @type number
    -- @meta read/write
    fontscale = rtk.Attribute{
        default=1.0,
        reflow=rtk.Widget.REFLOW_FULL
    },
    --- A bitmap of @{rtk.font|font flags} to alter the text appearance (default nil). Nil
    -- (or 0) does not style the font.
    -- @type number|nil
    -- @meta read/write
    fontflags = rtk.Attribute{
        default=function(self, attr)
            return self._theme_font[3]
        end
    },

    -- Overrides from rtk.Widget
    valign=rtk.Widget.CENTER,
    tpadding = 6,
    bpadding = 6,
    lpadding = 10,
    rpadding = 10,
    autofocus = true,
}

--- Create a new button with the given attributes.
--
-- @display rtk.Button
-- @treturn rtk.Button the new button widget
function rtk.Button:initialize(attrs, ...)
    self._theme = rtk.theme
    self._theme_font = self._theme_font or rtk.theme.button_font or rtk.theme.default_font
    rtk.Widget.initialize(self, attrs, self.class.attributes.defaults, ...)
    self._font = rtk.Font()
end

function rtk.Button:__tostring_info()
    return self.label or (self.icon and self.icon.path)
end

function rtk.Button:_handle_attr(attr, value, oldval, trigger, reflow, sync)
    local ret = rtk.Widget._handle_attr(self, attr, value, oldval, trigger, reflow, sync)
    if ret == false then
        return ret
    end
    if self._segments and (attr == 'wrap' or attr == 'label') then
        -- Force regeneration of segments on next reflow
        self._segments.invalid = true
    end
    if type(self.icon) == 'string' and (attr == 'color' or attr == 'label') then
        -- We're (potentially) changing the color but, because the user-provided attribute
        -- is a string it means we loaded the icon based on its name.  Recalculate the icon
        -- attr so that the light vs dark style gets recalculated based on this new new
        -- button color.
        self:attr('icon', self.icon, true)
    elseif attr == 'icon' and value then
        -- Ensure next reflow calls refresh_scale() on the icon.
        self._last_reflow_scale = nil
    end
    return ret
end

-- Returns the width, height, single-line height, and wrapped label.
--
-- The single-line height represents the height of the prewrapped label
-- when rendered with the current font.  This can be used for alignment
-- calculations.
function rtk.Button:_reflow_get_max_label_size(boxw, boxh)
    -- Avoid re-laying out the string if nothing relevant has changed.
    local calc = self.calc
    local seg = self._segments
    if seg and seg.boxw == boxw and seg.wrap == calc.wrap and not seg.invalid and rtk.scale.value == seg.scale then
        return self._segments, self.lw, self.lh
    else
        return self._font:layout(calc.label, boxw, boxh, calc.wrap)
    end
end

function rtk.Button:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window)
    local calc = self.calc
    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp = self:_get_content_size(boxw, boxh, fillw, fillh, clampw, clamph)

    local icon = calc.icon
    if icon and uiscale ~= self._last_reflow_scale then
        icon:refresh_scale()
        self._last_reflow_scale = uiscale
    end
    local scale = rtk.scale.value
    local iscale = scale / (icon and icon.density or 1.0)
    local iw, ih
    if calc.icon then
        iw = math.round(icon.w * iscale)
        ih = math.round(icon.h * iscale)
    else
        iw, ih = 0, 0
    end
    if calc.circular then
        local size = math.max(iw, ih)
        if w and not h then
            calc.w = w + lp + rp
        elseif h and not w then
            calc.w = h + tp + bp
        else
            calc.w = math.max(w or size, h or size) + lp + rp
        end
        calc.h = calc.w
        self._radius = (calc.w - 1) / 2
        if not self._shadow then
            self._shadow = rtk.Shadow()
        end
        self._shadow:set_circle(self._radius, calc.elevation)
        return
    end

    -- Rectangular button
    local spacing = 0
    local hpadding = lp + rp
    local vpadding = tp + bp
    if calc.label then
        -- Calculate the viewable portion of the label
        local lwmax = w or ((clampw or fillw) and (boxw - hpadding) or math.inf)
        local lhmax = h or ((clamph or fillh) and (boxh - vpadding) or math.inf)
        if icon then
            -- Both label and icon are specified.  Determine number of pixels used for
            -- spacing based on appearance.
            spacing = calc.spacing * scale
            if calc.tagged then
                -- Tagged icon is spaced based on position and left/right widget padding.
                -- Add that to the spacing amount.
                spacing = spacing + (calc.iconpos == rtk.Widget.LEFT and lp or rp)
            end
            -- Reduce the size of the allowed label based on icon size and spacing.
            lwmax = lwmax - (iw + spacing)
        end

        self._font:set(calc.font, calc.fontsize, calc.fontscale, calc.fontflags)
        self._segments, self.lw, self.lh = self:_reflow_get_max_label_size(lwmax, lhmax)
        -- Clamp label width to the label max calculated above as it respects the
        -- box size.  Even if we don't truncate the label during reflow, we can clip it
        -- during draw.
        self.lw = math.min(self.lw, lwmax)
        -- But we *don't* clamp label height as that will affect the calculation for
        -- vertical centering.  We use the full line height there, and rely on _draw()
        -- to clip it.

        if icon then
            -- Label and icon
            calc.w = w or (iw + spacing + self.lw)
            calc.h = h or math.max(ih, self.lh)
        else
            -- Label only
            calc.w = w or self.lw
            calc.h = h or self.lh
        end
    elseif icon then
        -- Icon only
        calc.w = w or iw
        calc.h = h or ih
    else
        -- Neither label nor icon -- not exactly useful.
        calc.w = 0
        calc.h = 0
    end
    -- Finally, apply min/max and round to ensure alignment to pixel boundaries.
    calc.w = math.round(rtk.clamp(calc.w + hpadding, calc.minw, calc.maxw))
    calc.h = math.round(rtk.clamp(calc.h + vpadding, calc.minh, calc.maxh))
end

-- Precalculate positions for _draw()
function rtk.Button:_realize_geometry()
    if self.circular then
        return
    end
    local calc = self.calc
    local tp, rp, bp, lp = self:_get_padding_and_border()

    -- Button surface geometry which defaults to the full size of the button, to
    -- be overridden below based on style attributes.
    local surx, sury = 0, 0
    local surw, surh = calc.surface and calc.w or 0, calc.h
    local label = calc.label
    local icon = calc.icon
    local scale = rtk.scale.value
    local iscale = scale / (icon and icon.density or 1.0)
    local spacing = calc.spacing * scale

    -- Tagged icon overlay x positionand width.
    local tagx, tagw = 0, 0
    -- Default x positions of the icon and label, both left-aligned after left
    -- padding.  They'll be adjusted below.
    local lx = lp
    local ix = lx

    local lw, lh
    if label then
        lw, lh = self._font:measure(label)
    end
    -- Now calculate geometry for surface, label, icon, and tag overlay based on the
    -- different style related attributes.
    --
    -- This code below is tedious and repetitive, but it has the more important benefit of
    -- being straightforward (well, relative to what it might be, anyway).  It's possible to
    -- make it less verbose and cleverer but then it becomes much harder to reason about.
    --
    -- So I'm preferring obviousness over terseness here.
    if icon and label then
        local iconwidth = icon.w * iscale
        if calc.iconpos == rtk.Widget.LEFT then
            -- Icon on the left
            if calc.tagged then
                -- Tagged icon.  Icon is already on the left, so we just need to
                -- align the label within the label area based on halign.
                tagw = lp + iconwidth + lp
                if calc.halign == rtk.Widget.LEFT then
                    lx = tagw + spacing
                elseif calc.halign == rtk.Widget.CENTER then
                    lx = tagw + math.max(0, (calc.w - tagw - lw)/2)
                else
                    lx = math.max(tagw + spacing, calc.w - rp - lw)
                end
            else
                -- Untagged icon.  Both label and icon need to be shifted with non-left
                -- alignment.
                local sz = lw + spacing + iconwidth
                if calc.halign == rtk.Widget.LEFT then
                    lx = lx + iconwidth + spacing
                elseif calc.halign == rtk.Widget.CENTER then
                    local offset = math.max(0, (calc.w - sz)/2)
                    ix = offset
                    lx = ix + iconwidth + spacing
                else
                    lx = calc.w - rp - lw
                    ix = lx - spacing - iconwidth
                    if ix < 0 then
                        -- Button width is too small, revert to left alignment semantics so that
                        -- the label gets truncated.
                        lx = lp + iconwidth + spacing
                        ix = lp
                    end
                end
            end
        else
            -- Icon on the right
            if calc.tagged then
                ix = calc.w - iconwidth - rp
                tagx = ix - rp
                tagw = rp + iconwidth + rp
                if calc.halign == rtk.Widget.CENTER then
                    lx = math.max(0, (calc.w - tagw - lw)/2)
                elseif calc.halign == rtk.Widget.RIGHT then
                    lx = math.max(lp, calc.w - lw - tagw - spacing)
                end
            else
                -- With non-tagged buttons, icon is to the right of the label, not on the
                -- right edge of the button.
                local sz = lw + spacing + iconwidth
                if calc.halign == rtk.Widget.LEFT then
                    ix = lx + lw + spacing
                elseif calc.halign == rtk.Widget.CENTER then
                    local offset = math.max(0, (calc.w - sz)/2)
                    lx = offset
                    ix = lx + spacing + lw
                else
                    ix = calc.w - rp - iconwidth
                    lx = math.max(lx, ix - spacing - lw)
                end
            end
        end
    else
        -- Either label or icon but not both.  They are currently positioned for
        -- left align, implement the other alignments.
        local sz = icon and (icon.w * iscale) or lw
        if calc.halign == rtk.Widget.CENTER then
            local offset = (calc.w - sz)/2
            lx = offset
        elseif calc.halign == rtk.Widget.RIGHT then
            lx = calc.w - rp - sz
        end
        -- Rather than testing to see which one (icon/label) is visible, just
        -- blindly set them both.
        ix = lx
    end

    -- Precalculate vertical icon position
    local iy
    if icon then
        if calc.valign == rtk.Widget.TOP then
            iy = sury + tp
        elseif calc.valign == rtk.Widget.CENTER then
            -- Center icon vertically according to calculated height, adjusting for padding.
            iy = sury + tp + math.max(0, calc.h - icon.h*iscale - tp - bp) / 2
        else
            -- Bottom
            iy = sury + math.max(0, calc.h - icon.h*iscale - bp)
        end
    end
    -- Vertical label position plus label clip rectangle
    local ly, clipw, cliph
    if label then
        if calc.valign == rtk.Widget.TOP then
            ly = sury + tp
        elseif calc.valign == rtk.Widget.CENTER then
            ly = sury + tp + math.max(0, calc.h - lh - tp - bp) / 2
        else
            -- Bottom
            ly = sury + math.max(0, calc.h - lh - bp)
        end
        clipw = calc.w - lx
        if calc.iconpos == rtk.Widget.RIGHT then
            -- Icon is on the right, so adjust clip width to subtract space for icon
            clipw = clipw - (tagw > 0 and tagw or (calc.w - ix + calc.spacing))
        end
        cliph = calc.h - ly
    end
    self._pre = {
        tp=tp, rp=rp, bp=bp, lp=lp,
        ix=ix, iy=iy,
        lx=lx, ly=ly, lw=lw, lh=lh,
        tagx=tagx, tagw=tagw,
        surx=surx, sury=sury, surw=surw or 0, surh=surh or 0,
        clipw=clipw, cliph=cliph,
        iw=icon and (icon.w*iscale),
        ih=icon and (icon.h*iscale),
    }
end


function rtk.Button:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    if calc.disabled then
        alpha = alpha * 0.5
    end
    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local x = calc.x + offx
    local y = calc.y + offy
    if y + calc.h < 0 or y > cliph or calc.ghost then
        -- Widget would not be visible on current drawing target
        return false
    end

    local hover = (self.hovering or calc.hover) and not calc.disabled
    local clicked = hover and event.buttons ~= 0 and self:focused() and self.window.is_focused
    local theme = self._theme
    local gradient, brightness, cmul, bmul
    if clicked then
        gradient = theme.button_clicked_gradient * theme.button_gradient_mul
        brightness = theme.button_clicked_brightness
        cmul = theme.button_clicked_mul
        bmul = theme.button_clicked_border_mul
    elseif hover then
        gradient = theme.button_hover_gradient * theme.button_gradient_mul
        brightness = theme.button_hover_brightness
        cmul = theme.button_hover_mul
        bmul = theme.button_hover_border_mul
    else
        gradient = theme.button_normal_gradient * theme.button_gradient_mul
        bmul = theme.button_normal_border_mul
        brightness = 1.0
        cmul = 1.0
    end
    self:_handle_drawpre(offx, offy, alpha, event)
    if self.circular then
        self:_draw_circular_button(x, y, hover, clicked, gradient, brightness, cmul, bmul, alpha)
    else
        self:_draw_rectangular_button(x, y, hover, clicked, gradient, brightness, cmul, bmul, alpha)
        self:_draw_borders(offx, offy, alpha)
    end
    self:_handle_draw(offx, offy, alpha, event)
end

function rtk.Button:_is_mouse_over(clparentx, clparenty, event)
    local calc = self.calc
    if calc.circular then
        local x = calc.x + clparentx + self._radius
        local y = calc.y + clparenty + self._radius
        return self.window and self.window.in_window and
               rtk.point_in_circle(event.x, event.y, x, y, self._radius)
    else
        return rtk.Widget._is_mouse_over(self, clparentx, clparenty, event)
    end
end

function rtk.Button:_draw_circular_button(x, y, hover, clicked, gradient, brightness, cmul, bmul, alpha)
    local calc = self.calc

    -- gfx.circle() draws outward from the center, circle coordinates are offset by radius.
    local radius = math.ceil(self._radius)
    local cirx = math.floor(x) + radius
    local ciry = math.floor(y) + radius
    local icon = calc.icon

    if calc.surface and (not calc.flat or hover or clicked) then
        if calc.elevation > 0 then
            self._shadow:draw(x+1, y+1)
        end
        local r, g, b, a = rtk.color.mod(calc.color, 1.0, 1.0, brightness)
        self:setcolor({r*cmul, g*cmul, b*cmul, a}, alpha)
        gfx.circle(cirx, ciry, radius, 1, 1)
    end
    if icon then
        local ix = (calc.w - (icon.w * rtk.scale.value))/2
        local iy = (calc.h - (icon.h * rtk.scale.value))/2
        self:_draw_icon(x + ix, y + iy, hover, alpha)
    end
    if calc.border then
        local color, thickness = table.unpack(calc.border)
        self:setcolor(color)
        -- Unfortunately this looks a bit janky.
        for i = 1, thickness do
            gfx.circle(cirx, ciry, radius - (i - 1), 0, 1)
        end
    end
end

function rtk.Button:_draw_rectangular_button(x, y, hover, clicked, gradient, brightness, cmul, bmul, alpha)
    local calc = self.calc
    local pre = self._pre
    local amul = calc.alpha * alpha

    -- Label color uses textcolor if it's over a surface, otherwise textcolor2
    local label_over_surface = calc.surface and (calc.flat == rtk.Button.RAISED or hover)
    local textcolor =  label_over_surface and calc.textcolor or calc.textcolor2
    -- Whether the any part of the surface needs to be drawn
    local draw_surface = label_over_surface or (calc.label and calc.tagged and calc.surface)

    local tagx = x + pre.tagx
    local surx = x + pre.surx
    local sury = y + pre.sury
    local surw = pre.surw
    local surh = pre.surh

    if calc.tagged and calc.flat == rtk.Button.LABEL and calc.surface and not hover then
        surx = tagx
        surw = pre.tagw
    end

    if surw > 0 and surh > 0 and draw_surface then
        local d = (gradient * calc.gradient) / calc.h
        -- Slight compensation of brightness based on degree of gradient, since the
        -- gradient can alter the overall perceived brightness of the source color.  This
        -- ensures the requested color is reached at the middle point of the button's
        -- height.
        local lmul = 1 - calc.h*d/2
        -- Surface
        local r, g, b, a = rtk.color.rgba(calc.color)
        local sr, sg, sb, sa = rtk.color.mod({r, g, b, a}, 1.0, 1.0, brightness * lmul, amul)
        gfx.gradrect(surx, sury, surw, surh, sr*cmul, sg*cmul, sb*cmul, sa*amul,  0, 0, 0, 0,   r*d, g*d, b*d, 0)
        -- Border
        gfx.set(r*bmul, g*bmul, b*bmul, amul)
        gfx.rect(surx, sury, surw, surh, 0)
        if pre.tagw > 0 and (hover or calc.flat ~= rtk.Button.LABEL) then
            local ta = 1 - (calc.tagalpha or self._theme.button_tag_alpha)
            self:setcolor({0, 0, 0, 1})
            gfx.muladdrect(tagx, sury, pre.tagw, surh, ta, ta, ta, 1.0)
        end
    elseif calc.bg then
        -- Flat icon with background defined, so paint a rectangle.
        self:setcolor(calc.bg)
        gfx.rect(x, y, calc.w, calc.h, 1)
    end
    if calc.icon then
        self:_draw_icon(x + pre.ix, y + pre.iy, hover, alpha)
    end
    if calc.label then
        self:setcolor(textcolor, alpha)
        self._font:draw(self._segments, x + pre.lx, y + pre.ly, pre.clipw, pre.cliph)
    end
end

function rtk.Button:_draw_icon(x, y, hovering, alpha)
    -- TODO: supporting clipping
    self.calc.icon:draw(x, y, self.calc.alpha * alpha, rtk.scale.value)
end