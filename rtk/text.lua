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

--- Displays arbitrary text which can be optionally wrapped (either to fit width constraints
-- imposed by the parent container or within the widget's own @{w|defined width}),
-- otherwise it's clipped (unless disabled by setting `overflow` to true).
--
-- @code
--   local hbox = rtk.HBox{spacing=5}
--   hbox:add(rtk.Text{'Name:'}, {valign='center'})
--   hbox:add(rtk.Entry())
--
-- Here's an example with a large block of center-aligned text that will wrap and scroll
-- within a viewport:
--
-- @code
--   local data = 'A big long block of text goes here ... pretend this is it.'
--   -- Comic Sans used ironically
--   local text = rtk.Text{data, halign='center', wrap=true, margin=10, font='Comic Sans MS'}
--   -- Constrain height to 100 pixels within which the wrapped text will scroll
--   box:add(rtk.Viewport{text, h=100})
--
-- @class rtk.Text
-- @inherits rtk.Widget
rtk.Text = rtk.class('rtk.Text', rtk.Widget)

--- Word Wrap Constants.
--
-- Used with the `wrap` attribute, where lowercase versions of these constants without the `WRAP_` prefix
-- can be used for convenience.
--
-- @section wrapconst
-- @compact

--- Don't wrap the text and instead allow the widget to overflow its bounding box.
-- @meta 'none'
rtk.Text.static.WRAP_NONE = false
--- Wrap the text at normal word-break boundaries (at whitespace or punctuation), and allow
-- long unbreakable words to overflow the bounding box.
-- @meta 'normal'
rtk.Text.static.WRAP_NORMAL = true
--- Wrap text as with `WRAP_NORMAL` but allow breaking in the middle of long words in order to
-- avoid overflowing the bounding box.
-- @meta 'break-word'
rtk.Text.static.WRAP_BREAK_WORD = 2

--- Class API.
--- @section api
rtk.Text.register{
    [1] = rtk.Attribute{alias='text'},
    --- The string of text to be displayed.
    --
    -- This attribute may be passed as the first positional argument during initialization. (In
    -- other words, `rtk.Text{'Foo'}` is equivalent to `rtk.Text{text='Foo'}`.)
    --
    -- Strings containing explicit newlines are rendered across multiple lines as you'd expect.
    -- @meta read/write
    -- @type string
    text = rtk.Attribute{
        default='Text',
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- The color of the text, which is adaptive if nil, using the @{rtk.themes.text|text} color
    -- defined in the dark theme if the underlying background has a low luminance, or the
    -- text color from the light theme if the background has a high luminance (default nil).
    -- @meta read/write
    -- @type colortype
    color = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_NONE,
        default=rtk.Attribute.NIL,
        calculate=function(self, attr, value, target)
            if not value then
                local parentbg = self.parent and self.parent.calc.bg
                local luma = rtk.color.luma(self.calc.bg, parentbg or rtk.theme.bg)
                value = rtk.themes[luma > rtk.light_luma_threshold and 'light' or 'dark'].text
            end
            return {rtk.color.rgba(value)}
        end,
    },
    --- Controls the wrapping behavior of text lines that exceed the bounding box imposed
    -- by our container (default `WRAP_NONE`).
    -- @meta read/write
    -- @type wrapconst
    wrap = rtk.Attribute{
        default=rtk.Text.WRAP_NONE,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate={
            ['none']=rtk.Text.WRAP_NONE,
            ['normal']=rtk.Text.WRAP_NORMAL,
            ['break-word']=rtk.Text.WRAP_BREAK_WORD
        },
    },
    --- How individual lines of text should be aligned within the widget's inner content area
    -- (defaults to match `halign`).  Any of the horizontal alignment constants are supported.
    --
    -- This is subtly different from `halign`. The internal laid out text has its own natural
    -- size based on the line contents, and `halign` controls the positioning of this inner
    -- content box within the overall `rtk.Text` widget's box.  In contrast, `textalign` controls
    -- the alignment of each individual line within the inner content box.
    --
    -- When `textalign` is not specified (i.e. is nil), then it uses the same value as for
    -- `halign` as a sane default behavior.
    --
    -- To demonstrate, consider:
    -- @code
    --   local text = 'This is\na few lines of\nshort text'
    --   -- Lines of text are right-aligned relative to itself, but centered within the
    --   -- overall rtk.Text box.
    --   vbox:add(rtk.Text{text, w=300, border='red', wrap=true, halign='center', textalign='right'})
    --   -- Lines of text are center-aligned relative to itself, but right-aligned within
    --   -- the overall rtk.Text box.
    --   vbox:add(rtk.Text{text, w=300, border='red', wrap=true, halign='right', textalign='center'})
    --   -- When textalign isn't specified, it uses the same value as halign, which
    --   -- simplifies the most common use case.
    --   vbox:add(rtk.Text{text, w=300, border='red', wrap=true, halign='center'})
    --
    -- Which results in the following:
    --
    -- ![](../img/text-textalign.png)
    --
    -- @meta read/write
    -- @type alignmentconst
    textalign = rtk.Attribute{
        default=nil,
        calculate=rtk.Reference('halign'),
    },

    --- Whether the text is allowed to overflow its bounding box, otherwise it will be clipped (default false,
    -- which will clip overflowed text).
    -- @meta read/write
    -- @type boolean
    overflow = false,

    --- The amount of space between separate lines, where 0 does not add any additional space (i.e. it uses
    -- the font's natural line height) (default 0).
    -- @type number
    -- @meta read/write
    spacing = rtk.Attribute{
        default=0,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- The name of the font face (e.g. `'Calibri`'), which uses the @{rtk.themes.text_font|global text
    -- default} if nil (default nil).
    -- @type string|nil
    -- @meta read/write
    font = rtk.Attribute{
        default=function(self, attr)
            return self._theme_font[1]
        end,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- The pixel size of the text font (e.g. 18), which uses the @{rtk.themes.text_font|global text
    -- default} if nil (default nil).
    -- @meta read/write
    -- @type number|nil
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
        reflow=rtk.Widget.REFLOW_FULL,
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
}

--- Create a new text widget with the given attributes.
--
-- @display rtk.Text
function rtk.Text:initialize(attrs, ...)
    self._theme_font = self._theme_font or rtk.theme.text_font or rtk.theme.default_font
    rtk.Widget.initialize(self, attrs, rtk.Text.attributes.defaults, ...)
    self._font = rtk.Font()
end

function rtk.Text:__tostring_info()
    return self.text
end


function rtk.Text:_handle_attr(attr, value, oldval, trigger, reflow, sync)
    if attr == 'text' and reflow == rtk.Widget.REFLOW_DEFAULT and self.w and not self.calc.wrap then
        -- We have a fixed with and aren't wrapping.  Provided neither old nor new values
        -- contain newlines, we can skip the costly full refow.  Technically we could skip
        -- full reflow if the number of newlines is the same, but this handles the common
        -- case.
        if not value:find('\n') and not oldval:find('\n') then
            reflow = rtk.Widget.REFLOW_PARTIAL
        end
    end
    local ok = rtk.Widget._handle_attr(self, attr, value, oldval, trigger, reflow, sync)
    if ok == false then
        return ok
    end
    if self._segments and (attr == 'text' or attr == 'wrap' or attr == 'textalign' or attr == 'spacing') then
        -- Force regeneration of segments on next reflow
        self._segments.dirty = true
    elseif attr == 'bg' and not self.color then
        -- The background changed and we're using nil color (i.e. adaptive), so force recalculation of color.
        self:attr('color', self.color, true, rtk.Widget.REFLOW_NONE)
    end

    return ok
end

function rtk.Text:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    local calc = self.calc
    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    self._font:set(calc.font, calc.fontsize, calc.fontscale, calc.fontflags)

    local w, h, tp, rp, bp, lp, minw, maxw, minh, maxh = self:_get_content_size(
        boxw, boxh, fillw, fillh, clampw, clamph, nil, greedyw, greedyh
    )
    local hpadding = lp + rp
    local vpadding = tp + bp

    local lmaxw = (clampw or (fillw and greedyw)) and (boxw - hpadding) or w or math.inf
    local lmaxh = (clamph or (fillh and greedyh)) and (boxh - vpadding) or h or math.inf
    -- Avoid re-laying out the string if nothing relevant has changed.
    local seg = self._segments
    if not seg or seg.boxw ~= lmaxw or not seg.isvalid() then
        self._segments, self.lw, self.lh = self._font:layout(
            calc.text,
            lmaxw, lmaxh,
            calc.wrap ~= rtk.Text.WRAP_NONE,
            self.textalign and calc.textalign or calc.halign,
            true,
            calc.spacing,
            calc.wrap == rtk.Text.WRAP_BREAK_WORD
        )
    end
    -- Text objects support clipping, so we respect our bounding box when clamping is requested.
    calc.w = (w and w + hpadding) or (fillw and greedyw and boxw) or math.min(clampw and boxw or math.inf, self.lw + hpadding)
    calc.h = (h and h + vpadding) or (fillh and greedyh and boxh) or math.min(clamph and boxh or math.inf, self.lh + vpadding)
    -- Finally, apply min/max and round to ensure alignment to pixel boundaries.
    calc.w = math.ceil(rtk.clamp(calc.w, minw, maxw))
    calc.h = math.ceil(rtk.clamp(calc.h, minh, maxh))
end

-- Precalculate positions for _draw()
function rtk.Text:_realize_geometry()
    local calc = self.calc
    local tp, rp, bp, lp = self:_get_padding_and_border()
    local lx, ly
    if calc.halign == rtk.Widget.LEFT then
        lx = lp
    elseif calc.halign == rtk.Widget.CENTER then
        lx = lp + math.max(0, calc.w - self.lw - lp - rp) / 2
    elseif calc.halign == rtk.Widget.RIGHT then
        lx = math.max(0, calc.w - self.lw - rp)
    end

    if calc.valign == rtk.Widget.TOP then
        ly = tp
    elseif calc.valign == rtk.Widget.CENTER then
        ly = tp + math.max(0, calc.h - self.lh - tp - bp) / 2
    elseif calc.valign == rtk.Widget.BOTTOM then
        ly = math.max(0, calc.h - self.lh - bp)
    end
    self._pre = {
        tp=tp, rp=rp, bp=bp, lp=lp,
        lx=lx, ly=ly,
    }
end

function rtk.Text:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    local x, y = calc.x + offx, calc.y + offy

    if y + calc.h < 0 or y > cliph or calc.ghost then
        -- Widget not viewable on viewport
        return
    end

    local pre = self._pre
    self:_handle_drawpre(offx, offy, alpha, event)
    self:_draw_bg(offx, offy, alpha, event)
    self:setcolor(calc.color, alpha)
    assert(self._segments)
    self._font:draw(
        self._segments,
        x + pre.lx,
        y + pre.ly,
        not calc.overflow and math.min(clipw - x, calc.w) - pre.lx - pre.rp or nil,
        not calc.overflow and math.min(cliph - y, calc.h) - pre.ly - pre.bp or nil
    )
    self:_draw_borders(offx, offy, alpha)
    self:_handle_draw(offx, offy, alpha, event)
end