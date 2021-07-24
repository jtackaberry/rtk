-- Copyright 2017-2021 Jason Tackaberry
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


--- Single-line editable text entry with text selection and copy/paste support.
--
-- rtk.Entry implements most (all?) of the usual keyboard shortcuts and UX
-- idioms for cursor (`caret`) navigation, selection, and clipboard management, and
-- so it should feel relatively intuitive for most users.
--
-- Undo is also supported, both programmatically as well as via the default
-- user-accessible context menu.
--
-- @example
--   local entry = box:add(rtk.Entry{icon='18-search', placeholder='Search', textwidth=15})
--   entry.onkeypress = function(self, event)
--       if event.keycode == rtk.keycodes.ESCAPE then
--           self:clear()
--           self:animate{'bg', dst=rtk.Attribute.DEFAULT}
--       elseif event.keycode == rtk.keycodes.ENTER then
--           self:animate{'bg', dst='hotpink'}
--       end
--   end
--
-- @class rtk.Entry
-- @inherits rtk.Widget
rtk.Entry = rtk.class('rtk.Entry', rtk.Widget)

-- Popup menu created on-demand in _handle_mousedown().  Menu item ids map to
-- the corresponding method names.
rtk.Entry.static.contextmenu = {
    {'Undo', id='undo'},
    rtk.NativeMenu.SEPARATOR,
    {'Cut', id='cut'},
    {'Copy', id='copy'},
    {'Paste', id='paste'},
    {'Delete', id='delete'},
    rtk.NativeMenu.SEPARATOR,
    {'Select All', id='select_all'},
}

rtk.Entry.register{
    --- The current (or desired if setting) value of the text entry (default is the empty
    -- string). As the user interacts with the entry, this value is updated to reflect
    -- current state, or you can set the value programmatically via `attr()` one of the
    -- rtk.Entry-specific methods below.
    --
    -- The value is never nil.  If no text is inputted, it is represented by the
    -- empty string.
    --
    -- @meta read/write
    -- @type string
    value = rtk.Attribute{
        default='',
        calculate=function(self, attr, value, target)
            -- Ensure value is always a string.
            return value and tostring(value) or ''
        end,
    },

    --- Defines the width of the entry widget to hold this many characters based on the
    -- current `font` when `w` is not defined (default nil).  The `w` attribute will
    -- override `textwidth`.
    -- @meta read/write
    -- @type number|nil
    textwidth = rtk.Attribute{reflow=rtk.Widget.REFLOW_FULL},

    --- Optional icon for the left edge of the entry box (default nil).  If a string is
    -- provided, it refers to an icon name (without file extension) in an icon path
    -- registered with `rtk.add_image_search_path()`. See `rtk.Image.make_icon()`
    -- for more details. Otherwise an `rtk.Image` object can be used directly.
    --
    -- @type rtk.Image|string|nil
    -- @meta read/write
    icon = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=function(self, attr, value, target)
            if type(value) == 'string' then
                local icon = self.calc.icon
                local style = rtk.color.get_icon_style(self.calc.bg or rtk.theme.bg, rtk.theme.bg)
                if icon and icon.style == style then
                    -- Style didn't change.
                    return icon
                end
                local img = rtk.Image.make_icon(value, style)
                if not img then
                    img = rtk.Image.make_placeholder_icon(24, 24, style)
                end
                return img
            else
                return value
            end
        end
    },
    --- The opacity of `icon` (default 0.6).
    -- @meta read/wr4ite
    -- @type number
    icon_alpha = 0.6,

    --- The amount of space in pixels between the `icon` and the text (default 5).
    -- @meta read/write
    -- @type number
    spacing = rtk.Attribute{
        default=5,
        reflow=rtk.Widget.REFLOW_FULL
    },
    --- Placeholder text that is drawn with a low opacity as long as `value` is empty (default nil).
    -- If nil, the placeholder text is not drawn.  The color (including opacity) of the placeholder
    -- is defined by the current theme's @{rtk.themes.entry_placeholder|`entry_placeholder`}.
    -- @meta read/write
    -- @type string
    placeholder = rtk.Attribute{
        default=nil,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- Color of text value, which defaults to the theme's @{rtk.themes.text|`text`} value if
    -- nil (default).
    --
    -- @type colortype|nil
    -- @meta read/write
    textcolor = rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.text
        end,
        calculate=rtk.Reference('bg')
    },
    --- Color of border when the mouse is `hovering` over the rtk.Entry region, which
    -- defaults to the theme's @{rtk.themes.entry_border_hover|`entry_border_hover`}
    -- value if nil (default).
    --
    -- @type colortype|nil
    -- @meta read/write
    border_hover = rtk.Attribute{
        default=function(self, attr)
            return {rtk.theme.entry_border_hover, 1}
        end,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=function(self, attr, value, target)
            return rtk.Widget.static._calc_border(self, value)
        end,
    },
    --- Color of border when the widget is `focused`, which defaults to the theme's
    -- @{rtk.themes.entry_border_focused|`entry_border_focused`} value if nil (default).
    --
    -- @type colortype|nil
    -- @meta read/write
    border_focused = rtk.Attribute{
        default=function(self, attr)
            return {rtk.theme.entry_border_focused, 1}
        end,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=rtk.Reference('border_hover'),
    },
    --- Controls whether the cursor will blink when the widget is focused (default true).
    -- @type boolean
    -- @meta read/write
    blink = true,

    --- The current caret (or cursor) position which is immediately in front of the
    -- character defined by this index (default 1).
    -- @type number
    -- @meta read/write
    caret = 1,

    --- The name of the font face (e.g. `'Calibri`'), which uses the @{rtk.themes.entry_font|global
    -- text entry default} if nil (default nil).
    -- @type string|nil
    -- @meta read/write
    font = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_FULL,
        default=function(self, attr)
            return self._theme_font[1]
        end
    },
    --- The pixel size of the entry font (e.g. 18), which uses the @{rtk.themes.entry_font|global
    -- text entry default} if nil (default nil).
    -- @type number|nil
    -- @meta read/write
    fontsize = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_FULL,
        default=function(self, attr)
            return self._theme_font[2]
        end
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

    --
    -- Widget overrides
    --
    bg = rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.entry_bg
        end
    },
    tpadding = 4,
    rpadding = 10,
    bpadding = 4,
    lpadding = 10,
    cursor = rtk.mouse.cursors.BEAM,
    autofocus = true,
}

