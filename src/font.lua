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

-- Maps font keys (a string consisting of font name, size, and flags) to REAPER's
-- font index.  The element is a 2-element table consisting of the font index and
-- reference count.  Once the refcount drops to zero the font index is released.
local _fontcache = {}

-- Documentation for gfx.setfont() say that valid ids are between 1 and 16 but empirically
-- it looks safe to go up to 127.  So we allow ids between 2-127, and reserve id 1 as a
-- failsafe for when we run out of available ids.  When that happens, performance will
-- tank as we will be thrashing font loading on id 1.
local _idmgr = rtk.IndexManager(2, 127)

--- Registers (if necessary) and maintains a handle to a font (with particular parameters)
-- and provides methods for processing and rendering text at a low level.
--
-- @note
--  All font related operations should be done via `rtk.Font` for performance reasons.  Calling
--  REAPER's native [gfx.setfont()](https://www.reaper.fm/sdk/reascript/reascripthelp.html#lua_gfx.setfont)
--  is extremely expensive when done incorrectly, and this is a common mistake with script-writers.
--
-- @class rtk.Font
-- @compact fields
rtk.Font = rtk.class('rtk.Font')

rtk.Font.register{
    --- The name of the font as passed to the @{rtk.Font.initialize|constructor} or
    -- `set()`
    -- @meta read-only
    -- @type string
    name = nil,

    --- The size of the font as passed to the @{rtk.Font.initialize|constructor} or
    -- `set()`
    -- @meta read-only
    -- @type number
    size = nil,

    --- The scale factor that multiplies `size` that was passed to the
    -- @{rtk.Font.initialize|constructor} or `set()`
    -- @meta read-only
    -- @type number
    scale = nil,

    --- A bitmap of @{rtk.font|font flags} that were passed to the
    -- @{rtk.Font.initialize|constructor} or `set()`
    -- @meta read-only
    -- @type number
    flags = nil,

    --- The average line height for the font
    -- @meta read-only
    -- @type number
    texth = nil,
}


--- Allocates a new font handle.
--
-- The arguments are optional, but if they aren't specified then a subsequent call to
-- `set()` will be needed before any of the other methods can be used.
--
-- @tparam string|nil name the name of the font face (e.g. `'Calibri`') (default is based
--   on the @{rtk.themes.default_font|current theme})
-- @tparam number|nil size the size of the font (default is based on the
--   @{rtk.themes.default_font|current theme})
-- @tparam number|nil scale a factor to multiply the given font size by (default 1.0)
-- @tparam flags|nil flags a bitmap of @{rtk.font|font flags}
--
-- @display rtk.Font
function rtk.Font:initialize(name, size, scale, flags)
    if size then
        self:set(name, size, scale, flags)
    end
end

function rtk.Font:finalize()
    if self._idx then
        self:_decref()
    end
end

function rtk.Font:_decref()
    if not self._idx or self._idx == 1 then
        return
    end
    local refcount = _fontcache[self._key][2]
    if refcount <= 1 then
        -- No more references to this font, so we can release the slot for future fonts.
        _idmgr:release(self._idx)
        _fontcache[self._key] = nil
    else
        _fontcache[self._key][2] = refcount - 1
    end
end

function rtk.Font:_get_id()
    -- Passing true will force a GC if we've run out of ids, so if it still returns nil
    -- we can be sure all ids are claimed.
    local idx = _idmgr:next(true)
    if idx then
        return idx
    end
    -- Nothing free.  Return 1 which we use for ad hoc fonts without caching.
    return 1
end


