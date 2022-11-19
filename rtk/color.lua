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

rtk.color = {}

--- Functions to parse, convert, and otherwise manage colors.
--
-- This module doesn't need to be explicitly loaded as all functions are automatically
-- available in the `rtk` namespace when loading `rtk`.
--
-- @module color

--- Color Value Formats.
--
--  Except where indicated, functions and attributes across rtk that take a color value
--  can be specified in one of the following formats:
--
--  1. `'name'`: the case-insensitive name of a
--     [CSS color keyword](https://www.w3schools.com/cssref/css_colors.asp)
--     where alpha is assumed to be 1.0
--  2. `'name#aa'`: the case-insensitive name of a
--     [CSS color keyword](https://www.w3schools.com/cssref/css_colors.asp)
--     where alpha specified as a two hexdigit code delimited by a hash
--  3. `'#rrggbb'` : HTML hex style string where alpha is assumed to be 1.0
--  4. `'#rrggbbaa'`: HTML hex style string with alpha
--  5. `{r, g, b}`: 3-element table holding red, green, and blue numeric values
--     between 0 and 1.0
--  6. `{r, g, b, a}`: 4-element table, as above plus alpha between 0 and 1.0
--  7. A 24-bit packed integer holding red in the low byte, green in the middle byte,
--     and blue in the high byte, and where an alpha of 1.0 is assumed.
--
-- While many formats are supported, the above encodings all ultimately refer to colors
-- in the RGB colorspace.  Colors in other colorspaces (such as HSL or HSV) can be
-- converted using one of the functions in this module.
--
-- @example
--   -- Creates a text widget with aquamarine color that's translucent (format #2 above)
--   local t = rtk.Text{'Hello world', color='aquamarine#9c'}
--
--   -- Sets the current graphic context to red (format #3 above)
--   rtk.color.set('#ff0000')
--
--   -- Creates a container with a translucent white background (format #4 above)
--   local c = rtk.Container{bg='#ffffff55'}
--
--   -- Clears an image to a burgundy color (format #5 above)
--   img:clear({0.5, 0, 0.25})
--
-- @section colortype

--- Module API
-- @section api
-- @compact fields

--- Sets the graphic context to the given color before drawing to a surface
-- set by `rtk.pushdest()`.
--
-- @tparam colortype color the color to set the graphics context to
-- @tparam number|nil amul if not nil, the alpha channel is multiplied by this value
function rtk.color.set(color, amul)
    local r, g, b, a = rtk.color.rgba(color)
    if amul then
        a = a * amul
    end
    gfx.set(r, g, b, a)
end


--- Decodes a color value into its constituent red, green, blue, and alpha parts.
--
-- Although @{colortype|various formats} are supported, the given color must be
-- in the RGB colorspace.  This function just normalizes any supported color
-- format into its individual channels.
--
-- @tparam colortype color the color value to parse
-- @treturn number the red channel from 0.0 to 1.0
-- @treturn number the green channel from 0.0 to 1.0
-- @treturn number the blue channel from 0.0 to 1.0
-- @treturn number the alpha channel from 0.0 to 1.0, where 1.0 is assumed if the
--   given color value doesn't provide any alpha channel information.
function rtk.color.rgba(color)
    local tp = type(color)
    if tp == 'table' then
        local r, g, b, a = table.unpack(color)
        return r, g, b, a or 1
    elseif tp == 'string' then
        local hash = color:find('#')
        if hash == 1 then
            return rtk.color.hex2rgba(color)
        else
            local a
            if hash then
                -- In the form colorname#alpha
                a = (tonumber(color:sub(hash + 1), 16) or 0) / 255
                color = color:sub(1, hash - 1)
            end
            local resolved = rtk.color.names[color:lower()]
            if not resolved then
                log.warning('rtk: color "%s" is invalid, defaulting to black', color)
                return 0, 0, 0, a or 1
            end
            local r, g, b, a2 = rtk.color.hex2rgba(resolved)
            return r, g, b, a or a2
        end
    elseif tp == 'number' then
        local r, g, b = color & 0xff, (color >> 8) & 0xff, (color >> 16) & 0xff
        return r/255, g/255, b/255, 1
    else
        error('invalid type ' .. tp .. ' passed to rtk.color.rgba()')
    end
end

--- Returns the [relative luminance](https://en.wikipedia.org/wiki/Relative_luminance)
-- of the given color.
--
-- @tparam colortype color the color whose luminance to calculate
-- @tparam colortype|nil under if the given color has an alpha channel below 1.0 then
--   if this parameter is provided, it describes the color underneath so the
--   luminance returned is calculated over two blended colors
-- @treturn number the relative luminance from 0.0 to 1.0
function rtk.color.luma(color, under)
    if not color then
        return under and rtk.color.luma(under) or 0
    end
    local r, g, b, a = rtk.color.rgba(color)
    local luma = (0.2126 * r + 0.7152 * g + 0.0722 * b)
    if a < 1.0 then
        luma = math.abs((luma * a) + (under and (rtk.color.luma(under) * (1-a)) or 0))
    end
    return luma
end


--- Converts a color from RGB(A) to HSV(A) colorspace.
--
-- The alpha channel is optional and if it's encoded in the supplied color
-- it's simply passed through in the return value.
--
-- @tparam colortype color the color to convert to HSV
-- @treturn number the hue channel from 0.0 to 1.0
-- @treturn number the saturation channel from 0.0 to 1.0
-- @treturn number the value (aka brightness) channel from 0.0 to 1.0
-- @treturn number the alpha channel from 0.0 to 1.0, which defaults to
--   1.0 if the given color lacks an alpha channel
function rtk.color.hsv(color)
    local r, g, b, a = rtk.color.rgba(color)
    local h, s, v

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min
    if delta == 0 then
        h = 0
    elseif max == r then
        h = 60 * (((g - b) / delta) % 6)
    elseif max == g then
        h = 60 * (((b - r) / delta) + 2)
    elseif max == b then
        h = 60 * (((r - g) / delta) + 4)
    end
    s = (max == 0) and 0 or (delta / max)
    v = max
    return h/360.0, s, v, a
end

--- Converts a color from RGB(A) to HSL(A) colorspace.
--
-- The alpha channel is optional and if it's encoded in the supplied color
-- it's simply passed through in the return value.
--
-- @tparam colortype color the color to convert to HSL
-- @treturn number the hue channel from 0.0 to 1.0
-- @treturn number the saturation channel from 0.0 to 1.0
-- @treturn number the lightness channel from 0.0 to 1.0
-- @treturn number the alpha channel from 0.0 to 1.0, which defaults to
--   1.0 if the given color lacks an alpha channel
function rtk.color.hsl(color)
    local r, g, b, a = rtk.color.rgba(color)
    local h, s, l

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    l = (max + min) / 2
    if max == min then
        -- Color is achromatic so has no hue or saturation
        h = 0
        s = 0
    else
        local delta = max - min
        if l > 0.5 then
            s = delta / (2 - max - min)
        else
            s = delta / (max + min)
        end
        if max == r then
            h = (g - b) / delta + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / delta + 2
        else
            h = (r - g) / delta + 4
        end
        h = h / 6
    end
    return h, s, l, a
end


--- Converts a color to a 24-bit packed integer.
--
-- Note that packed values don't include alpha channel information, so if the
-- given color includes an alpha value it is ignored.
--
-- @example
--   -- This example opens a color picker (using the SWS API) starting with red.
--   -- The 'true' here and below has these two functions convert to and from
--   -- OS-native integer format.
--   local ok, color = reaper.GR_SelectColor(0, rtk.color.int('#ff0000', true))
--   if ok ~= 0 then
--      log.info('returned color was %s', rtk.color.int2hex(color, true))
--   end
--
-- @tparam colortype color the color to modify
-- @tparam boolean|nil native if true, the returned value will be filtered
--   through `rtk.color.convert_native()`
-- @treturn number a 24-bit packed integer with red in the low byte and blue
--   in the high byte
function rtk.color.int(color, native)
    local r, g, b, _ = rtk.color.rgba(color)
    local n = (r * 255) + ((g * 255) << 8) + ((b * 255) << 16)
    return native and rtk.color.convert_native(n) or n
end

--- Modifies a color by applying a multiplier against hue, saturation, value, and alpha.
--
-- The modification occurs in the HSV colorspace.  Note that in HSV, modifying value (V)
-- has a side effect on saturation but preserves hue (H).  In contrast, in HSL (hue,
-- saturation, lightness), modifying lightness implicitly affects hue.
--
-- So this function works in HSV rather than HSL as it's less visually disruptive to have
-- side effects on saturation.  But if you need to make changes in the HSL colorspace, use
-- `rtk.color.hsl()` and `rtk.color.hsl2rgb()`.
--
-- @tparam colortype color the color to modify
-- @tparam number|nil hmul the amount to multiply the hue channel
--   (if nil, no change to hue is made)
-- @tparam number|nil smul the amount to multiply the saturation channel
--   (if nil, no change to saturation is made)
-- @tparam number|nil vmul the amount to multiply the value (brightness) channel
--  (if nil, no change to brightness is made)
-- @tparam number|nil amul the amount to multiply the hue channel
--  (if nil, no change to alpha is made)
--
-- @treturn number the modified red channel from 0.0 to 1.0
-- @treturn number the modified green channel from 0.0 to 1.0
-- @treturn number the modified blue channel from 0.0 to 1.0
-- @treturn number the modified alpha channel from 0.0 to 1.0
function rtk.color.mod(color, hmul, smul, vmul, amul)
    local h, s, v, a = rtk.color.hsv(color)
    return rtk.color.hsv2rgb(
        rtk.clamp(h * (hmul or 1), 0, 1),
        rtk.clamp(s * (smul or 1), 0, 1),
        rtk.clamp(v * (vmul or 1), 0, 1),
        rtk.clamp(a * (amul or 1), 0, 1)
    )
end


--- Converts between a REAPER-native numeric color and an OS-native numeric color.
--
-- It is necessary to call this function when interacting with non-rtk functions that
-- need to receive OS-native color values, for example `reaper.GR_SelectColor()`.
--
-- This function works in both directions, so calling it twice (with the second call
-- receiving the output of the first call) returns the original value.
--
-- @note
--   It's probably more convenient to use `rtk.color.int()` or `rtk.color.int2hex()`,
--   both of which take a flag to convert between an OS-native numeric color.
--
-- @tparam number n the *numeric* color that is either REAPER- or OS-native
-- @treturn number the converted color
function rtk.color.convert_native(n)
    if rtk.os.mac or rtk.os.linux then
        return rtk.color.flip_byte_order(n)
    else
        return n
    end
end

--- Changes the endianness of the given color represented as a 24-bit number.
--
-- Unlike `rtk.color.convert_native()` that only changes the byte order on
-- platforms that need it (Mac and Linux, specifically), this function
-- *always* flips the byte order.
--
-- This is necessary when using the js_ReaScriptAPI GDI functions, which
-- always takes values in the opposite byte order.
--
-- @tparam number color the 24-bit packed numeric color value
-- @treturn number the color whose byte order has been inverted
function rtk.color.flip_byte_order(color)
    return ((color & 0xff) << 16) | (color & 0xff00) | ((color >> 16) & 0xff)
end

--- Gets the background color of the current REAPER theme.
--
-- This function requres either REAPER 6.11 or later, or the SWS Extension.
--
-- @treturn string|nil the HTML-style hex color string of the current theme's
--   background in the form #rrggbbaa, or nil if the system is running a version
--   of REAPER prior to 6.11 without the SWS extension.
function rtk.color.get_reaper_theme_bg()
    if reaper.GetThemeColor then
        -- Use the empty track list area as the target background color.
        local r = reaper.GetThemeColor('col_tracklistbg', 0)
        if r ~= -1 then
            return rtk.color.int2hex(r)
        end
    end
    if reaper.GSC_mainwnd then
        -- Fallback for older versions of Reaper (before 6.11) which lack GetThemeColor()
        --
        -- 5 is COLOR_WINDOW, which is the window background.  20 is COLOR_3DHILIGHT which
        -- isn't perfect but seems more reliable on Windows because COLOR_WINDOW returns a
        -- light gray for the default theme.
        --
        -- See https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsyscolor
        local idx = (rtk.os.mac or rtk.os.linux) and 5 or 20
        return rtk.color.int2hex(reaper.GSC_mainwnd(idx))
    end
end

--- Determines whether light or dark icons should be used given a background color.
--
-- Dark icons will be used when the ultimate luminance of the given color(s)
-- exceeds `rtk.light_luma_threshold`.
--
-- @tparam string|table color the background color (format per `rtk.color.set`)
-- @tparam string|table|nil under if defined, defines the color underneath, which is used
--   if the `color` parameter has has an alpha channel value less than 1.
-- @treturn string either the literal string `light` or `dark` depending which icon style
--   is indicated given the background color
function rtk.color.get_icon_style(color, under)
    return rtk.color.luma(color, under) > rtk.light_luma_threshold and 'dark' or 'light'
end

--- Converts an HTML-style hex formatted color to RGBA.
--
-- It's recommended to use `rtk.color.rgba()` instead, which calls this function behind
-- the scenes.
--
-- @tparam string s a color in the form `#rrggbb` or `#rrggbbaa`
-- @treturn number the red channel from 0.0 to 1.0
-- @treturn number the green channel from 0.0 to 1.0
-- @treturn number the blue channel from 0.0 to 1.0
-- @treturn number the alpha channel from 0.0 to 1.0, where 1.0 is assumed if the
--   given color string is in the form `#rrggbb`.
function rtk.color.hex2rgba(s)
    local r = tonumber(s:sub(2, 3), 16) or 0
    local g = tonumber(s:sub(4, 5), 16) or 0
    local b = tonumber(s:sub(6, 7), 16) or 0
    local a = tonumber(s:sub(8, 9), 16)
    return r / 255, g / 255, b / 255, a and a / 255 or 1.0
end

--- Converts an RGBA color to an HTML-style hex formatted string.
--
-- @tparam number r the red channel from 0.0 to 1.0
-- @tparam number g the green channel from 0.0 to 1.0
-- @tparam number b the blue channel from 0.0 to 1.0
-- @tparam number|nil a the optional alpha channel from 0.0 to 1.0
-- @treturn string a color in the form `#rrggbb` if no alpha channel was given
--   or if alpha is 1.0, otherwise the color will be in the form `#rrggbbaa`
function rtk.color.rgba2hex(r, g, b, a)
    r = math.ceil(r * 255)
    b = math.ceil(b * 255)
    g = math.ceil(g * 255)
    if not a or a == 1.0 then
        return string.format('#%02x%02x%02x', r, g, b)
    else
        return string.format('#%02x%02x%02x%02x', r, g, b, math.ceil(a * 255))
    end
end

--- Convert a 24-bit packed integer color to an HTML-style hex formatted color string.
--
-- If you have a packed color value with a different byte order, you can first
-- call `rtk.color.flip_byte_order()`.
--
-- To convert in the other direction (a hex value to a packed integer) you can
-- use `rtk.color.int()`.
--
-- @tparam number n a 24-bit packed integer holding red in the low byte and
--  blue in the high byte.
-- @tparam boolean|nil native if true, the given value will be filtered
--   through `rtk.color.convert_native()` before converting to hex.
-- @treturn string an HTML-style hex formatted string in the form `#rrggbb`.
function rtk.color.int2hex(n, native)
    if native then
        n = rtk.color.convert_native(n)
    end
    local r, g, b = n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff
    return string.format('#%02x%02x%02x', r, g, b)
end

--- Converts an HSV(A) color to RGB(A).
--
-- @tparam number h the hue channel from 0.0 to 1.0
-- @tparam number s the saturation channel from 0.0 to 1.0
-- @tparam number v the value (aka brightness) channel from 0.0 to 1.0
-- @tparam number|nil a the optional alpha channel from 0.0 to 1.0
-- @treturn number the red channel from 0.0 to 1.0
-- @treturn number the green channel from 0.0 to 1.0
-- @treturn number the blue channel from 0.0 to 1.0
-- @treturn number the alpha channel from 0.0 to 1.0, or 1.0 if `a` was nil
function rtk.color.hsv2rgb(h, s, v, a)
    if s == 0 then
        return v, v, v, a or 1.0
    end

    local i = math.floor(h * 6)
    local f = (h * 6) - i
    local p = v * (1 - s)
    local q = v * (1 - s*f)
    local t = v * (1 - s*(1-f))
    if i == 0 or i == 6 then
        return v, t, p, a or 1.0
    elseif i == 1 then
        return q, v, p, a or 1.0
    elseif i == 2 then
        return p, v, t, a or 1.0
    elseif i == 3 then
        return p, q, v, a or 1.0
    elseif i == 4 then
        return t, p, v, a or 1.0
    elseif i == 5 then
        return v, p, q, a or 1.0
    else
        log.error('invalid hsv (%s %s %s) i=%s', h, s, v, i)
    end
end

local function hue2rgb(p, q, t)
    if t < 0 then
        t = t + 1
    elseif t > 1 then
        t = t - 1
    end
    if t < 1/6 then
        return p + (q - p) * 6 * t
    elseif t < 1/2 then
        return q
    elseif t < 2/3 then
        return p + (q - p) * (2/3 - t) * 6
    else
        return p
    end
end

--- Converts an HSL(A) color to RGB(A).
--
-- @tparam number h the hue channel from 0.0 to 1.0
-- @tparam number s the saturation channel from 0.0 to 1.0
-- @tparam number l the lightness channel from 0.0 to 1.0
-- @tparam number|nil a the optional alpha channel from 0.0 to 1.0
-- @treturn number the red channel from 0.0 to 1.0
-- @treturn number the green channel from 0.0 to 1.0
-- @treturn number the blue channel from 0.0 to 1.0
-- @treturn number the alpha channel from 0.0 to 1.0, or 1.0 if `a` was nil
function rtk.color.hsl2rgb(h, s, l, a)
    local r, g, b
    if s == 0 then
        r, g, b = l, l, l
    else
        local q = (l < 0.5) and (l * (1 + s)) or (l+s - l*s)
        local p = 2 * l - q
        r = hue2rgb(p, q, h + 1/3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1/3)
    end
    return r, g, b, a or 1.0
end

--- A table that maps [CSS color names](https://www.w3schools.com/cssref/css_colors.asp) to
-- HTML-style hex color strings. All color names are lowercase, without spaces or special
-- characters.  A special `transparent` color name is included that has a zero alpha channel,
-- which could be used with widget borders, for example, to ensure the border space is consumed
-- but is otherwise invisible.
--
-- You can also insert your own custom color names into this table:
--
-- @code
--   rtk.color.names['mycustomcolor'] = '#12ab34'
--
-- @meta read/write
-- @type table
rtk.color.names = {
    transparent = "#ffffff00",
    black = '#000000',
    silver = '#c0c0c0',
    gray = '#808080',
    white = '#ffffff',
    maroon = '#800000',
    red = '#ff0000',
    purple = '#800080',
    fuchsia = '#ff00ff',
    green = '#008000',
    lime = '#00ff00',
    olive = '#808000',
    yellow = '#ffff00',
    navy = '#000080',
    blue = '#0000ff',
    teal = '#008080',
    aqua = '#00ffff',
    orange = '#ffa500',
    aliceblue = '#f0f8ff',
    antiquewhite = '#faebd7',
    aquamarine = '#7fffd4',
    azure = '#f0ffff',
    beige = '#f5f5dc',
    bisque = '#ffe4c4',
    blanchedalmond = '#ffebcd',
    blueviolet = '#8a2be2',
    brown = '#a52a2a',
    burlywood = '#deb887',
    cadetblue = '#5f9ea0',
    chartreuse = '#7fff00',
    chocolate = '#d2691e',
    coral = '#ff7f50',
    cornflowerblue = '#6495ed',
    cornsilk = '#fff8dc',
    crimson = '#dc143c',
    cyan = '#00ffff',
    darkblue = '#00008b',
    darkcyan = '#008b8b',
    darkgoldenrod = '#b8860b',
    darkgray = '#a9a9a9',
    darkgreen = '#006400',
    darkgrey = '#a9a9a9',
    darkkhaki = '#bdb76b',
    darkmagenta = '#8b008b',
    darkolivegreen = '#556b2f',
    darkorange = '#ff8c00',
    darkorchid = '#9932cc',
    darkred = '#8b0000',
    darksalmon = '#e9967a',
    darkseagreen = '#8fbc8f',
    darkslateblue = '#483d8b',
    darkslategray = '#2f4f4f',
    darkslategrey = '#2f4f4f',
    darkturquoise = '#00ced1',
    darkviolet = '#9400d3',
    deeppink = '#ff1493',
    deepskyblue = '#00bfff',
    dimgray = '#696969',
    dimgrey = '#696969',
    dodgerblue = '#1e90ff',
    firebrick = '#b22222',
    floralwhite = '#fffaf0',
    forestgreen = '#228b22',
    gainsboro = '#dcdcdc',
    ghostwhite = '#f8f8ff',
    gold = '#ffd700',
    goldenrod = '#daa520',
    greenyellow = '#adff2f',
    grey = '#808080',
    honeydew = '#f0fff0',
    hotpink = '#ff69b4',
    indianred = '#cd5c5c',
    indigo = '#4b0082',
    ivory = '#fffff0',
    khaki = '#f0e68c',
    lavender = '#e6e6fa',
    lavenderblush = '#fff0f5',
    lawngreen = '#7cfc00',
    lemonchiffon = '#fffacd',
    lightblue = '#add8e6',
    lightcoral = '#f08080',
    lightcyan = '#e0ffff',
    lightgoldenrodyellow = '#fafad2',
    lightgray = '#d3d3d3',
    lightgreen = '#90ee90',
    lightgrey = '#d3d3d3',
    lightpink = '#ffb6c1',
    lightsalmon = '#ffa07a',
    lightseagreen = '#20b2aa',
    lightskyblue = '#87cefa',
    lightslategray = '#778899',
    lightslategrey = '#778899',
    lightsteelblue = '#b0c4de',
    lightyellow = '#ffffe0',
    limegreen = '#32cd32',
    linen = '#faf0e6',
    magenta = '#ff00ff',
    mediumaquamarine = '#66cdaa',
    mediumblue = '#0000cd',
    mediumorchid = '#ba55d3',
    mediumpurple = '#9370db',
    mediumseagreen = '#3cb371',
    mediumslateblue = '#7b68ee',
    mediumspringgreen = '#00fa9a',
    mediumturquoise = '#48d1cc',
    mediumvioletred = '#c71585',
    midnightblue = '#191970',
    mintcream = '#f5fffa',
    mistyrose = '#ffe4e1',
    moccasin = '#ffe4b5',
    navajowhite = '#ffdead',
    oldlace = '#fdf5e6',
    olivedrab = '#6b8e23',
    orangered = '#ff4500',
    orchid = '#da70d6',
    palegoldenrod = '#eee8aa',
    palegreen = '#98fb98',
    paleturquoise = '#afeeee',
    palevioletred = '#db7093',
    papayawhip = '#ffefd5',
    peachpuff = '#ffdab9',
    peru = '#cd853f',
    pink = '#ffc0cb',
    plum = '#dda0dd',
    powderblue = '#b0e0e6',
    rosybrown = '#bc8f8f',
    royalblue = '#4169e1',
    saddlebrown = '#8b4513',
    salmon = '#fa8072',
    sandybrown = '#f4a460',
    seagreen = '#2e8b57',
    seashell = '#fff5ee',
    sienna = '#a0522d',
    skyblue = '#87ceeb',
    slateblue = '#6a5acd',
    slategray = '#708090',
    slategrey = '#708090',
    snow = '#fffafa',
    springgreen = '#00ff7f',
    steelblue = '#4682b4',
    tan = '#d2b48c',
    thistle = '#d8bfd8',
    tomato = '#ff6347',
    turquoise = '#40e0d0',
    violet = '#ee82ee',
    wheat = '#f5deb3',
    whitesmoke = '#f5f5f5',
    yellowgreen = '#9acd32',
    rebeccapurple = '#663399',
}