--- Create a new text entry widget with the given attributes.
-- @display rtk.Entry
function rtk.Entry:initialize(attrs, ...)
    self._theme_font = rtk.theme.entry_font or rtk.theme.default_font
    rtk.Widget.initialize(self, attrs, self.class.attributes.defaults, ...)

    -- Array mapping character index to x offset
    self._positions = {0}
    -- Initialized in _reflow()
    self._backingstore = nil
    self._font = rtk.Font()
    self._caretctr = 0
    -- Character position where selection was started
    self._selstart = nil
    -- Character position where where selection ends (which may be less than or
    -- greater than the anchor)
    self._selend = nil
    self._loffset = 0
    self._blinking = false
    self._dirty = false
    -- A table of prior states for ctrl-z undo.  Each entry is is an array
    -- of {text, caret, selstart, selend}
    self._history = nil
    self._last_doubleclick_time = 0
    self._num_doubleclicks = 0
end

function rtk.Entry:_handle_attr(attr, value, oldval, trigger, reflow)
    local calc = self.calc
    -- Calling superclass here will queue reflow, which in turn will automatically dirty
    -- rendered text and _calcview().
    local ok = rtk.Widget._handle_attr(self, attr, value, oldval, trigger, reflow)
    if ok == false then
        return ok
    end
    if attr == 'value' then
        -- Ensure we store the calculated value
        self.value = value
        self._selstart = nil
        -- After setting value, ensure caret does not extend past end of value.
        if calc.caret >= value:len() then
            calc.caret = value:len() + 1
        end
        if trigger then
            self:onchange()
        end
    elseif attr == 'caret' then
        calc.caret = rtk.clamp(value, 1, self.value:len() + 1)
        -- Reflect new value back to user-facing attribute
        self.caret = calc.caret
    elseif attr == 'bg' and type(self.icon) == 'string' then
        -- We're (potentially) changing the color but, because the user-provided attribute
        -- is a string it means we loaded the icon based on its name.  Recalculate the icon
        -- attr so that the light vs dark style gets recalculated based on this new
        -- background color.
        self:attr('icon', self.icon, true)
    end
    return true
end