--- Draw a string to the current drawing target using the font.
--
-- The text will render in the current color.  You can call `rtk.Widget:setcolor()` or
-- `rtk.color.set()` first to set the desired color
-- @tparam string|table text the text to render, which is either a regular string to be
--   drawn directly, or is an array of line segments as returned by `layout()`, which
--   supports text alignment.
-- @tparam number x the x coordinate within the current drawing target
-- @tparam number y the y coordinate within the current drawing target
-- @tparam number|nil clipw if not nil, is the allowed width beyond which text is clipped
-- @tparam number|nil cliph if not nil, is the allowed height beyond which text is clipped
-- @tparam number|nil flags an optional bitmap of font flags according to the
--   [upstream documentation for gfx.drawstr()](https://www.reaper.fm/sdk/reascript/reascripthelp.html#lua_gfx.drawstr)
function rtk.Font:draw(text, x, y, clipw, cliph, flags)
    -- The code in this function is terribly repetitive and tedious, but it's meant to
    -- avoid unnecessary loops or table creation for common cases.
    if rtk.os.mac then
        -- XXX: it's unclear why we need to fudge the extra pixel on OS X but it fixes
        -- alignment.
        local fudge = 1 * rtk.scale.value
        y = y + fudge
        if cliph then
            cliph = cliph - fudge
        end
    end
    flags = flags or 0
    self:set()
    if type(text) == 'string' then
        gfx.x = x
        gfx.y = y
        if cliph then
            gfx.drawstr(text, flags, x + clipw, y + cliph)
        else
            gfx.drawstr(text, flags)
        end
    elseif #text == 1 then
        -- Single string list of segments.
        local segment, sx, sy, sw, sh = table.unpack(text[1])
        gfx.x = x + sx
        gfx.y = y + sy
        if cliph then
            gfx.drawstr(segment, flags, x + clipw, y + cliph)
        else
            gfx.drawstr(segment, flags)
        end
    else
        -- Multiple segments we need to loop over.
        flags = flags | (cliph and 0 or 256)
        local checkh = cliph
        clipw = x + (clipw or 0)
        cliph = y + (cliph or 0)
        for n = 1, #text do
            local segment, sx, sy, sw, sh = table.unpack(text[n])
            local offy = y + sy
            if checkh and offy > cliph then
                break
            elseif offy + sh >= 0 then
                gfx.x = x + sx
                gfx.y = offy
                gfx.drawstr(segment, flags, clipw, cliph)
            end
        end
    end
end

--- Measures the dimensions of the given string with the current font parameters.
--
-- @tparam string s the string to measure
-- @treturn number w the width of the string
-- @treturn number h the height of the string
function rtk.Font:measure(s)
    self:set()
    return gfx.measurestr(s)
end


-- Set of characters after which line breaks can occur
local _wrap_characters = {
    [' '] = true,
    ['-'] = true,
    [','] = true,
    ['.'] = true,
    ['!'] = true,
    ['?'] = true,
    ['\n'] = true,
    ['/'] = true,
    ['\\'] = true,
    [';'] = true,
    [':'] = true,
}

--- Measures the dimensions of a string when laid out a certain way.
--
-- This function processes the string into line segments and provides the
-- geometry of each line (dimensions as well as positional offsets for
-- rendering).  The string may contain newlines.
--
-- @example
--   local s = 'Friends, Romans, countrymen, lend me your ears;\nI come to bury Caesar, not to praise him.'
--   local font = rtk.Font('Times New Roman', 24)
--   local segments, w, h = font:layout(s, 800, nil, true, rtk.Widget.CENTER)
--   log.info('total size: %d x %d', w, h)
--   for n, segment in ipairs(segments) do
--       local line, x, y, w, h = table.unpack(segment)
--       log.info('line %d: %s,%s %sx%s: %s', n, x, y, w, h, line)
--   end
--
-- @tparam string s the string to layout
-- @tparam number boxw the width constraint for the laid out string
-- @tparam number|nil boxh the height constraint for the laid out string (not currently used)
-- @tparam bool|nil wrap if true, the string will be wrapped so as not to overflow `boxw`
--   (default false)
-- @tparam alignmentconst|nil align an @{alignmentconst|halign alignment constant} that
--   controls how the laid out string is aligned within `boxw` (defaults to `LEFT`).
-- @tparam boolean|nil relative if true, non-left alignment is relative to the
--   widest line in the string, otherwise it is aligned within the given `boxw`
--   (default false)
--   For intrinsic size calculations, you want relative to be true (default false)
-- @tparam number|nil spacing amount of additional space between each line in pixels
--   (default 0).
-- @tparam boolean|nil breakword if wrap is true, this controls whether words are allowed to be
--   broken as a last resort in order to fit within boxw.  If this is is false, the resulting line
--   will overflow boxw.
-- @treturn table an array of line segments, where each element in the array is in the form
--   `{line, x, y, w, h}` where line is a string, x and y are the coordinates of the line
--   segment (offset from 0, 0), and w and h are the pixel dimensions of the string
-- @treturn number the calculated width of the string, which is guaranteed to be less
--   than `boxw` if (and only if) `wrap` is true.
-- @treturn number the calculated height of the string when rendered (which includes `spacing`)
function rtk.Font:layout(s, boxw, boxh, wrap, align, relative, spacing, breakword)
    self:set()
    local segments = {
        text = s,
        boxw = boxw,
        boxh = boxh,
        wrap = wrap,
        align = align,
        relative = relative,
        spacing = spacing,
        scale = rtk.scale.value
    }
    align = align or rtk.Widget.LEFT
    spacing = spacing or 0
    -- Common case where the string fits in the box.  But first if the string contains a
    -- newline and we're not wrapping we need to take the slower path.
    if not s:find('\n') then
        local w, h = gfx.measurestr(s)
        if w <= boxw or not wrap then
            segments[1] = {s, 0, 0, w, h}
            return segments, w, h
        end
    end

    -- If we're here, either we need to wrap, or the text contains newlines and therefore
    -- multiple segments.
    local maxwidth = 0
    -- Current y offset of the last segment
    local y = 0

    local function addsegment(segment)
        local w, h = gfx.measurestr(segment)
        segments[#segments+1] = {segment, 0, y, w, h}
        maxwidth = math.max(w, maxwidth)
        y = y + h + spacing
    end

    if not wrap then
        for n, line in ipairs(s:split('\n')) do
            if #line > 0 then
                addsegment(line)
            else
                y = y + self.texth + spacing
            end
        end
    else
        local startpos = 1
        local wrappos = 1
        local len = s:len()
        for endpos = 1, len do
            local substr = s:sub(startpos, endpos)
            local ch = s:sub(endpos, endpos)
            local w, h = gfx.measurestr(substr)
            if _wrap_characters[ch] then
                wrappos = endpos
            end
            if w > boxw or ch == '\n' then
                local wrapchar = _wrap_characters[s:sub(wrappos, wrappos)]
                -- If we're allowed to break words and the current wrap position is not a
                -- wrap character (which can happen when breakword is true and we're
                -- forced to wrap at a non-break character to fit in boxw) then we throw
                -- in the towel and adjust the wrap position to current position for this
                -- line segment.
                if breakword and (wrappos == startpos or not wrapchar) then
                    wrappos = endpos - 1
                end
                if wrappos > startpos and (breakword or wrapchar) then
                    addsegment(s:sub(startpos, wrappos):strip())
                    startpos = wrappos + 1
                    wrappos = endpos
                elseif ch == '\n' then
                    -- New line
                    y = y + self.texth + spacing
                end
            end
        end
        if startpos <= len then
            -- Add the remaining segment at the tail end.
            addsegment(string.strip(s:sub(startpos, len)))
        end
    end
    if align == rtk.Widget.CENTER then
        maxwidth = relative and maxwidth or boxw
        for n, segment in ipairs(segments) do
            segment[2] = (maxwidth - segment[4]) / 2
        end
    end
    if align == rtk.Widget.RIGHT then
        maxwidth = relative and maxwidth or boxw
        for n, segment in ipairs(segments) do
            segment[2] = maxwidth - segment[4]
        end
    end
    return segments, maxwidth, y
end



--- Sets the font properties.
--
-- The parameters are the same as @{rtk.Font.initialize|the constructor}
--
-- If no arguments are passed, then the graphics context will be set to the font
-- specification from the last call to `set()` -- although you *probably* don't want to
-- call this function without arguments, unless you're calling REAPER's font APIs
-- directly. It's highly recommended you use `layout()` and `draw()` instead, in which
-- case you don't need to call this except when you want to change the font parameters.
--
-- The font size will automatically be adjusted according to `rtk.scale` and
-- `rtk.font.multiplier`.
--
-- @treturn bool true if the font changed, false if it remained the same
function rtk.Font:set(name, size, scale, flags)
    scale = scale or 1
    flags = flags or 0
    local sz = size and math.ceil(size * scale * rtk.scale.value * rtk.font.multiplier)
    local newfont = name and (name ~= self.name or sz ~= self.calcsize or flags ~= self.flags)
    if self._idx and self._idx > 1 then
        if not newfont then
            gfx.setfont(self._idx)
            return false
        else
            -- Font is changing.
            self:_decref()
        end
    elseif self._idx == 1 then
        -- Ad hoc font.
        gfx.setfont(1, self.name, self.calcsize, self.flags)
        return true
    end

    if not newfont then
        error('rtk.Font:set() called without arguments and no font parameters previously set')
    end

    -- Initialize a new font.
    local key = name .. tostring(sz) .. tostring(flags)
    local cache = _fontcache[key]
    local idx
    if not cache then
        idx = self:_get_id()
        if idx > 1 then
            _fontcache[key] = {idx, 1}
        end
    else
        -- Increase reference count
        cache[2] = cache[2] + 1
        idx = cache[1]
    end
    gfx.setfont(idx, name, sz, flags)
    self._key = key
    self._idx = idx
    self.name = name
    self.size = size
    self.scale = scale
    self.flags = flags
    self.calcsize = sz
    self.texth = gfx.texth
    return true
end
