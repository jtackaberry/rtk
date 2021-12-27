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

--- Utility class to manage REAPER images.
--
-- Note that this isn't a widget and `rtk.Image` objects can't be added to containers. For
-- that, use `rtk.ImageBox` instead.  This is just a utility class to manipulate
-- REAPER-backed images at a low level.
--
-- Images are automatically freed as part of Lua garbage collection, with the underlying
-- REAPER buffer released for use by future rtk.Image objects.
--
-- @class rtk.Image
rtk.Image = rtk.class('rtk.Image')

--- Drawing Mode Constants.
--
-- These constants are used with the `mode` arguments in the various drawing methods.
-- They can be bitwise-ORed together.
--
-- @section modeconst
-- @compact

--- Default blending mode which considers both source and destination alpha
-- channels. Most of the time this is what you want.
rtk.Image.static.DEFAULT = 0
--- Blends source and destination by summing their color values together.
rtk.Image.static.ADDITIVE_BLEND = 1
--- Blends source and destination by subtracting the source color from the destination color.
rtk.Image.static.SUBTRACTIVE_BLEND = 128
--- Ignores the alpha channel from the source image treating all pixels as fully
-- opaque when blitting onto the destination.  Unless you need alpha blending, you
-- should use this mode for improved performance.
rtk.Image.static.NO_SOURCE_ALPHA = 2
--- When scaling images, filtering provides pixel interpolation to improve the quality
-- but comes at a cost. This disables filtering so the scaling algorithm is nearest
-- neighbor.
rtk.Image.static.NO_FILTERING  = 4
--- A combination of `NO_SOURCE_ALPHA` and `NO_FILTERING` which is the most efficient
-- drawing mode but obviously is only useful in certain circumstances.
rtk.Image.static.FAST_BLIT  = 2|4

-- Reaper supports image ids between 0 and 1023 (inclusive).
rtk.Image.static.ids = rtk.IndexManager(0, 1023)


--- Static Class Functions.
--
-- @section functions


local function _search_image_paths_list(fname, paths)
    if not paths or #paths == 0 then
        return
    end
    -- Fast path, check first registered directory
    local path = string.format('%s/%s', paths[1], fname)
    if rtk.file.exists(path) then
        return path
    end
    -- Wasn't in the first one.  Loop through remaining.
    if #paths > 1 then
        for i = 2, #paths do
            path = string.format('%s/%s', paths[i], fname)
            if rtk.file.exists(path) then
                return path
            end
        end
    end
end

-- Searches all registered image paths for the given filename and with
-- the given icon style if defined.  Returns the discovered path and
-- a bool to indicate whether the icon was found in the given iconstyle
-- path or the other one (such that the image will need to be recolored).
local function _search_image_paths(fname, style)
    if not style then
        local path = _search_image_paths_list(fname, rtk._image_paths)
        if path then
            return path, true
        end
        -- Image not found in non-icon paths, search icon paths as a
        -- last resort.
        style = rtk.theme.iconstyle
    end
    local path = _search_image_paths_list(fname, rtk._image_paths[style])
    if path then
        return path, true
    end
    -- Nothing found in the requested style, search through the other one.
    local otherstyle = style == 'light' and 'dark' or 'light'
    local path = _search_image_paths_list(fname, rtk._image_paths[otherstyle])
    if path then
        return path, false
    end
end