function rtk.Entry:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, viewport, window)
    local calc = self.calc
    local maxw, maxh = nil, nil
    self._font:set(calc.font, calc.fontsize, calc.fontscale, calc.fontflags)

    if calc.textwidth and not self.w then
        -- Compute dimensions based on font and given textwidth.  Choose a character
        -- that's big enough to ensure we can safely support textwidth worth of any
        -- character.
        local charwidth, _ = gfx.measurestr('W')
        maxw, maxh = charwidth * calc.textwidth, self._font.texth
    else
        -- No hints given on dimensions, so make something up from whole cloth for our
        -- intrinsic size.
        maxw, maxh = gfx.measurestr("Dummy string!")
    end

    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp = self:_get_content_size(boxw, boxh, fillw, fillh, clampw, clamph)
    calc.w = (w or maxw) + lp + rp
    calc.h = (h or maxh) + tp + bp
    -- Remember calculated padding as we use that in many functions.
    self._ctp, self._crp, self._cbp, self._clp = tp, rp, bp, lp

    -- We use the backingstore to implement left-clipping, which REAPER doesn't natively
    -- support.
    if not self._backingstore then
        self._backingstore = rtk.Image()
    end
    self._backingstore:resize(calc.w, calc.h, false)
    self._dirty = true
end

function rtk.Entry:_realize_geometry()
    self:_calcpositions()
    self:_calcview()
end

function rtk.Entry:_unrealize()
    self._backingstore = nil
end

-- Measure the x position of each character in the string.  This allows us to support
-- proportional fonts.
function rtk.Entry:_calcpositions(startfrom)
    self._font:set()
    -- Ok, this isn't exactly efficient, but it should be fine for sensibly sized strings.
    for i = (startfrom or 1), self.value:len() do
        local w, _ = gfx.measurestr(self.value:sub(1, i))
        self._positions[i + 1] = w
    end
end

function rtk.Entry:_calcview()
    local calc = self.calc
    -- TODO: handle case where text is deleted from end, we want to keep the text right justified
    local curx = self._positions[calc.caret]
    local curoffset = curx - self._loffset
    local innerw = calc.w - (self._clp + self._crp)
    local icon = calc.icon
    if icon then
        innerw = innerw - (icon.w * rtk.scale) - calc.spacing
    end
    if curoffset < 0 then
        self._loffset = curx
    elseif curoffset > innerw then
        self._loffset = curx - innerw
    end
end

function rtk.Entry:_handle_focus(event, other)
    local ok = rtk.Widget._handle_focus(self, event, other)
    -- Force a redraw if there is a selection
    self._dirty = self._dirty or (ok and self._selstart)
    return ok
end

function rtk.Entry:_handle_blur(event, other)
    local ok = rtk.Widget._handle_blur(self, event, other)
    -- Force a redraw if there is a selection
    self._dirty = self._dirty or (ok and self._selstart)
    return ok
end

function rtk.Entry:_blink()
    if self.calc.blink and self:focused() and self.window.is_focused then
        self._blinking = true
        local ctr = self._caretctr % 16
        self._caretctr = self._caretctr + 1
        if ctr == 0 then
            self:queue_draw()
        end
        rtk.defer(self._blink, self)
    end
end

-- Given absolute coords of the text area, determine the caret position from
-- the mouse down event.
function rtk.Entry:_caret_from_mouse_event(event)
    local calc = self.calc
    local iconw = calc.icon and (calc.icon.w*rtk.scale + calc.spacing) or 0
    local relx = self._loffset + event.x - self.clientx - iconw - self._clp
    for i = 2, self.value:len() + 1 do
        local pos = self._positions[i]
        local width = pos - self._positions[i-1]
        if relx <= self._positions[i] - width/2 then
            return i - 1
        end
    end
    return self.value:len() + 1
end

function rtk.Entry:_get_word_left(spaces)
    local caret = self.calc.caret
    if spaces then
        while caret > 1 and self.value:sub(caret - 1, caret - 1) == ' ' do
            caret = caret - 1
        end
    end
    while caret > 1 and self.value:sub(caret - 1, caret - 1) ~= ' ' do
        caret = caret - 1
    end
    return caret
end

