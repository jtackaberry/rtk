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

-- Namespaces introduced by this module
rtk.file = {}
rtk.clipboard = {}
rtk.gfx = {}

--- Miscellaneous utility functions and constants.
--
-- This module doesn't need to be explicitly loaded as all functions are automatically
-- available in the `rtk` namespace when loading `rtk`.
--
-- @module utils

--- Undo constants.
--
-- For use with `reaper.Undo_EndBlock2()`.
-- ([Reference](https://forum.cockos.com/showpost.php?p=2090533&postcount=27).)
--
-- These are global constants.
--
-- @section undo
-- @compact
-- @scope .

--- All actions
UNDO_STATE_ALL = -1
--- Track/master volume/pan/routing, plus routing/hwout envelopes
UNDO_STATE_TRACKCFG = 1
--- Track/master fx, including @{UNDO_STATE_FXENV|FX envelopes}
UNDO_STATE_FX = 2
--- Track items
UNDO_STATE_ITEMS = 4
--- Loop selection, markers, regions, and extensions
UNDO_STATE_MISCCFG = 8
--- Freeze state
UNDO_STATE_FREEZE = 16
--- Non-FX envelopes only
UNDO_STATE_TRACKENV = 32
--- FX envelopes only
UNDO_STATE_FXENV = 64
--- Contents of automation items not position, length, rate etc of automation
-- items, which is part of envelope state
UNDO_STATE_POOLEDENVS = 128
--- ARA state
UNDO_STATE_FX_ARA = 256

--- Functions
-- @section functions


--- Compares the given major/minor version against the REAPER version.
--
-- @code
--   if rtk.check_reaper_version(5, 975) then
--       reaper.MB('Sorry, REAPER version 5.975 or later is required', 'Unsupported', 0)
--   end
--
-- @tparam number major require at least this major version
-- @tparam number minor require at least this minor version, provided the major version
--   is satisfied.  3-digit minor versions are supported -- for example, this function
--   understands that version 5.98 is greater than version 5.975.
-- @tparam bool|nil exact if true, the given version must exactly match the current REAPER
--   version, otherwise any REAPER version greater than or equal to the given version
--   constraints will pass the check.
-- @treturn bool true if the REAPER version satisfies the given version constraints,
--   false otherwise.
function rtk.check_reaper_version(major, minor, exact)
    local curmaj = rtk._reaper_version_major
    local curmin = rtk._reaper_version_minor
    -- Normalize 3-digit minor versions
    minor = minor < 100 and minor or minor/10
    if exact then
        return curmaj == major and curmin == minor
    else
        return (curmaj > major) or (curmaj == major and curmin >= minor)
    end
end

--- Clamps a value within a range.
--
-- Min and max may be nil, in which case this behaves like math.min or math.max (depending
-- on which is nil).
--
-- @tparam number value the value to clamp within the range
-- @tparam number min the minimum end of the range
-- @tparam number max the maximum end of the range
-- @treturn number the value that's clamped to the range (if necessary)
function rtk.clamp(value, min, max)
    if min and max then
        return math.max(min, math.min(max, value))
    elseif min then
        return math.max(min, value)
    elseif max then
        return math.min(max, value)
    else
        return value
    end
end

--- A variant of clamp() that supports fractional relative min/max values.
--
-- For example, if min is 0.5, then it is calculated as 0.5*value before clamping.
--
-- Arguments are as with `rtk.clamp()`.
function rtk.clamprel(value, min, max)
    min = min and min < 1.0 and min*value or min
    max = max and max < 1.0 and max*value or max
    -- This is repetetive of rtk.clamp() but as this function is called quite a
    -- bit, we afford the duplication to skip the extra function call.
    if min and max then
        return math.max(min, math.min(max, value))
    elseif min then
        return math.max(min, value)
    elseif max then
        return math.min(max, value)
    else
        return value
    end
end

function rtk.isrel(value)
    return value and value > 0 and value <= 1.0
end

--- Determines whether the given point lies within the given rectangle.
--
-- @tparam number x the x coordinate of the point to test
-- @tparam number y the y coordinate of the point to test
-- @tparam number bx the x coordinate of the box
-- @tparam number by the y coordinate of the box
-- @tparam number bw the width of the box
-- @tparam number bh the height of the box
-- @treturn boolean true if the point falls within the box, or false otherwise
function rtk.point_in_box(x, y, bx, by, bw, bh)
    return x >= bx and y >= by and x <= bx + bw and y <= by + bh
end

--- Determines whether the given point lies within the given circle.
--
-- @tparam number x the x coordinate of the point to test
-- @tparam number y the y coordinate of the point to test
-- @tparam number cirx the x coordinate of the **center** of the circle
-- @tparam number ciry the y coordinate of the **center** of the circle
-- @tparam number radius the radius of the circle in pixels
-- @treturn boolean true if the point falls within the circle, or false otherwise
function rtk.point_in_circle(x, y, cirx, ciry, radius)
    -- About 2x faster than using ^2
    local dx = x - cirx
    local dy = y - ciry
    return dx*dx + dy*dy <= radius*radius
end

--- Opens the URL in the system-default web browser.
--
-- This works on Windows, Mac OS X, and Linux.
--
-- @tparam string url the URL to open
function rtk.open_url(url)
    if rtk.os.windows then
        reaper.ExecProcess(string.format('cmd.exe /C start /B "" "%s"', url), -2)
    elseif rtk.os.mac then
        -- On Mac, open doesn't block, so we can just use os.execute()
        os.execute(string.format('open "%s"', url))
    elseif rtk.os.linux then
        reaper.ExecProcess(string.format('xdg-open "%s"', url), -2)
    else
        reaper.ShowMessageBox(
            "Sorry, I don't know how to open URLs on this operating system.",
            "Unsupported operating system", 0
        )
    end
end

--- Generates a random UUID4.
--
-- @treturn string a [standard formatted random UUID4](https://en.wikipedia.org/wiki/Universally_unique_identifier)
function rtk.uuid4()
    return reaper.genGuid():sub(2, -2):lower()
end

--- Returns the contents of the given filename.
--
-- @tparam string fname the path to the file to read
-- @treturn string|nil the contents of the file, or nil if there was an error
-- @treturn string|nil an error message if the read failed, otherwise nil if it succeeded
function rtk.file.read(fname)
    local f, err = io.open(fname)
    if f then
        local contents = f:read("*all")
        f:close()
        return contents, nil
    else
        return nil, err
    end
end

--- Writes the given contents to a file.
--
-- The file is replaced if it exists.
--
-- @tparam string fname the path to the file to write
-- @tparam string contents the data to write to the file
-- @treturn string|nil nil if the write succeeded, otherwise will be an error message
--  indicating the reason for failure
function rtk.file.write(fname, contents)
    local f, err = io.open(fname, "w")
    if f then
        f:write(contents)
        f:close()
    else
        return err
    end
end

--- Returns the size in bytes of the given filename.
--
-- @tparam string fname the path to the file whose size to check
-- @treturn number|nil the number of bytes in the file, or nil if there was an error
-- @treturn string|nil an error message if the check failed, otherwise nil if it succeeded
function rtk.file.size(fname)
    local f, err = io.open(fname)
    if f then
        local size = f:seek("end")
        f:close()
        return size, nil
    else
        return nil, err
    end
end

--- Checks to see if a filename exists.
--
-- @tparam string fname the path to the file to check for existence
-- @treturn boolean true if the file exists, or false otherwise
function rtk.file.exists(fname)
    return reaper.file_exists(fname)
end

--- Gets the contents of the system clipboard.
--
-- @note
--  This function requires the [SWS extension](https://www.sws-extension.org/).
--  It won't raise an error if SWS isn't available, but you can also check
--  `rtk.has_sws_extension` before calling if you wish.
--
-- @treturn string|nil the contents of the clipboard (which may be the empty string if
--   the clipboard was empty) or nil if the SWS extension wasn't available.
function rtk.clipboard.get()
    if not reaper.CF_GetClipboardBig then
        return
    end
    local fast = reaper.SNM_CreateFastString("")
    local data =  reaper.CF_GetClipboardBig(fast)
    reaper.SNM_DeleteFastString(fast)
    return data
end

--- Sets the contents of the system clipboard.
--
-- @note
--  This function requires the [SWS extension](https://www.sws-extension.org/).
--  It won't raise an error if SWS isn't available, but you can also check
--  `rtk.has_sws_extension` before calling if you wish.
--
-- @treturn boolean false if the SWS extension wasn't available, true otherwise.
function rtk.clipboard.set(data)
    if not reaper.CF_SetClipboard then
        return false
    end
    reaper.CF_SetClipboard(data)
    return true
end

--- Draws a rounded rectangle with optional fill on the curent drawing target.
--
-- @tparam number x the left edge of the rectangle in pixels
-- @tparam number y the top edge of the rectangle in pixels
-- @tparam number w the width of the rectangle in pixels
-- @tparam number h the height of the rectangle in pixels
-- @tparam number r the radius of the rounded border
-- @tparam number|nil thickness the pixel thickness of the rectangle's border,
--   where `0` means the rectangle will be filled (default 1, which means
--   a non-filled rectangle with a 1 pixel border)
-- @tparam boolean|nil aa whether the edges of the border should be anti-aliased (default true)
function rtk.gfx.roundrect(x, y, w, h, r, thickness, aa)
    thickness = thickness or 1
    aa = aa or 1
    --  Unlike gfx.rect(), gfx.roundrect() seems to have an off-by-one issue.
    w = w - 1
    h = h - 1

    if thickness == 1 then
        gfx.roundrect(x, y, w, h, r, aa)
    elseif thickness > 1 then
        -- Not practical for large radii but the illusion holds up for small values
        for i = 0, thickness - 1 do
            gfx.roundrect(x+i, y+i, w - i*2, h - i*2, r, aa)
        end
    elseif h >= 2*r then
        -- Logic lifted from: https://forums.cockos.com/showpost.php?p=1435244&postcount=23
        -- Top left corner
        gfx.circle(x+r, y+r, r, 1, aa)
        -- Top right corner
        gfx.circle(x+w-r, y+r, r, 1, aa)
        -- Bottom left corner
        gfx.circle(x+r, y+h-r, r, 1, aa)
        -- Bottom right corner
        gfx.circle(x+w-r, y+h-r, r, 1, aa)
        -- Left edge
        gfx.rect(x, y+r, r, h - r*2)
        -- Right edge
        gfx.rect(x+w-r, y+r, r+1, h - r*2)
        -- Middle
        gfx.rect(x+r, y, w - r*2, h+1)
    else
        -- Radius is sufficiently large that one circle will span an entire edge
        r = h/2 - 1
        -- Left edge
        gfx.circle(x+r, y+r, r, 1, aa)
        -- Right edge
        gfx.circle(x+w-r, y+r, r, 1, aa)
        -- Middle
        gfx.rect(x+r, y, w - r*2, h)
    end
end


rtk.IndexManager = rtk.class('rtk.IndexManager')
function rtk.IndexManager:initialize(first, last)
    self.first = first
    self.last = last
    -- Rebased to index offset 0
    self._last = last - first
    -- Array of 32-bit bitmaps where each element is a chunk of 32 indexes
    self._bitmaps = {}
    -- Highest idx ever allocated
    self._tail_idx = nil
    -- Last idx allocated.
    self._last_idx = nil
end

function rtk.IndexManager:_set(idx, value)
    local elem = math.floor(idx / 32) + 1
    local count = #self._bitmaps
    if elem > count then
        -- Expand bitmap array if necessary
        for n = 1, elem - count do
            self._bitmaps[#self._bitmaps + 1] = 0
        end
    end
    local bit = idx % 32
    if value ~= 0 then
        self._bitmaps[elem] = self._bitmaps[elem] | (1 << bit)
    else
        self._bitmaps[elem] = self._bitmaps[elem] & ~(1 << bit)
    end
end

function rtk.IndexManager:set(idx, value)
    return self:_set(idx - self.first, value)
end

function rtk.IndexManager:_get(idx)
    local elem = math.floor(idx / 32) + 1
    if elem > #self._bitmaps then
        return false
    end
    local bit = idx % 32
    return self._bitmaps[elem] & (1 << bit) ~= 0
end

function rtk.IndexManager:get(idx)
    return self:_get(idx - self.first)
end

function rtk.IndexManager:_search_free()
    -- Start at the element we last issued an index from, under the assumption
    -- that free slots are likely to chunk together.
    -- FIXME: except we don't do that.
    local start = self._last_idx < self._last and self._last_idx or 0
    local bit = start % 32
    local startelem = math.floor(start / 32) + 1
    for elem = 1, #self._bitmaps do
        local bitmap = self._bitmaps[elem]
        if bitmap ~= 0xffffffff then
            for bit=bit, 32 do
                if bitmap & (1 << bit) == 0 then
                    return elem, bit
                end
            end
        end
        bit = 0
    end
end

function rtk.IndexManager:_next()
    local idx
    if not self._tail_idx then
        -- First issued index
        idx = 0
    elseif self._tail_idx < self._last then
        -- We still have free indices at the tail
        idx = self._tail_idx + 1
    else
        -- Nothing free at the tail.  We need to go searching.
        local elem, bit = self:_search_free()
        if elem == #self._bitmaps and bit >= self._last % 32 then
            -- No free indexes
            return nil
        end
        idx = (elem - 1) * 32 + bit
    end
    self._last_idx = idx
    self._tail_idx = self._tail_idx and math.max(self._tail_idx, idx) or idx
    self:_set(idx, 1)
    return idx + self.first
end

function rtk.IndexManager:next(gc)
    local idx = self:_next()
    if not idx and gc then
        collectgarbage('collect')
        idx = self:_next()
    end
    return idx
end

function rtk.IndexManager:release(idx)
    self:_set(idx - self.first, 0)
end


--- Monkey Patches.
--
-- Several functions are added to native Lua namespaces.
--
-- @section monkeypatch

--- A value representing infinity.
--
-- Useful for conditional expressions involving `math.min()` or `math.max()`, e.g.
--
-- @code
--   val = math.min(should_clamp and minval or math.inf, val)
math.inf = 1/0

--- Rounds a decimal value to the nearest integer.
--
-- Fractional values greater than or equal to 0.5 are rounded up, otherwise will
-- be rounded down.
--
-- @tparam number n the value to round
-- @treturn number the rounded value
function math.round(n)
    return n and (n % 1 >= 0.5 and math.ceil(n) or math.floor(n))
end


--- Checks if a string starts with the given prefix.
--
-- @example
--   if line:startswith('--') then
--       continue
--   end
--
-- @tparam string s the string whose prefix to check
-- @tparam string prefix the string to check if `s` begins with
-- @tparam boolean|nil insensitive whether the test should be case-insensitive
--   (defaults to false)
-- @treturn boolean true if the string starts with the prefix, false otherwise
function string.startswith(s, prefix, insensitive)
    if insensitive == true then
        return s:lower():sub(1, string.len(prefix)) == prefix:lower()
    else
        return s:sub(1, string.len(prefix)) == prefix
    end
end

--- Splits a string into an array based on the given delimiter.
--
-- The delimiter is not included in the array elements.
--
-- @example
--   local line = 'Bob:Smith:42'
--   local first, last, age = table.unpack(line:split(':'))
--
-- @tparam string s the string to split
-- @tparam string|nil delim the delimiter that separates the parts (defaults to any
--   whitespace character)
-- @tparam bool|nil filter if true, filters out empty string fields from the result
--   (default false)
-- @treturn table the individual parts (without the delimiter)
function string.split(s, delim, filter)
    local parts = {}
    for word in s:gmatch('[^' .. (delim or '%s') .. ']' .. (filter and '+' or '*')) do
        parts[#parts+1] = word
    end
    return parts
end

--- Removes any leading or trailing whitespace from a string.
--
-- @tparam string s the string to strip
-- @treturn string the string any leading or trailing whitespace removed.
function string.strip(s)
    return s:match('^%s*(.-)%s*$')
end

--- Hashes the string to a 63-bit number.
--
-- This uses a simple but fast algorithm with reasonably good distribution by
-- Daniel Bernstein called djb2.
--
-- @tparam string s the string to hash
-- @tparam number the numeric hash of the strong.
function string.hash(s)
    local hash = 5381
    for i = 1, #s do
        hash = ((hash << 5) + hash) + s:byte(i)
    end
    return hash & 0x7fffffffffffffff
end


local function val_to_str(v, seen)
    if "string" == type(v) then
        v = string.gsub(v, "\n", "\\n")
        if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v, '"', '\\"') .. '"'
    else
        if type(v) == 'table' and not v.__tostring then
            return seen[tostring(v)] and '<recursed>' or table.tostring(v, seen)
        else
            return tostring(v)
        end
        return "table" == type(v) and table.tostring(v, seen) or tostring(v)
    end
end

local function key_to_str(k, seen)
    if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. val_to_str(k, seen) .. "]"
    end
end

local function _table_tostring(tbl, seen)
    local result, done = {}, {}
    seen = seen or {}
    local id = tostring(tbl)
    seen[id] = 1
    for k, v in ipairs(tbl) do
        table.insert(result, val_to_str(v, seen))
        done[k] = true
    end
    for k, v in pairs(tbl) do
        if not done[k] then
            table.insert(result, key_to_str(k, seen) .. "=" .. val_to_str(v, seen))
        end
    end
    seen[id] = nil
    return "{" .. table.concat( result, "," ) .. "}"
end

--- Converts a table to a printable string.
--
-- This is the reverse of `table.fromstring()`.
--
-- @note
--   Circular references are not handled and will blow the stack, and so this is
--   useful for debugging but not much else.
--
-- @tparam table tbl the table to stringify
-- @treturn string the stringified table, e.g. `{1, 2, foo='bar', [5]=42}`
function table.tostring(tbl)
    return _table_tostring(tbl)
end

--- Parses a stringified table into an actual Lua table.
--
-- This is the reverse of `table.tostring()`.
--
-- If the string is not a syntactically valid Lua table, a runtime error will
-- be thrown.  You can use `rtk.call()` to handle it (or of course Lua's native
-- `xpcall()`.
--
-- @warning Not safe
--   The implementation uses Lua's `load()` which means this is not safe for
--   untrusted data.  If you need a proper serialization solution, consider
--   using something like [json](https://github.com/rxi/json.lua) instead.
--
-- @tparam string str the table represented as a string
-- @treturn table the parsed table
function table.fromstring(str)
    return load('return ' .. str)()
end

--- Merges the fields from one table into another.
--
-- Fields that already exist in the destination table will be replaced if
-- they exist in the source.
--
-- @example
--   self.attrs = table.merge(attrs, {
--       foo='hello',
--       bar='world',
--  })
--
-- @tparam table dst the table to update
-- @tparam table src the table whose values to copy into `dst`
-- @treturn table returns dst back for convenience, however `dst` will be modified
--   in place and a new table is *not* created.
function table.merge(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

--- Creates a shallow copy of a table.
--
-- A shallow copy is one where the new table has all the same fields as the
-- original table, but any nested tables are not copied and will be referenced
-- in both the original and new table.
--
-- @tparam table t the table to shallow-copy
-- @tparam table|nil merge if not nil, the fields from this table will be merged
--   into the shallow copy (see `rtk.merge()`).
-- @treturn table a new table with the same fields as `t` plus `merge` if provided
function table.shallow_copy(t, merge)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    if merge then
        table.merge(copy, merge)
    end
    return copy
end

--- Returns an array of field names (or keys) from the given table.
--
-- Order is not deterministic.
--
-- @example
--   local t = {foo=42, bar='hello', baz='world'}
--   -- Prints {"foo", "bar", "baz"} (or possibly in a different order)
--   log.info('keys are %s', table.tostring(table.keys(t))
--
-- @tparam table t the table whose keys to return
-- @treturn table a new table containing all the field names (or indices) in `t`
function table.keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        keys[#keys+1] = k
    end
    return keys
end

--- Returns an array of field values from the given table.
--
-- @example
--   local t = {foo=42, bar='hello', baz='world'}
--   -- Prints {42, "hello", "world"} (or possibly in a different order)
--   log.info('values are %s', table.tostring(table.values(t))
--
-- @tparam table t the table whose values to return
-- @treturn table a new table containing all the field values in `t`
function table.values(t)
    local values = {}
    for _, v in pairs(t) do
        values[#values+1] = v
    end
    return values
end