--- Create a new `rtk.Image` from a png image located in a previously registered icon path
-- via `rtk.add_image_search_path()`.
--
-- If only one or the other (light or dark) icon styles were registered with
-- `rtk.add_image_search_path()`, or if the the icon specified by `name` is available in
-- one path but not the other, it's still possible to request a specific `style`. In this
-- case, the icon will be filtered to be black if `style` is `dark` or white if `style` is
-- `light`.  But note in this case colored icons will be turned monochromatic.
--
-- If ultimately no suitable icon can be located, an error is logged and nil is
-- returned.  The caller can choose to use `make_placeholder_icon()` in a pinch.
--
-- @note
--   The main feature of this function is the (monochromatic) icon @{recolor|recoloring}
--   to match the current theme (if it's necessary).  To load an image without any
--   implicit modification, use `rtk.Image:load()`.
--
-- @example
--    local img = rtk.Image.make_icon('18-undo', 'light')
--
-- @tparam string name Filename of the icon without the extension
-- @tparam string|nil style Either `dark` or `light` indicating the icon luminance.  If
--   nil then the current theme icon style will be assumed.
-- @treturn rtk.Image|nil newly loaded image, or nil if icon could not be found (in which case
--   an error is logged to the console)
-- @meta static
function rtk.Image.static.make_icon(name, style)
    local img
    style = style or rtk.theme.iconstyle
    local path, matched = _search_image_paths(name .. '.png', style)
    if path then
        img = rtk.Image():load(path)
        if not matched then
            img:recolor(style == 'light' and '#ffffff' or '#000000')
        end
        img.style = style
    end
    if not img then
        log.error('rtk: rtk.Image.make_icon("%s"): icon not found in any icon path', name)
    end
    return img
end

--- Returns an icon with a red question mark that can be used to indicate icon
-- load failure without aborting the program.
--
-- @tparam number|nil w desired image width, nil implies 24
-- @tparam number|nil h desired image height, nil implies 24
-- @tparam string|nil style `dark` or `light` to indicate desired icon brightness.
--    If nil, then dark is assumed.
-- @treturn rtk.Image the new image
--
-- @code
--    local img = rtk.Image.make_icon('18-undo', 'light')
--    if not img then
--        img = rtk.Image.make_placeholder_icon(24, 24, 'light')
--    end
-- @meta static
function rtk.Image.static.make_placeholder_icon(w, h, style)
    local img = rtk.Image(w or 24, h or 24)
    img:pushdest()
    rtk.color.set({1, 0.2, 0.2, 1})
    gfx.setfont(1, 'Sans', w or 24)
    gfx.x, gfx.y = 5, 0
    gfx.drawstr('?')
    img:popdest()
    img.style = style or 'dark'
    return img
end

--- Class API
--
-- @section image.api

rtk.Image.register{
    --- The x offset within the underlying REAPER image as set by `viewport()` (default 0).
    -- @type number
    -- @meta read-only
    x = 0,
    --- The y offset within the underlying REAPER image as set by `viewport()` (default 0).
    -- @type number
    -- @meta read-only
    y = 0,
    --- The width in pixels of the image as set by `create()` or `load()` (default nil). Will
    -- be nil until one of those methods is called.
    -- @type number|nil
    -- @meta read-only
    w = nil,
    --- The height in pixels of the image as set by `create()` or `load()` (default nil). Will
    -- be nil until one of those methods is called.
    -- @type number|nil
    -- @meta read-only
    h = nil,

    --- The pixel density factor of the image, which controls how the image is drawn relative to
    -- `rtk.scale`.  Specifically, `rtk.scale.value` is divided by `density` when drawn,
    -- so a pixel density of `1.0` (default) is scaled directly by `rtk.scale.value`, while
    -- a density of `2.0` is drawn at half `rtk.scale.value`.
    --
    -- This can be used to define high-DPI or "retina" images.  Note that `w` and `h` are *not*
    -- adjusted according to density and will reflect the image's true/intrinsic size.  It is
    -- most useful when combined with `rtk.MultiImage`, which can represent many DPI variants of
    -- the same image.
    --
    -- @type number
    -- @meta read/write
    density = 1.0,

    --- The image path that was passed to `load()` or nil if `load()` wasn't called (default nil).
    -- @type string|nil
    -- @meta read-only
    path = nil,

    --- The current rotation of the image in degrees as passed to `rotate()`.
    -- @type number
    -- @meta read-only
    rotation = 0,

    --- The numeric id that represents the image buffer within REAPER.  This value is auto-generated
    -- and is unique to the image buffer, although multiple `rtk.Image` objects can share the same
    -- id if `viewport()` is used.
    -- @type number|nil
    -- @meta read-only
    id = nil,
}

--- Constructor to create a new image resource.
--
-- If the dimensions are specified, the image will be reserved from REAPER and
-- sized accordingly, where all pixels will default to transparent.  Otherwise,
-- the object will be inert until either `create()`, `load()`, or `resize()` are
-- explicitly called.
--
-- @tparam number|nil w if specified, @{create|creates} a new image with the given width
-- @tparam number|nil h if specified, @{create|creates} a new image with the given height
-- @tparam number|nil density the image's pixel `density` (defaults to `1.0` if nil)
-- @treturn rtk.Image the new instance
--
-- @code
--     -- Creates a new image and immediately loads from file
--     local img = rtk.Image():load('image.jpg')
--
--     -- Creates a new blank 24x24 image
--     local img2 = rtk.Image(24, 24)
--     -- This is equivalent
--     img = rtk.Image():create(24, 24)
--
-- @display rtk.Image
function rtk.Image:initialize(w, h, density)
    table.merge(self, self.class.attributes.defaults)
    if h then
        self:create(w, h, density)
    end
end

function rtk.Image:finalize()
    if self.id and not self._ref then
        -- We are the owner of the id (i.e. _ref is nil) so free the image and release
        -- the id.
        gfx.setimgdim(self.id, 0, 0)
        rtk.Image.static.ids:release(self.id)
    end
end

function rtk.Image:__tostring()
    local clsname = self.class.name:gsub('rtk.', '')
    return string.format(
        '<%s %s,%s %sx%s id=%s density=%s path=%s ref=%s>',
        clsname, self.x, self.y, self.w, self.h, self.id, self.density, self.path, self._ref
    )
end

--- Assigns a new image buffer with the specified dimensions.
--
-- After this method returneds, a new `id` will be assigned to the image.  The alpha
-- channel of image will be fully transparent by default.
--
-- @tparam number w the width of the image buffer in pixels
-- @tparam number h the height of the image buffer in pixels
-- @tparam number|nil density the image's pixel `density` (defaults to `1.0` if nil)
-- @treturn rtk.Image Returns self for method chaining. A new rtk.Image object is
--  not created here, rather the existing object is updated to use a new buffer.
function rtk.Image:create(w, h, density)
    if not self.id then
        -- Passing true will force a GC if we've run out of ids.  Any pending rtk.Image
        -- garbage will be collected and their ids freed up for reuse.  If this call
        -- fails, then we truly have run out of available buffers.
        self.id = rtk.Image.static.ids:next(true)
        if not self.id then
            error("unable to allocate image: ran out of available REAPER image buffers")
        end
    end
    if h ~= nil then
        -- Newly created images are automatically cleared to transparent so no need
        -- to have resize() do it.
        self:resize(w, h, false)
    end
    self.density = density or 1.0
    return self
end

--- Loads an image from disk.
--
-- After this method returns, a new `id` will be assigned to the image if necessary, and
-- `path`, `w`, and `h` will be updated to reflect the newly loaded image.  If the load
-- fails, those attributes will be set to nil.
--
-- If no file is found at the given path, it is treated as a path that's relative to the
-- current script path or any non-icon image paths previously registered with
-- `rtk.add_image_search_path()`, and they will be searched in that order. Unlike
-- `make_icon()`, the file extension isn't assumed to be .png -- so it's required -- and
-- the image will not be recolored if it's found in the icon path that doesn't correspond
-- to the active theme.
--
-- @example
--   local img = rtk.Image():load('/path/to/image.jpg')
--   if not img then
--      log.error('image failed to load')
--   end
--
-- @tparam string path the path to the image file to load
-- @treturn rtk.Image|nil returns self if the load was successful for method chaining,
--   otherwise if the load failed then nil is returned.
function rtk.Image:load(path)
    local found = path
    if not rtk.file.exists(path) then
        -- Check relative to the script.  rtk.script_path always has trailing path sep.
        found  = rtk.script_path .. path
        if not rtk.file.exists(found) then
            -- Hunt for the file in registered icon paths.
            found = _search_image_paths(path)
        end
    end
    self._path = found
    local id = self.id
    -- Only allocate a new candidate id if we don't already have one (or do have one
    -- but don't actually own it).
    if not id or self._ref then
        id = rtk.Image.static.ids:next()
    end
    local res = gfx.loadimg(id, found)
    if res ~= -1 then
        self.id = id
        self.path = found
        self.w, self.h = gfx.getimgdim(self.id)
        self.density = density or 1.0
        return self
    else
        rtk.Image.static.ids:release(id)
        self.w, self.h = nil, nil
        self.id = nil
        log.warning('rtk: rtk.Image:load("%s"): no such file found in any search paths', path)
        return nil
    end
end

--- Pushes this image's buffer onto the stack for off-screen drawing.
--
-- All subsequent drawing operations will be directed to the image's buffer.  The
-- image must have a valid `id`, which means `create()` or `load()` must first
-- have been called.
--
-- You must call `popdest()` after you're done drawing.  Failure to do so will result
-- in either a blank window or, more likely, a runtime error.
function rtk.Image:pushdest()
    assert(self.id, 'create() or load() must be called first')
    rtk.pushdest(self.id)
end

--- Pops this image's buffer off the stack for off-screen drawing.  It must be the
-- current drawing target or a runtime error will occur.
--
-- After this method returns, the previous image buffer from before `pushdest()`
-- was called will be restored as the current drawing target.
function rtk.Image:popdest()
    assert(gfx.dest == self.id, 'rtk.Image.popdest() called on image that is not the current drawing target')
    rtk.popdest(self.id)
end

--- Clones the current image contents into a new rtk.Image object with a new image buffer.
--
-- @treturn rtk.Image a new rtk.Image object with a copy of the current image contents.
function rtk.Image:clone()
    local newimg = rtk.Image(self.w, self.h)
    if self.id then
        newimg:blit{src=self, sx=self.x, sy=self.y}
    end
    newimg.density = self.density
    return newimg
end

--- Resizes the current image to new dimensions.
--
-- If necessary, `create()` is implicitly called.
--
-- @tparam number w the desired width in pixels of the image
-- @tparam number h the desired height in pixels of the image
-- @tparam boolean|nil clear if true or not provided then `clear()` is called after
--   resizing, otherwise if false then the image is not cleared.  After resizing any
--   existing image data will become corrupt (due to stride changes) so you almost certainly
--   want to clear, but if you plan to draw over the entire image after resizing you can
--   pass false here as a small optimization.
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:resize(w, h, clear)
    w = math.ceil(w)
    h = math.ceil(h)
    if self.w ~= w or self.h ~= h then
        if not self.id then
            return self:create(w, h)
        end
        self.w, self.h = w, h
        -- Seems necessary to size down to 0x0 first or else clear to transparency
        -- doesn't work.
        gfx.setimgdim(self.id, 0, 0)
        gfx.setimgdim(self.id, w, h)
    end
    if clear ~= false then
        self:clear()
    end
    return self
end


--- Returns a *new image* with the current image scaled to the given resolution.
--
-- @example
--   local scaled = rtk.Image.icon('32-delete'):scale(18)
--
-- @tparam number|nil w the target width in pixels, or nil to use the h parameter and
--   preserve aspect
-- @tparam number|nil h the target height in pixels, or nil to use the w parameter and
--   preserve aspect
-- @tparam modeconst|nil mode the drawing mode used to blit the scaled image (default when
--   nil is `DEFAULT`).
-- @tparam number|nil density the pixel density of the new scaled image, or nil to retain
--   the source image's `density`
function rtk.Image:scale(w, h, mode, density)
    assert(w or h, 'one or both of w or h parameters must be specified')
    if not self.id then
        -- Current image not loaded, so we "scale" an empty image just by
        -- returning a fresh image instance with the requested size.
        return rtk.Image(w, h)
    end
    local aspect = self.w / self.h
    w = w or (h / aspect)
    h = h or (w * aspect)
    local newimg = rtk.Image(w, h)
    newimg:blit{src=self, sx=self.x, sy=self.y, sw=self.w, sh=self.h, dw=newimg.w, dh=newimg.h, mode=mode}
    newimg.density = density or self.density
    return newimg
end



--- Clears the image either to the given color or to fully transparent.
--
-- If a color is provided, the image will be filled with that color, otherwise
-- the alpha channel is fully set to 0.
--
-- @tparam colortype|nil color the color to clear the image to, or nil to clear the
--   image to transparency (where all pixels have an alpha of 0)
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:clear(color)
    self:pushdest()
    if not color then
        -- Ensures alpha channel of the rectangle we draw next is fully transparent.
        gfx.set(0, 0, 0, 0, rtk.Image.DEFAULT, self.id, 0)
        -- This sometimes appears to be necessary due to unknown internal REAPER voodoo.
        gfx.setimgdim(self.id, 0, 0)
        gfx.setimgdim(self.id, self.w, self.h)
    else
        rtk.color.set(color)
        gfx.mode = rtk.Image.DEFAULT
    end
    gfx.rect(self.x, self.y, self.w, self.h, 1)
    -- Restore gfx.a2
    gfx.set(0, 0, 0, 1, rtk.Image.DEFAULT, self.id, 1)
    self:popdest()
    return self
end

--- Creates a new `rtk.Image` that is a viewport into the current image.
--
-- This allows you take a slice of the current image to create a smaller view
-- within it, without needing to create a new image buffer and copy the image
-- over.
--
-- A typical use case is having a single image that contains multiple icons (i.e.
-- a sprite) and you want to use a specific region of the sprite, for example
-- as a @{rtk.Button.icon|button icon}.
--
-- The returned new `rtk.Image` will have the same `id` as the current image
-- because they share the same underlying image buffer.
--
-- @tparam number|nil x the x offset within the source image (nil is 0)
-- @tparam number|nil y the y offset within the source image (nil is 0)
-- @tparam number|nil w the width of new image (nil extends to the right edge of the source)
-- @tparam number|nil h the height of the new image (nil extends to the bottom edge of the source)
-- @tparam number|nil density the pixel density the new image (defaults to current image's `density` if nil)
-- @treturn rtk.Widget a new image object that represents the slice within the source image
function rtk.Image:viewport(x, y, w, h, density)
    local new = rtk.Image()
    new.id = self.id
    new.density = density or self.density
    new.path = self.path
    new.x = x or 0
    new.y = y or 0
    new.w = w or (self.w - new.x)
    new.h = h or (self.h - new.y)
    -- Hold a reference to the source to ensure the source image isn't freed in finalize()
    new._ref = self
    return new
end

--- Draws the full image to the current drawing target.
--
-- This is a convenience method for `blit()` that offers positional parameters for the
-- most common drawing operations.
--
-- @tparam number|nil dx the x offset within the current drawing target (defaults to 0)
-- @tparam number|nil dy the y offset within the current drawing target (defaults to 0)
-- @tparam number|nil a the opacity level to blend the image onto the current target from 0.0 to 1.0
--   (defaults to 1.0)
-- @tparam number|nil scale the scale multiplier for the target image (defaults to 1.0)
-- @tparam number|nil clipw the width beyond which the image will be clipped (default to no clipping)
-- @tparam number|nil cliph the height beyond which the image will be clipped (defaults to no clipping)
-- @tparam modeconst|nil mode a bitmap of @{modeconst|drawing mode constants} (defaults to `DEFAULT`).
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:draw(dx, dy, a, scale, clipw, cliph, mode)
    return self:blit{
        dx=dx, dy=dy,
        alpha=a,
        clipw=clipw,
        cliph=cliph,
        mode=mode,
        scale=scale
    }
end


--- Draws a region of the image onto a drawing target, or another image onto this image.
--
-- Whereas `draw()` satisfies the most common use cases, `blit()` provides a more
-- comprehensive interface, abstracting REAPER's native `gfx.blit()` function with
-- additional features and conveniences.
--
-- This method takes a table of attributes where every possible field has some
-- sane default.  In fact, calling this method without any arguments will default
-- to drawing the image to the top left of the current drawing target.
--
-- The `attrs` table can contain the following fields, all of which are optional:
--   * `src` (`rtk.Image` or numeric image id): the source image that is to be drawn.
--      If not specified, the `rtk.Image` that blit() is called upon is the image source,
--      but if `src` is another image, then the current image is used as the drawing target.
--      In other words, if `src `is defined, it draws onto us, otherwise we draw
--      onto the current drawing target.
--   * `sx`: x offset within the source image (defaults to `x`)
--   * `sy`: y offset within the source image (defaults to `y`)
--   * `sw`: the width of the source image to draw (defaults to `w`)
--   * `sh`: the height of the source image to draw (defaults to `h`)
--   * `dx`: x offset within the drawing target where `sx` begins (defaults to 0)
--   * `dy`: y offset within the drawing target where `sy` begins (defaults to 0)
--   * `dw`: the target width for the destination. If this different than `sw` then the
--     image width is scaled to fit `dw`. (Defaults to `sw * scale`.)
--   * `dh`: the target height for the destination. If this different than `sh` then the
--     image height is scaled to fit `dh`. (Defaults to `sh * scale`.)
--   * `scale`: the scale of the destination image, which is only used if
--     `dw` or `dh` are not defined (defaults to 1.0)
--   * `clipw`: clips the drawn image to this width (defaults to no clipping of width)
--   * `cliph`: clips the drawn image to this height (defaults to no clipping of height)
--   * `mode`: a bitmap of @{modeconst|mode constants} (defaults to `DEFAULT`)
--
-- @example
--   -- Draws the image at 50,100 in the current drawing target at 50% opacity
--   -- and scaled 150%.
--   local img = rtk.Image():load('portrait.jpg')
--   img:blit{dx=50, dy=100, alpha=0.5, scale=1.5}
--
--   -- Draws whatever is on the current drawing target to the image.  This
--   -- trick is used by widgets like rtk.Viewport to support translucent
--   -- overlays.
--   --
--   -- In this example, we're calling from within a hypothetical widget's
--   -- _draw() function where the calculated geometry attributes are available.
--   local img = rtk.Image:create(self.calc.w, self.calc.h)
--   img:blit{src=gfx.dest, sx=self.calc.x, sy=self.calc.y, mode=rtk.Image.FAST_BLIT}
--
-- @tparam table|nil attrs a table of fields as described above
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:blit(attrs)
    attrs = attrs or {}
    gfx.a = attrs.alpha or 1.0
    local mode = attrs.mode or rtk.Image.DEFAULT
    if mode & rtk.Image.SUBTRACTIVE_BLEND ~= 0 then
        -- With gfx.blit(), subtractive blend is indicated as setting the additive
        -- blend flag with a negative alpha.
        mode = (mode & ~rtk.Image.SUBTRACTIVE_BLEND) | rtk.Image.ADDITIVE_BLEND
        gfx.a = -gfx.a
    end
    gfx.mode = mode

    local src = attrs.src
    if src and type(src) == 'table' then
        assert(rtk.isa(src, rtk.Image), 'src must be an rtk.Image or numeric image id')
        src = src.id
    end
    if src then
        self:pushdest()
    end
    local scale = (attrs.scale or 1.0) / self.density
    local sx = attrs.sx or self.x
    local sy = attrs.sy or self.y
    local sw = attrs.sw or self.w
    local sh = attrs.sh or self.h
    local dx = attrs.dx or 0
    local dy = attrs.dy or 0
    local dw = attrs.dw or (sw * scale)
    local dh = attrs.dh or (sh * scale)
    if attrs.clipw and dw > attrs.clipw then
        sw = sw - (dw - attrs.clipw) / (dw/sw)
        dw = attrs.clipw
    end
    if attrs.cliph and dh > attrs.cliph then
        sh = sh - (dh - attrs.cliph)/(dh/sh)
        dh = attrs.cliph
    end
    if self.rotation == 0 then
        gfx.blit(src or self.id, 1.0, 0,
            sx, sy,
            sw, sh,
            dx or 0, dy or 0,
            dw, dh,
            0, 0)
    else
        gfx.blit(
            src or self.id, 1.0, self.rotation,
            -- source geometry
            sx - (self._soffx or 0), sy - (self._soffy or 0),
            self._dw, self._dh,
            -- dest geometry
            dx - (self._doffx or 0), dy - (self._doffy or 0),
            self._dw, self._dh,
            -- rotation offsets
            0, 0
        )
    end
    gfx.mode = 0
    if src then
        self:popdest()
    end
    return self
end


--- Changes all pixels in the image to the given color while respecting the alpha channel.
--
-- The image is mutated in situ.  If you don't want that you can `clone()` it first.  This
-- uses `filter()` under the hood, by first multiplying all pixels (except alpha) with 0,
-- and then adding the supplied color.
--
-- @tparam colortype color the color to change all pixels to
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:recolor(color)
    local r, g, b, _ = rtk.color.rgba(color)
    return self:filter(0, 0, 0, 1.0, r, g, b, 0)
end


--- Applies an effect to the image by multiplying or adding values to individual
--  channels.
--
-- The image is mutated in situ.  If you don't want that you can `clone()` it first.
--
-- @tparam number mr the amount to multiply all pixels in the *red* channel
-- @tparam number mg the amount to multiply all pixels in the *green* channel
-- @tparam number mb the amount to multiply all pixels in the *blue* channel
-- @tparam number ma the amount to multiply all pixels in the *alpha* channel
-- @tparam number ar the value to add to all pixels in the *red* channel
-- @tparam number ag the value to add to all pixels in the *green* channel
-- @tparam number ab the value to add to all pixels in the *blue* channel
-- @tparam number aa the value to add to all pixels in the *alpha* channel
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:filter(mr, mg, mb, ma, ar, ag, ab, aa)
    self:pushdest()
    gfx.muladdrect(self.x, self.y, self.w, self.h, mr, mg, mb, ma, ar, ag, ab, aa)
    self:popdest()
    return self
end

--- Draws a rectangle on the image in the given color.
--
-- @tparam colortype color the color of the rectangle
-- @tparam number x the x offset within the image for the left edge of the rectangle
-- @tparam number y the y offset within the image for the top edge of the rectangle
-- @tparam number w the width of the rectangle
-- @tparam number h the height of the rectangle
-- @tparam boolean|nil fill whether the rectangle should be filled (defaults to false)
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:rect(color, x, y, w, h, fill)
    self:pushdest()
    rtk.color.set(color)
    gfx.rect(x, y, w, h, fill)
    self:popdest()
    return self
end

--- Blurs a region of the image.
--
-- REAPER's blur capability is a bit crap, being both slow and ugly, but this can be
-- useful in certain circumstances.  Just don't expect the same quality you get
-- from a Gaussian blur.
--
-- @tparam number|nil strength the number of passes, where large values increase the
--   level of blur (default 20)
-- @tparam number|nil x the x offset within the image to start blurring (default 0)
-- @tparam number|nil y the y offset within the image to start blurring (default 0)
-- @tparam number|nil w the width of the blur region (default full image width)
-- @tparam number|nil h the height of the blur region (default full image height)
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:blur(strength, x, y, w, h)
    if not self.w then
        -- No image to blur, no-op
    end
    self:pushdest()
    gfx.mode = 6
    x = x or 0
    y = y or 0
    for i = 1, strength or 20 do
        gfx.x = x
        gfx.y = y
        gfx.blurto(x + (w or self.w), y + (h or self.h))
    end
    self:popdest()
    return self
end

--- Flips the image vertically in place.
--
-- The image is mutated in situ.  If you don't want that you can `clone()` it first.
--
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:flip_vertical()
    self:pushdest()
    gfx.mode = 6
    gfx.a = 1
    gfx.transformblit(self.id, self.x, self.y, self.w, self.h, 2, 2, {
        -- top left
        self.x, self.y + self.h,
        -- top right
        self.x + self.w, self.y + self.h,
        -- bottom left
        self.x, self.y,
        -- bottom right
        self.x + self.w, self.y
    })
    rtk.popdest()
    return self
end

-- TODO: Finish implementing.

local function _xlate(x, y, theta)
    return x*math.cos(theta) - y*math.sin(theta),
           x*math.sin(theta) + y*math.cos(theta)
end

--- Rotates the image.
--
-- The rotation is non-destructive: it only applies to how the image is @{blit|blitted}.
--
-- @warning Not fully implemented
--   This is a work-in-progress and doesn't work properly in all cases.  For example,
--   it doesn't work with scaling or cloning.  The usefulness is very limited at the
--   moment.  Expect weird behavior.
--
-- @tparam number degrees the rotation in degrees
-- @treturn rtk.Image returns self for method chaining
function rtk.Image:rotate(degrees)
    self.rotation = math.rad(degrees)
    -- Top left
    local x1, y1 = 0, 0
    local xt1, yt1 = _xlate(x1, y1, self.rotation)
    -- Top right
    local x2, y2 = 0 + self.w, 0
    local xt2, yt2 = _xlate(x2, y2, self.rotation)
    -- Bottom left
    local x3, y3 = 0, self.h
    local xt3, yt3 = _xlate(x3, y3, self.rotation)
    -- Bottom right
    local x4, y4 = 0 + self.w, self.h
    local xt4, yt4 = _xlate(x4, y4, self.rotation)

    -- Determine full bounding box of rotated image
    local xmin = math.min(xt1, xt2, xt3, xt4)
    local xmax = math.max(xt1, xt2, xt3, xt4)
    local ymin = math.min(yt1, yt2, yt3, yt4)
    local ymax = math.max(yt1, yt2, yt3, yt4)

    local dw = xmax - xmin
    local dh = ymax - ymin
    local dmax = math.max(dw, dh)
    self._dw = dmax
    self._dh = dmax
    self._soffx = (dmax - self.w)/2
    self._soffy = (dmax - self.h)/2
    self._doffx = math.max(0, (dh-dw)/2)
    self._doffy = math.max(0, (dw-dh)/2)
    return self
end