function rtk.Entry:_get_word_right(spaces)
    local caret = self.calc.caret
    local len = self.value:len()
    while caret <= len and self.value:sub(caret, caret) ~= ' ' do
        caret = caret + 1
    end
    if spaces then
        while caret <= len and self.value:sub(caret, caret) == ' ' do
            caret = caret + 1
        end
    end
    return caret
end


--- Selects all text.
function rtk.Entry:select_all()
    self._selstart = 1
    self._selend = self.value:len() + 1
    self._dirty = true
    self:queue_draw()
end

--- Selects a region of text between two character positions.
--
-- Each parameter refers to an index within the `value` string, where the first
-- character in `value` is index `1`, as usual for Lua.
--
-- The range works like Lua's native `string.sub()` in that the range is inclusive (i.e.
-- includes the characters at both `a` and `b` indexes), and also suports negative end
-- indices, such that -1 refers to the end of the string, -2 is the second last character,
-- etc.
--
-- @tparam number a the starting character index
-- @tparam number b the ending character index (inclusive within the region), or negative to
--   slice from the end of the string, where -1 will extend to the end of `value`.
function rtk.Entry:select_range(a, b)
    local len = #self.value
    if len == 0 or not a then
        -- Regardless of what was asked, there is nothing to select.
        self._selstart = nil
    else
        b = b or a
        self._selstart = math.max(1, a)
        self._selend = b > 0 and math.min(len + 1, b + 1) or math.max(self._selstart, len+b+2)
    end
    self._dirty = true
    self:queue_draw()
end

--- Returns the selection range.
--
-- @treturn number the index within `value` of the start of the selection, or nil if nothing
--   was selected.
-- @treturn number the index within `value` of the end of the selection (inclusive), or nil if nothing
--   was selected.
function rtk.Entry:get_selection_range()
    if self._selstart then
        return math.min(self._selstart, self._selend), math.max(self._selstart, self._selend)
    end
end

function rtk.Entry:_delete_range(a, b)
    self.value = self.value:sub(1, a - 1) .. self.value:sub(b + 1)
    self._dirty = true
end

