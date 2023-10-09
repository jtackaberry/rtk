-- Copyright 2022-2023 Jason Tackaberry
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

--- @warning Horizontal only
--   Vertical orientation sliders are not yet implemented. This will come in a future release.
--   If this is important to you, please chime in on the
--   [GitHub issue](https://github.com/jtackaberry/rtk/issues/16).
--
--- The slider widget is useful for inputting numeric values.
--
-- `rtk.Slider` supports both continuous and discrete modes (depending on whether `step`
-- is defined), with optional ticks and tick labels.
--
-- @code
--   somebox:add(rtk.Slider())
--
-- ![](../img/slider.gif)
--
-- Sliders can be made discrete via the `step` attribute, and tick marks can be enabled
-- using the `ticks` attribute:
--
-- @code
--   somebox:add(rtk.Slider{step=10, ticks=true})
--
-- ![](../img/slider-ticks.gif)
--
-- Ticks positions can also be labeled:
--
-- @code
--   somebox:add(rtk.Slider{step=1, ticks=true, min=1, max=3, ticklabels={'Low', 'Medium', 'High'}})
--
-- ![](../img/slider-labels.gif)
--
-- If you want labels on either end of the slider, it's easy enough to place it in an
-- `rtk.HBox` with `rtk.Text` instances for labels.  This example also shows that the
-- slider `color` can be changed, and its `value` initialized:
--
-- @code
--   local hbox = somebox:add(rtk.HBox{spacing=5, valign='center'})
--   hbox:add(rtk.Text{'0%'})
--   hbox:add(rtk.Slider{color='crimson', value=67})
--   hbox:add(rtk.Text{'100%'})
--
-- ![](../img/slider-end-labels.png)
--
-- Sliders may contain arbitrarily many thumbs, by passing a table of values as the `value`
-- attribute, rather than a scalar.  This is commonly used to implement range sliders.  Here's
-- a more complete example showing a range slider with labels on either end, all packed into
-- an `rtk.HBox`, and updating the labels based on current slider values.  Note here we must
-- use a fixed-width `rtk.Text` to ensure the slider size doesn't shift around as the value
-- changes:
--
-- @code
--   local hbox = somebox:add(rtk.HBox{spacing=5, valign='center'})
--   local min = hbox:add(rtk.Text{'25', w=25})
--   local slider = hbox:add(rtk.Slider{value={25, 75}, step=1})
--   local max = hbox:add(rtk.Text{'75', w=25})
--   slider.onchange = function(self)
--       min:attr('text', self.value[1])
--       max:attr('text', self.value[2])
--   end
--
-- ![](../img/slider-range.gif)
--
--
-- @note Intrinsic size is greedy
--   Unlike most widgets whose @{geometry|intrinsic size} is based on some aspect of
--   of their attributes (for example, the intrinsic size of an `rtk.Text` widget is based
--   on the rendered size of its @{rtk.Text.text|text attribute}), sliders are naturally
--   greedy and will consume the full size of the box offered by their parents.  So a
--   horizontal slider will consume all remaining width available within its parent
--   container.  In other words, it always behaves as if the @{rtk.Container.fillw|fillw
--   cell attribute} has been set to true.
--
--   If you want to constrain this greediness, you can use the `maxw` attribute to
--   limit the upper bound of the slider's width.  Of course you also specify a
--   fixed width using the `w` attribute, but `maxw` is usually the better choice as
--   it allows the slider to shrink according to its parent.  And if you want to ensure
--   it can't shrink *too* much, you can use `minw`.
--
-- @class rtk.Slider
-- @inherits rtk.Widget
rtk.Slider = rtk.class('rtk.Slider', rtk.Widget)

--- Tick Constants.
--
-- Used with the `ticks` attribute, where lowercase versions of these constants without
-- the `TICKS_` prefix can be used for convenience.
--
-- @section tickconst
-- @compact

--- Never display tick marks
-- @meta 'never'
rtk.Slider.static.TICKS_NEVER = 0
--- Always display tick marks (requires `step` to be defined)
-- @meta 'always'
rtk.Slider.static.TICKS_ALWAYS = 1
--- Only display tick marks when the user is actively moving a slider thumb by mouse
-- (requires `step` to be defined)
-- @meta 'when-active'
rtk.Slider.static.TICKS_WHEN_ACTIVE = 2

--- Class API.
--- @section api
rtk.Slider.register{
    [1] = rtk.Attribute{alias='value'},

    --- The current value of the slider, between `min` and `max` (default 0).
    --
    -- Multiple slider thumbs can be created by setting this value to a table of values,
    -- rather than a single scalar value.  Arbitrarily many thumb values may be specified
    -- here, but a common use case is to specify two thumbs to implement a range slider.
    --
    -- This attribute may be passed as the first positional argument during initialization. (In
    -- other words, `rtk.Slider{42}` is equivalent to `rtk.Slider{value=42}`.)
    --
    -- The @{rtk.Widget.calc|calculated version} of this attribute is always a table,
    -- even when you pass a scalar value.
    --
    -- @type number|table
    -- @meta read/write
    value = rtk.Attribute{
        default=0,
        -- Ensure min/max attrs are calculated first as we depend on them.
        priority=true,
        reflow=rtk.Widget.REFLOW_NONE,
        calculate=function(self, attr, value, target)
            return type(value) == 'table' and value or {value}
        end,
        set=function(self, attr, value, calculated, target)
            self._use_scalar_value = type(value) ~= 'table'
            for i = 1, #calculated do
                calculated[i] = rtk.clamp(tonumber(calculated[i]), target.min, target.max)
                if not self._thumbs[i] then
                    self._thumbs[i] = {idx=i, radius=0, radius_target=0}
                end
            end
            for i = #calculated + 1, #self._thumbs do
                self._thumbs[i] = nil
            end
            target.value = calculated
        end
    },

    --- Overall slider color, affecting the thumb (unless overridden by `thumbcolor`) plus
    -- the active portion drawn over the track, which uses the theme's
    -- @{rtk.themes.slider|`slider`} value by default.
    --
    -- @type colortype|nil
    -- @meta read/write
    color = rtk.Attribute{
        type='color',
        default=function(self, attr)
            return rtk.theme.slider
        end,
        calculate=rtk.Reference('bg'),
    },

    --- Track color along which the thumbs are dragged, which uses the theme's
    -- @{rtk.themes.slider_track|`slider_track`} value by default.
    --
    -- @type colortype|nil
    -- @meta read/write
    trackcolor = rtk.Attribute{
        type='color',
        default=function(self, attr)
            return rtk.theme.slider_track
        end,
        calculate=rtk.Reference('bg'),
    },

    --- The radius of the circular slider thumb (default 6).
    --
    -- @type number
    -- @meta read/write
    thumbsize = rtk.Attribute{
        default=6,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- The color of thumb handles, which defaults to `color`.
    --
    -- @type colortype|nil
    -- @meta read/write
    thumbcolor = rtk.Attribute{
        type='color',
    },

    --- When `step` is defined, this is an optional table of strings to be displayed next
    -- to each tick mark (default nil).  The labels provided are mapped in index order.
    -- `ticks` may be disabled -- labels will still be drawn at the tick positions -- but
    -- this attribute is ignored if `step` is nil.
    --
    -- @type table
    -- @meta read/write
    ticklabels = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- The color of the labels written next to ticks when `ticklabels` is defined, which
    -- defaults to the theme's @{rtk.themes.slider_tick_label|`slider_tick_label`} value.
    --
    -- @type colortype|nil
    -- @meta read/write
    ticklabelcolor = rtk.Attribute {
        type='color',
        default=function(self, attr)
            return rtk.theme.slider_tick_label or rtk.theme.text
        end,
    },

    --- The amount of additional space between ticks and `ticklabels` (default 2).
    --
    -- @type number
    -- @meta read/write
    spacing = rtk.Attribute{
        default=2,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- Controls whether and how ticks should be displayed when `step` is defined (default
    -- @{rtk.Slider.TICKS_NEVER|TICKS_NEVER}).
    --
    -- For convenience, a boolean value can also be provided, where false is
    -- @{rtk.Slider.TICKS_NEVER|TICKS_NEVER} and true is @{rtk.Slider.TICKS_ALWAYS|TICKS_ALWAYS}.
    --
    -- @type tickconst|bool
    -- @meta read/write
    ticks = rtk.Attribute{
        default=rtk.Slider.TICKS_NEVER,
        calculate={
            never=rtk.Slider.TICKS_NEVER,
            always=rtk.Slider.TICKS_ALWAYS,
            ['when-active']=rtk.Slider.TICKS_WHEN_ACTIVE,
            ['false']=rtk.Slider.TICKS_NEVER,
            [false]=rtk.Slider.TICKS_NEVER,
            ['true']=rtk.Slider.TICKS_ALWAYS,
            [true]=rtk.Slider.TICKS_ALWAYS,
        },
        set=function(self, attr, value, calculated, target)
            self._tick_alpha = calculated == rtk.Slider.TICKS_ALWAYS and 1 or 0
            target.ticks = calculated
        end,
    },

    --- The size of the square tick marks when `ticks` is enabled (default 4).
    --
    -- @type number
    -- @meta read/write
    ticksize = rtk.Attribute{
        default=4,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- The size of the slider track (default 2).
    --
    -- @type number
    -- @meta read/write
    tracksize = rtk.Attribute{
        default=2,
        reflow=rtk.Widget.REFLOW_FULL,
    },

    --- The minimum allowed value of any thumb in the slider (default 0).  Thumb
    -- values will be clamped to this minimum value.
    --
    -- @type number
    -- @meta read/write
    min = 0,

    --- The minimum allowed value of any thumb in the slider (default 100).  Thumb
    -- values will be clamped to this minimum value.
    --
    -- @type number
    -- @meta read/write
    max = 100,

    --- Snaps slider thumb values to discrete step boundaries (default nil).
    -- When disabled (nil), the thumb values are continuous.
    --
    -- @type number|nil
    -- @meta read/write
    step = rtk.Attribute{
        type='number',
        calculate=function(self, attr, value, target)
            -- Ensure zero values are calculated as nil
            return value and value > 0 and value
        end,
    },

    --- The name of the font face (e.g. `'Calibri`') for all labels, which uses the
    -- @{rtk.themes.slider_font|global slider font} by default.
    --
    -- @type string|nil
    -- @meta read/write
    font = rtk.Attribute{
        default=function(self, attr)
            return self._theme_font[1]
        end,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- The pixel size of the slider font (e.g. 18) for all labels, which uses the
    -- @{rtk.themes.slider_font|global slider font size} by default.
    --
    -- @type number|nil
    -- @meta read/write
    fontsize = rtk.Attribute{
        default=function(self, attr)
            return self._theme_font[2]
        end,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- Scales all font sizes by the given multiplier (default 1.0). This is a convenient
    -- way to adjust the relative font size without specifying the exact size.
    --
    -- @type number
    -- @meta read/write
    fontscale = rtk.Attribute{
        default=1.0,
        reflow=rtk.Widget.REFLOW_FULL
    },
    --- A bitmap of @{rtk.font|font flags} to alter the label appearance (default nil). Nil
    -- (or 0) does not style the font.
    --
    -- @type number|nil
    -- @meta read/write
    fontflags = rtk.Attribute{
        default=function(self, attr)
            return self._theme_font[3]
        end
    },

    focused_thumb_index = 1,

    -- Overides from rtk.Widget
    --
    autofocus = true,
    scroll_on_drag = false,
}

function rtk.Slider:initialize(attrs, ...)
    -- Array of slider thumbs, where each index holds a table containing the
    -- thumb's details:
    --   pos: number of pixels offset from left edge of slider (recalculated on reflow)
    --   radius: current hover radius in pixels
    --   value: value that was used to calculate pos
    self._thumbs = {}
    -- Current alpha of ticks for animation
    self._tick_alpha = 0
    -- Index of the currently hovering thumb.
    self._hovering_thumb = nil
    self._font = rtk.Font()
    self._theme_font = rtk.theme.slider_font or rtk.theme.default_font
    rtk.Widget.initialize(self, attrs, rtk.Slider.attributes.defaults, ...)
end

function rtk.Slider:_handle_attr(attr, value, oldval, trigger, reflow, sync)
    local ok = rtk.Widget._handle_attr(self, attr, value, oldval, trigger, reflow, sync)
    if ok == false then
        return ok
    end
    if attr == 'value' then
        -- XXX: should we animate the value if not syncing?  If so, need to be careful
        -- about changes to value's scalarness.
        self:onchange()
    elseif self._label_segments and attr == 'ticklabels' then
        -- Force regeneration of label segments on next reflow
        self._label_segments = nil
    end
end


function rtk.Slider:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    local calc = self.calc
    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp, minw, maxw, minh, maxh = self:_get_content_size(
        boxw, boxh, fillw, fillh, clampw, clamph, nil, greedyw, greedyh
    )
    local hpadding = lp + rp
    local vpadding = tp + bp
    local lh = 0
    local segments = self._label_segments

    self._font:set(calc.font, calc.fontsize, calc.fontscale, calc.fontflags)

    -- Use the first tick label as a proxy for all labels when testing for validity.
    if calc.step and calc.ticklabels and (not segments or not segments[1].isvalid()) then
        local lmaxw = (clampw or (fillw and greedyw)) and (boxw - hpadding) or w or math.inf
        local lmaxh = (clamph or (fillh and greedyh)) and (boxh - vpadding) or h or math.inf
        segments = {}
        -- Avoid ipairs() so we can handle nil elements
        for n=1, #calc.ticklabels do
            local label = calc.ticklabels[n] or ''
            local s, w, h = self._font:layout(
                label,
                lmaxw,
                lmaxh,
                false,
                rtk.Widget.CENTER,
                true,
                0,
                false
            )
            -- Remember the total w/h for _realize_geometry()
            s.w = w
            s.h = h
            segments[#segments+1] = s
            lh = math.max(h, lh)
        end
        lh = lh + calc.spacing
        self._label_segments = segments
    end
    self.lh = lh

    -- Enusre the slider is at least big enough to fit the thumbs
    minw = math.max(minw or 0, math.max(calc.minw or 0, #calc.value * calc.thumbsize*2) * rtk.scale.value)
    minh = math.max(minh or 0, math.max(calc.minh or 0, calc.thumbsize*2, calc.tracksize) * rtk.scale.value)
    -- Intrinsic size
    local size = math.max(calc.thumbsize * 2, calc.ticksize, calc.tracksize) * rtk.scale.value
    -- Sliders are intrinsically greedy and fill their bounding box unless explicitly
    -- constrained with a fixed dimension.  However if greedyw/h is false, it means we're
    -- autosizing and so we don't want to automatically consume the box in that dimension.
    -- In that case we fall back to *some* kind of reasonable fixed size.
    calc.w = w and (w + hpadding) or (greedyw and boxw or 50)
    calc.h = h and (h + vpadding) or (size + self.lh + vpadding)
    -- Finally, apply min/max and round to ensure alignment to pixel boundaries.
    calc.w = math.ceil(rtk.clamp(calc.w, minw, maxw))
    calc.h = math.ceil(rtk.clamp(calc.h, minh, maxh))
    -- If there's no explicit width then here we indicate that we have consumed
    -- fillw.  TODO: needs adjustment when vertical slider support is added.
    return not w, false
end

-- Precalculate positions for _draw()
function rtk.Slider:_realize_geometry()
    local calc = self.calc
    local tp, rp, bp, lp = self:_get_padding_and_border()
    local scale = rtk.scale.value
    -- Calculate geometry for the track
    local track = {
        x = calc.x + lp + calc.thumbsize*scale,
        y = calc.y + tp + ((calc.h - tp - bp - self.lh) - calc.tracksize*scale)/2,
        w = calc.w - lp - rp - calc.thumbsize*2*scale,
        h = calc.tracksize * scale,
    }
    local ticks
    if calc.step then
        ticks = {
            distance = track.w / ((calc.max - calc.min) / calc.step),
            size = calc.ticksize * scale,
        }
        ticks.offset = (ticks.size - track.h) / 2
        -- ticks.distance can be fractional, so the extra 1 is just to ensure we safely
        -- include the final tick.
        for x = track.x, track.x + track.w + 1, ticks.distance do
            ticks[#ticks+1] = {x - ticks.offset, track.y - ticks.offset}
        end
        if calc.ticklabels then
            local ly = track.y + calc.tracksize + (calc.spacing + calc.thumbsize)*scale
            for n, segments in ipairs(self._label_segments) do
                local tick = ticks[n]
                if not tick then
                    break
                end
                -- Start left-aligned relative to the tick
                segments.x = tick[1]
                local offset = segments.w - ticks.size
                if n == #ticks then
                    -- If it's the last tick label, right-align it.
                    segments.x = segments.x - offset
                elseif n > 1 then
                    -- All others are centered relative to the tick
                    segments.x = segments.x - offset/2
                end
                segments.y = ly
            end
        end
    end

    self._pre = {
        tp=tp, rp=rp, bp=bp, lp=lp,
        track=track,
        ticks=ticks,
    }

    -- Invalidate per-thumb cached value to ensure coordinates are recalculated on
    -- next _get_thumb().
    for idx = 1, #self._thumbs do
        self._thumbs[idx].value = nil
    end
end

function rtk.Slider:_get_thumb(idx)
    assert(self._pre, '_get_thumb() called before reflow')
    local thumb = self._thumbs[idx]
    local track = self._pre.track
    local calc = self.calc
    -- Don't use calculated() here because we want to calculate pos based on
    -- animating values.
    local value = calc.value[idx]
    if thumb.value ~= value then
        thumb.pos = track.w * (value - calc.min) / (calc.max - calc.min)
        thumb.value = value
    end
    -- But here we do use calculated() to compute the post-animation (if any) position of
    -- the value, which is used by handle_dragstart()
    local c = self:calc('value')
    if c ~= value then
        thumb.pos_final = track.w * (c[idx] - calc.min) / (calc.max - calc.min)
    else
        thumb.pos_final = thumb.pos
    end
    return thumb
end

-- Returns the thumb nearest to the given client coordinates.
function rtk.Slider:_get_nearest_thumb(clientx, clienty)
    local trackx = self.clientx + self._pre.lp
    local tracky = self.clienty + self._pre.tp
    local candidate = nil
    local candidate_distance = nil
    for i = 1, #self._thumbs do
        local thumb = self:_get_thumb(i)
        local delta = clientx - trackx - thumb.pos
        local distance = math.abs(delta)
        -- If there are multiple thumbs at the same distance, only take later thumbs if
        -- the mouse click is on the right side (delta > 0).
        if not candidate or (distance < candidate_distance) or (distance == candidate_distance and delta > 0) then
            candidate = thumb
            candidate_distance = distance
        end
    end
    return candidate
end

function rtk.Slider:_clamp_value_to_step(v)
    local calc = self.calc
    local step = calc.step
    return rtk.clamp(step and (math.round(v / step) * step) or v, calc.min, calc.max)
end

function rtk.Slider:_set_thumb_value(thumbidx, value, animate, fast)
    value = self:_clamp_value_to_step(value)
    -- calc() ensures we return the dst value if any animation is active, which
    -- could be for another thumb.
    local current = self:calc('value')
    if current[thumbidx] == value then
        -- Target value for thumb didn't actually change.
        return false
    end
    local newval = self._use_scalar_value and value or table.shallow_copy(current, {[thumbidx] = value})

    if animate == false then
        self:cancel_animation('value')
        self:sync('value', newval)
    else
        -- We're going to be animating toward newval, so for sync we explicitly set the
        -- calculated value to be the current calculated value, otherwise we would end up
        -- jumping to the end of the animation in the first frame.
        self:sync('value', newval, current)
        local duration = fast and 0.25 or 0.4
        -- Explicitly set doneval here to ensure we preserve the scalarness of the
        -- specified 'value' attr.  Otherwise animate() would end up calling value's
        -- calculate() and will get back a table.
        self:animate{'value', dst=newval, doneval=newval, duration=duration, easing='out-expo'}
    end
    return true
end


function rtk.Slider:_set_thumb_value_with_crossover(idx, value, animate, event)
    local newidx
    local calc = self.calc
    -- Hand off to adjacent thumbs if crossing their value thresholds.
    if idx > 1 and value < calc.value[idx - 1] then
        newidx = idx - 1
    elseif idx < #self._thumbs and value > calc.value[idx + 1] then
        newidx = idx + 1
    end
    if newidx then
        self:_set_thumb_value(idx, calc.value[newidx], false)
        self.focused_thumb_index = newidx
        self._hovering_thumb = newidx
        self:_animate_thumb_overlays(event, nil, true)
    end
    local changed = self:_set_thumb_value(self.focused_thumb_index, value, animate, event.type ~= rtk.Event.KEY)
    return changed, self.focused_thumb_index
end


function rtk.Slider:_is_mouse_over(clparentx, clparenty, event)
    if not self.window or not self.window.in_window then
        -- When mouse cursor leaves window ensure we animate out.
        self._hovering_thumb = nil
        return false
    end
    local calc = self.calc
    local pre = self._pre
    local y = calc.y + clparenty + pre.tp
    local track = pre.track
    local trackx = track.x + clparentx
    local tracky = track.y + clparenty
    local radius = 20 * rtk.scale.value
    -- If a thumb is currently being pressed, ensure we don't override the hovering thumb
    -- index.
    if not event:is_widget_pressed(self) then
        -- The index of the thumb that we're hovering near, if any.
        self._hovering_thumb = nil
        -- We need to iterate over all thumbs and test whether the mouse is within the
        -- extended hover radius, but before we do that, first do the cheaper box test,
        -- which saves us from the costly loop in the common case when the mouse isn't
        -- near the slider.
        if rtk.point_in_box(event.x, event.y, trackx - radius, y - radius, calc.w + radius*2, calc.h + radius*2) then
            -- Mouse is close enough to the slider that we need to check each thumb.
            for i = 1, #self._thumbs do
                local thumb = self:_get_thumb(i)
                if rtk.point_in_circle(event.x, event.y, trackx + thumb.pos, tracky, radius) then
                    self._hovering_thumb = i
                    break
                end
            end
        else
            -- If the mouse isn't in the wider box, it obviously isn't in the smaller box we'll
            -- be testing later.
            return false
        end
    end
    return self._hovering_thumb or
           -- Not hovering over a thumb, now check if we're hovering over the track, with
           -- the height extended by the thumb diamater so we have a more accessible click
           -- area.
           rtk.point_in_box(event.x, event.y, trackx, y - calc.thumbsize, calc.w, calc.h + calc.thumbsize*2)
end

function rtk.Slider:_handle_mouseleave(event)
    local ok = rtk.Widget._handle_mouseleave(self, event)
    if ok == false then
        return ok
    end
    self:_animate_thumb_overlays(event)
    return ok
end

function rtk.Slider:_handle_mousedown(event)
    local ok = rtk.Widget._handle_mousedown(self, event)
    if ok == false then
        return ok
    end
    local thumb = self:_get_nearest_thumb(event.x, event.y)
    self.focused_thumb_index = thumb.idx
    if not self._hovering_thumb then
        local value = self:_get_value_from_offset(event.x - self.clientx - self.calc.thumbsize)
        self:_set_thumb_value(thumb.idx, value, true, true)
    else
        -- Ensure we replace the hovering thumb with the one we've just activated.
        self._hovering_thumb = thumb.idx
    end
    self:_animate_thumb_overlays(event)
    self:_animate_ticks(true)
    return true
end

function rtk.Slider:_handle_mouseup(event)
    local ok = rtk.Widget._handle_mouseup(self, event)
    self:_animate_thumb_overlays(event, nil, true)
    self:_animate_ticks(false)
    return ok
end

function rtk.Slider:_handle_dragstart(event, x, y, t)
    local draggable, droppable = self:ondragstart(self, event, x, y, t)
    if draggable ~= nil then
        return draggable, droppable
    end
    local thumb = self:_get_nearest_thumb(x, y)
    self.focused_thumb_index = thumb.idx
    self:_animate_thumb_overlays(event, nil, true)
    return {startx=x, starty=y, thumbidx=thumb.idx}, false
end

function rtk.Slider:_handle_dragmousemove(event, arg)
    local ok = rtk.Widget._handle_dragmousemove(self, event)
    if ok == false or event.simulated then
        return ok
    end
    if not arg.startpos then
        -- Set starting position based on the calculated position of the thumb after any
        -- in-flight animation.  We fetch this value now rather than in
        -- _handle_dragstart() because when touch scrolling is enabled, mousedown is
        -- deferred and fired *after* dragstart returns a truthy value.  Since mousedown
        -- can cause the thumb position to change, and is done so after dragstart, we need
        -- to wait until dragmousemove to get the position.
        local thumb = self:_get_thumb(arg.thumbidx)
        arg.startpos = thumb.pos_final
    end
    local offx = (event.x - arg.startx)
    if arg.fine then
        offx = math.ceil(offx * 0.2)
    end
    local v = self:_get_value_from_offset(offx + arg.startpos)
    local value_changed
    value_changed, arg.thumbidx = self:_set_thumb_value_with_crossover(arg.thumbidx, v, self.calc.step ~= nil, event)
    if (event.shift and value_changed) or (event.shift ~= arg.fine) then
        arg.startx = event.x
        arg.starty = event.y
        -- Ensure start position is recalculated on next event.
        arg.startpos = nil
    end
    arg.fine = event.shift
    event:set_handled(self)
    return true
end

function rtk.Slider:_handle_dragend(event, dragarg)
    self:_animate_ticks(false)
end

function rtk.Slider:_handle_mousemove(event)
    self:_animate_thumb_overlays(event)
end

function rtk.Slider:_handle_focus(event, context)
    self:_animate_thumb_overlays(event, true)
    return rtk.Widget._handle_focus(self, event, context)
end

function rtk.Slider:_handle_blur(event, other)
    self._hovering_thumb = nil
    self:_animate_thumb_overlays(event, false)
    return rtk.Widget._handle_blur(self, event, other)
end

function rtk.Slider:_handle_keypress(event)
    local ok = rtk.Widget._handle_keypress(self, event)
    if ok == false or not self.focused_thumb_index then
        return ok
    end
    local calc = self.calc
    local value = calc.value[self.focused_thumb_index]
    local step = calc.step or (calc.max - calc.min)/10
    if event.shift then
        step = step * 3
    elseif event.ctrl then
        step = step * 2
    end
    local newvalue
    if event.keycode == rtk.keycodes.LEFT or event.keycode == rtk.keycodes.DOWN then
        newvalue = value - step
    elseif event.keycode == rtk.keycodes.RIGHT or event.keycode == rtk.keycodes.UP then
        newvalue = value + step
    end
    if newvalue then
        self:_set_thumb_value_with_crossover(self.focused_thumb_index, newvalue, true, event)
    end
    return ok
end

function rtk.Slider:_animate_thumb_overlays(event, focused, force)
    if rtk.dnd.dragging and not force then
        return
    end
    if focused == nil then
        focused = self.window.is_focused and self:focused(event)
    end
    for i = 1, #self._thumbs do
        local dst = nil
        local thumb = self:_get_thumb(i)
        if focused and thumb.idx == self.focused_thumb_index then
            if event and event.buttons ~= 0 then
                dst = 32
            else
                dst = 20
            end
        elseif thumb.idx == self._hovering_thumb then
            dst = 20
        elseif thumb.radius_target > 0 then
            dst = 0
        end
        if dst ~= nil and dst ~= thumb.radius_target then
            thumb.radius_target = dst
            rtk.queue_animation{
                key=string.format('%s.thumb.%d.hover', self.id, thumb.idx),
                src=thumb.radius,
                dst=dst,
                duration=0.2,
                easing='out-sine',
                update=function(val)
                    thumb.radius = val
                    self:queue_draw()
                end,
            }
        end
    end
end

function rtk.Slider:_animate_ticks(on)
    local calc = self.calc
    if calc.step and calc.ticks == rtk.Slider.TICKS_WHEN_ACTIVE then
        local dst = on and 1 or 0
        rtk.queue_animation{
            key=string.format('%s.ticks', self.id),
            src=self._tick_alpha,
            dst=dst,
            duration=0.2,
            easing='out-sine',
            update=function(val)
                self._tick_alpha = val
                self:queue_draw()
            end,
        }
    else
        self._ticks_alpha = (calc.ticks == rtk.Slider.TICKS_ALWAYS) and 1 or 0
    end
end

function rtk.Slider:_get_value_from_offset(offx)
    local calc = self.calc
    local v = (offx * (calc.max - calc.min) / self._pre.track.w) + calc.min
    return self:_clamp_value_to_step(v)
end

function rtk.Slider:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    local y = calc.y + offy
    if y + calc.h < 0 or y > cliph or self.calc.ghost then
        -- Widget would not be visible on current drawing target
        return false
    end
    local scale = rtk.scale.value
    local pre = self._pre
    local track = pre.track
    local ticks = pre.ticks
    local trackx = track.x + offx
    local tracky = track.y + offy
    local thumby = tracky + (track.h/2)
    local tickalpha = 0.6 * self._tick_alpha * alpha * calc.alpha
    local drawticks = ticks and tickalpha > 0 and not calc.disabled

    self:_handle_drawpre(offx, offy, alpha, event)
    self:_draw_bg(offx, offy, alpha, event)

    self:setcolor(calc.trackcolor, alpha)
    gfx.rect(trackx, tracky, track.w, track.h, 1)

    local first_thumb_x, last_thumb_x
    if drawticks then
        first_thumb_x = trackx + self:_get_thumb(1).pos
        last_thumb_x = trackx + self:_get_thumb(#self._thumbs).pos
        self:setcolor('black', tickalpha)
        for i = 1, #ticks do
            local x, y = table.unpack(ticks[i])
            -- Draw ticks on the track outside the slider range, as we'll be drawing ticks
            -- over the active track segments later.
            if x < first_thumb_x or x > last_thumb_x then
                gfx.rect(offx + x, offy + y, ticks.size, ticks.size, 1)
            end
        end
    end
    -- We do two passes, the first to draw the active track segments with ticks overlaid
    -- (if enabled) plus the translucent thumb hover zones, and then another pass to draw
    -- the actual thumbs.  This is done as a second pass to ensure we draw over top any
    -- ticks, otherwise the target tick for a currently-animating thumb would abruptly
    -- vanish.
    local thumbs = {}
    local lastpos = 0
    for i = 1, #self._thumbs do
        local thumb = self:_get_thumb(i)
        local thumbx = trackx + thumb.pos
        if not calc.disabled then
            if #self._thumbs == 1 or i > 1 then
                local segmentw = thumb.pos - lastpos
                self:setcolor(calc.color, alpha)
                gfx.rect(trackx + lastpos, tracky, segmentw, track.h, 1)
                if drawticks then
                    self:setcolor('white', tickalpha)
                    -- Unless this is the first thumb we're drawing, start at the second tick
                    -- within this active track segment, otherwise we'll end up drawing an
                    -- active tick over a gutter tick.
                    for j = math.floor(lastpos / ticks.distance) + (i > 1 and 2 or 1), #ticks do
                        local x, y = table.unpack(ticks[j])
                        if x >= track.x + thumb.pos then
                            break
                        end
                        gfx.rect(offx + x, offy + y, ticks.size, ticks.size, 1)
                    end
                end
            end
            if thumb.radius > 0 then
                self:setcolor(calc.thumbcolor or calc.color, 0.25 * alpha)
                gfx.circle(thumbx, thumby, thumb.radius * scale, 1, 1)
            end
        end
        thumbs[#thumbs+1] = {thumbx, thumby}
        lastpos = thumb.pos
    end
    if not calc.disabled then
        self:setcolor(calc.thumbcolor or calc.color, alpha)
    end
    for i = 1, #thumbs do
        local pos = thumbs[i]
        gfx.circle(pos[1], pos[2], calc.thumbsize * scale, 1, 1)
    end
    if self._label_segments then
        if not calc.disabled then
            self:setcolor(calc.ticklabelcolor, alpha)
        end
        for n, segments in ipairs(self._label_segments) do
            if not segments.x then
                break
            end
            self._font:draw(segments, offx + segments.x, offy + segments.y)
        end
    end
    self:_draw_borders(offx, offy, alpha)
    self:_handle_draw(offx, offy, alpha, event)
end


--- Event Handlers.
--
-- See also @{widget.handlers|handlers for rtk.Widget}.
--
-- @section slider.handlers


--- Called when the slider value changes.
--
-- The `value` attribute reflects the current state.
--
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Slider:onchange() end