--- Deletes a specific range from the text entry.
--
-- The original value is added to undo history.
--
-- @tparam number a the starting character index
-- @tparam number b the ending character index (inclusive within the region)
function rtk.Entry:delete_range(a, b)
    self:push_undo()
    self:_delete_range(a, b)
    self.calc.caret = rtk.clamp(self.calc.caret, 1, #self.value)
    self.caret = self.calc.caret
    self:queue_draw()
    self:onchange()
end

function rtk.Entry:_delete()
    local calc = self.calc
    if self._selstart then
        local a, b = self:get_selection_range()
        self:_delete_range(a, b - 1)
        if calc.caret > self._selstart then
            calc.caret = math.max(1, calc.caret - (b-a))
            -- Reflect new value back to user-facing attribute
            self.caret = calc.caret
        end
        self._selstart = nil
        self:queue_draw()
        return b-a
    end
    return 0
end


--- Deletes the current selected range from `value` and resets the selection.
--
-- The original value is added to undo history.
--
-- @treturn number the number of characters that were deleted from `value`, or
--   0 if there was no selection.
function rtk.Entry:delete()
    if self._selstart then
        self:push_undo()
    end
    if self:_delete() > 0 then
        self:onchange()
    end
end


--- Erases all contents from the entry.
--
-- This is different from directly setting the `value` attribute to the empty string
-- in that it also pushes the current value onto the undo history.
function rtk.Entry:clear()
    if self.value ~= '' then
        self:push_undo()
        self:attr('value', '')
    end
end

--- Copies the selected range to the system clipboard.
--
-- The original value is added to undo history.
--
-- This uses `rtk.clipboard.set()` and so requires the SWS extension to work properly.
--
-- @treturn string|nil the text that was copied to clipboard, or nil if nothing was selected, or
--   if the SWS extension isn't available.
function rtk.Entry:copy()
    if self._selstart then
        local a, b = self:get_selection_range()
        local text = self.value:sub(a, b - 1)
        if rtk.clipboard.set(text) then
            return text
        end
    end
end


--- Copies the selected text to the clipboard and deletes it from `value`,
-- resetting the selection.
--
-- The original value is added to undo history.
--
-- @treturn string|nil the string that was cut from `value`, or nil if nothing
--   was selected, or if the SWS extension wasn't available.
function rtk.Entry:cut()
    local copied = self:copy()
    if copied then
        self:delete()
        self:onchange()
    end
    return copied
end

--- Pastes text from the clipboard into the text entry at the current `caret` position.
--
-- The original value is added to undo history.
--
-- @tparam string|nil the string that was pasted into the text entry, or nil if nothing
--   was in the clipboard, or if the SWS extension wasn't available.
function rtk.Entry:paste()
    local str = rtk.clipboard.get()
    if str and str ~= '' then
        self:push_undo()
        self:_delete()
        self:_insert(str)
        self:onchange()
        return str
    end
end

function rtk.Entry:_insert(text)
    local calc = self.calc
    -- FIXME: honor self.max based on current len and size of text
    self.value = self.value:sub(0, calc.caret - 1) .. text .. self.value:sub(calc.caret)
    self:_calcpositions(calc.caret)
    calc.caret = calc.caret + text:len()
    -- Reflect new value back to user-facing attribute
    self.caret = calc.caret
    self._dirty = true
    self:queue_draw()
end


--- Inserts the given text at the current `caret` position.
--
-- The original value is added to undo history.
--
-- @tparam string text the text to insert at `caret`
function rtk.Entry:insert(text)
    self:push_undo()
    self:_insert(text)
    self:onchange()
end

--- Reverts to the last state in the undo history.
--
-- All APIs that mutate `value` add undo state to the undo history. However,
-- individual character presses by the user within the entry do not generate
-- undo state.
--
-- @treturn boolean true if undo state was restored, or false if there was no
--   undo state.
function rtk.Entry:undo()
    local calc = self.calc
    if self._history and #self._history > 0 then
        local state = table.remove(self._history, #self._history)
        self.value, calc.caret, self._selstart, self._selend = table.unpack(state)
        -- Reflect new value back to user-facing attribute
        self.caret = calc.caret
        self._dirty = true
        self:_calcpositions()
        self:queue_draw()
        self:onchange()
        return true
    else
        return false
    end
end

--- Pushes current state to the undo history for future `undo()`.
function rtk.Entry:push_undo()
    if not self._history then
        self._history = {}
    end
    self._history[#self._history + 1] = {self.value, self.calc.caret, self._selstart, self._selend}
end

function rtk.Entry:_handle_mousedown(event)
    local ok = rtk.Widget._handle_mousedown(self, event)
    if ok == false then
        return ok
    end
    if event.button == rtk.mouse.BUTTON_LEFT then
        self.calc.caret = self:_caret_from_mouse_event(event)
        -- Reflect new value back to user-facing attribute
        self.caret = self.calc.caret
    elseif event.button == rtk.mouse.BUTTON_RIGHT then
        if not self._popup then
            self._popup = rtk.NativeMenu(rtk.Entry.contextmenu)
        end
        local clipboard = rtk.clipboard.get()
        self._popup:item('undo').disabled = not self._history or #self._history == 0
        self._popup:item('cut').disabled = not self._selstart
        self._popup:item('copy').disabled = not self._selstart
        self._popup:item('delete').disabled = not self._selstart
        self._popup:item('paste').disabled = not clipboard or clipboard == ''
        self._popup:item('select_all').disabled = #self.value == 0
        self._popup:open_at_mouse():done(function(item)
            if item then
                -- We named menu item ids after method names, so this is a simple dispatcher.
                self[item.id](self)
            end
        end)
    end
    return true
end

function rtk.Entry:_handle_keypress(event)
    local ok = rtk.Widget._handle_keypress(self, event)
    if ok == false then
        return ok
    end
    local len = self.value:len()
    local calc = self.calc
    local orig_caret = calc.caret
    local selecting = event.shift
    if event.keycode == rtk.keycodes.LEFT then
        if event.ctrl then
            calc.caret = self:_get_word_left(true)
        else
            calc.caret = math.max(1, calc.caret - 1)
        end
    elseif event.keycode == rtk.keycodes.RIGHT then
        if event.ctrl then
            calc.caret = self:_get_word_right(true)
        else
            calc.caret = math.min(calc.caret + 1, len + 1)
        end
    elseif event.keycode == rtk.keycodes.HOME then
        calc.caret = 1
    elseif event.keycode == rtk.keycodes.END then
        calc.caret = self.value:len() + 1
    elseif event.keycode == rtk.keycodes.DELETE then
        if self._selstart then
            self:delete()
        else
            if event.ctrl then
                self:push_undo()
                self:_delete_range(calc.caret, self:_get_word_right(true) - 1)
            else
                self:_delete_range(calc.caret, calc.caret)
            end
        end
        self:_calcpositions(calc.caret)
        self:onchange(event)
    elseif event.keycode == rtk.keycodes.BACKSPACE then
        if calc.caret >= 1 then
            if self._selstart then
                self:delete()
            else
                if event.ctrl then
                    self:push_undo()
                    calc.caret = self:_get_word_left(true)
                    self:_delete_range(calc.caret, orig_caret - 1)
                else
                    self:_delete_range(calc.caret - 1, calc.caret - 1)
                    calc.caret = math.max(1, calc.caret - 1)
                end
            end
            self:_calcpositions(calc.caret)
            self:onchange(event)
        end
    elseif event.char and not event.ctrl then
        if self._selstart then
            self:push_undo()
        end
        self:_delete()
        self:_insert(event.char)
        self:onchange(event)
        len = #self.value
        selecting = false
    elseif event.ctrl and event.char and not event.shift then
        if event.char == 'a' and len > 0 then
            self:select_all()
            -- Ensure selection doesn't get reset below because shift isn't pressed.
            selecting = nil
        elseif event.char == 'c' then
            self:copy()
            return true
        elseif event.char == 'x' then
            self:cut()
        elseif event.char == 'v' then
            self:paste()
        elseif event.char == 'z' then
            self:undo()
            selecting = nil
        end
    else
        return
    end
    if selecting then
        if not self._selstart then
            self._selstart = orig_caret
        end
        self._selend = calc.caret
    elseif selecting == false then
        self._selstart = nil
    end
    -- Reflect new value back to user-facing attribute
    self.caret = calc.caret
    -- Reset blinker
    self._caretctr = 0
    self:_calcview()
    self._dirty = true
    log.debug2(
        'keycode=%s char=%s caret=%s ctrl=%s shift=%s meta=%s alt=%s sel=%s-%s',
        event.keycode, event.char, calc.caret,
        event.ctrl, event.shift, event.meta, event.alt,
        self._selstart, self._selend
    )
    return true
end

function rtk.Entry:_handle_dragstart(event)
    if not self:focused() or event.button ~= rtk.mouse.BUTTON_LEFT then
        return
    end
    -- Superclass method disables dragging so don't call it.
    local draggable, droppable = self:ondragstart(self, event)
    if draggable == nil then
        self._selstart = self.calc.caret
        self._selend = self.calc.caret
        return true, false
    end
    return draggable, droppable
end

function rtk.Entry:_handle_dragmousemove(event)
    local ok = rtk.Widget._handle_dragmousemove(self, event)
    if ok == false then
        return ok
    end
    local selend = self:_caret_from_mouse_event(event)
    if selend == self._selend then
        return ok
    end
    self._selend = selend
    -- This will force a reflow of this widget.
    self:attr('caret', selend)
    return ok
end

function rtk.Entry:_handle_dragend(event)
    local ok = rtk.Widget._handle_dragend(self, event)
    if ok == false then
        return ok
    end
    -- Reset double click timer
    self._last_click_time  = 0
    return ok
end

function rtk.Entry:_handle_click(event)
    local ok = rtk.Widget._handle_click(self, event)
    if ok == false or event.button ~= rtk.mouse.BUTTON_LEFT then
        return ok
    end
    if event.time - self._last_doubleclick_time < 0.7 then
        -- Triple click selects all text
        self:select_all()
        self._last_doubleclick_time = 0
    elseif rtk.dragging ~= self then
        self:select_range(nil)
        rtk.Widget.focus(self)
    end
    return ok
end

function rtk.Entry:_handle_doubleclick(event)
    local ok = rtk.Widget._handle_doubleclick(self, event)
    if ok == false or event.button ~= rtk.mouse.BUTTON_LEFT then
        return ok
    end
    self._last_doubleclick_time = event.time
    local left = self:_get_word_left(false)
    local right = self:_get_word_right(true)
    self.calc.caret = right
    -- Reflect new value back to user-facing attribute
    self.caret = right
    self:select_range(left, right)
    return true
end


function rtk.Entry:_rendertext(x, y)
    self._font:set()
    -- Drawing text onto a fully transparent image, and then blending that image over the
    -- current drawing target looks really janky.  There is almost certainly some bug with
    -- REAPER here.  We solve this problem by drawing the region from the current drawing
    -- target onto our backing store, and then drawing the text on top of that.
    self._backingstore:blit{
        src=gfx.dest,
        sx=x + self._clp,
        sy=y + self._ctp,
        mode=rtk.Image.FAST_BLIT
    }

    self._backingstore:pushdest()
    if self._selstart and self:focused() then
        local a, b  = self:get_selection_range()
        self:setcolor(rtk.theme.entry_selection_bg)
        gfx.rect(
            self._positions[a] - self._loffset,
            0,
            self._positions[b] - self._positions[a],
            self._backingstore.h,
            1
        )
    end
    self:setcolor(self.calc.textcolor)
    local s = self.value:sub(self._left_idx or 1)
    self._font:draw(self.value, -self._loffset, 0)
    self._backingstore:popdest()

    self._dirty = false
end


function rtk.Entry:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    -- Must do this before calling rtk.Widget._draw() since we're checking our saved offset.
    if offy ~= self.offy or offx ~= self.offx then
        -- If we've scrolled within a viewport since last draw, force _rendertext() to
        -- repaint the background into the Entry's local backing store.
        self._dirty = true
    end

    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local x, y = calc.x + offx, calc.y + offy
    local focused = self:focused() and self.window.is_focused
    if (y + calc.h < 0 or y > cliph or calc.ghost) and not focused then
        -- Widget would not be visible on current drawing target
        return false
    end
    if self.disabled then
        alpha = alpha * 0.5
    end

    local tp, rp, bp, lp = self._ctp, self._crp, self._cbp, self._clp

    self:_handle_drawpre(offx, offy, alpha, event)
    -- Paint background first because _rendertext() will copy to the backing store and
    -- render the text over top it.
    self:_draw_bg(offx, offy, alpha, event)

    if self._dirty then
        self:_rendertext(x, y)
    end

    local amul = calc.alpha * alpha
    local icon = calc.icon
    if icon then
        local a = math.min(1, calc.icon_alpha * alpha + (focused and 0.2 or 0))
        -- TODO: clip
        icon:draw(
            x + lp,
            y + ((calc.h + tp - bp) - icon.h * rtk.scale) / 2,
            a * amul,
            rtk.scale
        )
        lp = lp + icon.w*rtk.scale + calc.spacing
    end
    self._backingstore:blit{
        sx=0,
        sy=0,
        sw=calc.w - lp - rp,
        sh=calc.h - tp - bp,
        dx=x + lp,
        dy=y + tp,
        alpha=amul,
        mode=rtk.Image.FAST_BLIT
    }

    if calc.placeholder and #self.value == 0 then
        self._font:set()
        -- self:setcolor(calc.textcolor, 0.5 * alpha)
        self:setcolor(rtk.theme.entry_placeholder, alpha)
        self._font:draw(calc.placeholder, x + lp, y + tp, calc.w - lp, calc.h - tp)
    end

    if focused then
        if not self._blinking then
            -- Run a "timer" in the background to queue a redraw when the
            -- cursor needs to blink.
            self:_blink()
        end
        self:_draw_borders(offx, offy, alpha, calc.border_focused)
        if self._caretctr % 32 < 16 then
            -- Draw caret
            local curx = x + self._positions[calc.caret] + lp - self._loffset
            self:setcolor(calc.textcolor, alpha)
            gfx.line(curx, y + tp, curx, y + calc.h - bp, 0)
        end
    else
        self._blinking = false
        if self.hovering then
            self:_draw_borders(offx, offy, alpha, calc.border_hover)
        else
            self:_draw_borders(offx, offy, alpha)
        end
    end
    self:_handle_draw(offx, offy, alpha, event)
end



--- Event Handlers.
--
-- See also @{widget.handlers|handlers for rtk.Widget}.
--
-- @section entry.handlers


--- Called whenever `value` has changed, either by the user changing the value in
-- the UI, or when it changes programmatically via the API.
--
-- @tparam rtk.Event|nil event an `rtk.Event.KEY` event if available, or nil if
--   the entry was changed programmatically.
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Entry:onchange(event) end
