-- Copyright 2017-2023 Jason Tackaberry
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

--- Encapsulates multiple underlying `rtk.Image` objects, representing different pixel density
-- variants of the same image.
--
-- Being a subclass of `rtk.Image`, `rtk.MultiImage` can be used anywhere an `rtk.Image` is
-- expected. When provided to widget attributes, such as `rtk.Button.icon`, the best variant
-- is selected based on the current `rtk.scale.value`.
--
-- The entire `rtk.Image` API works with `rtk.MultiImage`, so it is not re-documented
-- here.
--
-- In cases where `rtk.Image` methods return a new image, those same methods here
-- will return `rtk.MultiImage` instead.  For example, `viewport()` will return a new
-- `rtk.MultiImage` with each encapsulated image being a viewport into the original
-- variants.
--
-- @note Geometry is implicitly adjusted
--  Methods that receive coordinates and sizes will always be relative to a pixel density
--  of `1.0`.  All geometry values passed to `rtk.MultiImage` methods are automatically
--  adjusted according to the density of the underlying variants.
--
--  For example, suppose a multi-image has two images with density 1.0 and 2.0:
--  @code
--    local img = rtk.MultiImage{
--        rtk.Image:load('icon@1x.png', 1),
--        rtk.Image:load('icon@2x.png', 2),
--    }
--    local vp = img:viewport(16, 16, 32, 32)
--
--  The above `vp` viewport will contain a viewport at position 16,16 and size 32x32
--  within the 1.0 density variant, and position 32,32 and size 64x64 within the
--  2.0 density variant. In other words, the supplied geometry is multiplied by the
--  `density` of the image variant being acted upon.
--
-- @class rtk.MultiImage
-- @inherits rtk.Image
-- @see rtk.Image rtk.ImagePack
rtk.MultiImage = rtk.class('rtk.MultiImage', rtk.Image)

--- Constructor to create a new MultiImage.
--
-- For convenience, a variable number of existing `rtk.Image` objects may be passed
-- here, and they will all be included as variants for the multi image.  Alternatively
-- the `add()` method may be explicitly called.
--
-- @display rtk.MultiImage
function rtk.MultiImage:initialize(...)
    rtk.Image.initialize(self)
    self._variants = {}
    local images = {...}
    for _, img in ipairs(images) do
        self:add(img)
    end
end

function rtk.MultiImage:finalize()
    -- Override rtk.Image:finalize() to prevent releasing of whichever variant we are
    -- currently set to.  MultiImage() doesn't own the image resource, it only wraps
    -- existing rtk.Image objects, so the underlying image buffers will be released
    -- when the wrapped rtk.Image objects are destroyed.
end

--- Adds (or loads) an image variant to the multi image.
--
-- @tparam rtk.Image|string path_or_image if a string, the image is loaded via `rtk.Image:load()`
--  and assigned the supplied density; if an `rtk.Image`, the image is added directly as a
--  variant (and in this case the density argument is ignored)
-- @tparam number|nil density the pixel `density` of the image when `path_or_image` is a filename
--  string; is ignored (and therefore may be nil) when `path_or_image` is an `rtk.Image`
-- @treturn rtk.Image|nil returns the `rtk.Image` if load was successful, or nil if the load
--  failed.
function rtk.MultiImage:add(path_or_image, density)
    local img
    if rtk.isa(path_or_image, rtk.Image) then
        assert(not rtk.isa(path_or_image, rtk.MultiImage), 'cannot add an rtk.MultiImage to an rtk.MultiImage')
        img = path_or_image
    else
        assert(density, 'density must be supplied when path is passed to add()')
        img = rtk.Image:load(path_or_image, density)
    end
    assert(not self._variants[img.density], 'replacing existing density not supported')
    self._variants[img.density] = img
    -- Set the current context if it's the first image added, or if we're replacing
    -- the variant we're currently set to.
    if not self.id or self.density == img.density then
        self:_set(img)
    end
    if not self._max or img.density > self._max.density then
        self._max = img
    end
    return img
end

function rtk.MultiImage:load(path, density)
    -- rtk.Image:load() returns self, so we preserve that behavior here, even though
    -- we otherwise proxy add().
    if self:add(path, density) then
        return self
    end
end

function rtk.MultiImage:_set(img)
    self.current = img
    self.id = img.id
    self.x = img.x
    self.y = img.y
    self.w = img.w
    self.h = img.h
    self.density = img.density
    self.path = img.path
    self.rotation = img.rotation
end

--- Updates the current context of the multi image based on the given scale.
-- After this method is called, all the @{image.api|image attributes} are
-- updated to reflect the chosen variant.
--
-- The variant that's chosen will be that whose `density` most closely matches
-- the scale argument.  Larger density variants will be favored if an exact
-- match can't be found.
--
-- @note
--  Widgets that receive images as attributes (for example `rtk.Entry.icon`) will
--  automatically call this method when `rtk.scale.value` changes.  However if you
--  are using an `rtk.MultiImage` outside the context of a widget attribute, you will
--  need to explicitly call this method when the UI scale changes.
--
-- @tparam number|nil scale the variant whose density most closely matches this scale
--   will be selected; if nil, the current value of `rtk.scale.`value is used.`
-- @treturn rtk.MultiImage returns self for method chaining
function rtk.MultiImage:refresh_scale(scale)
    local best = self._max
    scale = scale or rtk.scale.value
    for density, img in pairs(self._variants) do
        if density == scale then
            best = img
            break
        elseif density > scale and density < best.density then
            best = img
        end
    end
    self:_set(best)
    return self
end

function rtk.MultiImage:clone()
    local new = rtk.MultiImage()
    for density, img in pairs(self._variants) do
        new:add(img:clone())
    end
    new:_set(new._variants[self.density])
    return new
end

function rtk.MultiImage:resize(w, h, clear)
    for density, img in pairs(self._variants) do
        img:resize(w*density, h*density, clear)
    end
    -- Reflect new dimensions of subimage
    self:_set(self.current)
    return self
end

function rtk.MultiImage:scale(w, h, mode)
    local new = rtk.MultiImage()
    for density, img in pairs(self._variants) do
        new:add(img:scale(w and w*density, h and h*density, mode))
    end
    new:_set(new._variants[self.density])
    return new
end

function rtk.MultiImage:clear(color)
    for density, img in pairs(self._variants) do
        img:clear(color)
    end
end

function rtk.MultiImage:viewport(x, y, w, h)
    local new = rtk.MultiImage()
    for density, img in pairs(self._variants) do
        new:add(img:viewport(x*density, y*density, w*density, h*density))
    end
    new:_set(new._variants[self.density])
    return new
end

function rtk.MultiImage:filter(mr, mg, mb, ma, ar, ag, ab, aa)
    for density, img in pairs(self._variants) do
        img:filter(mr, mg, mb, ma, ar, ag, ab, aa)
    end
    return self
end

function rtk.MultiImage:rect(color, x, y, w, h, fill)
    for density, img in pairs(self._variants) do
        img:rect(color, x*density, y*density, w*density, h*density, fill)
    end
    return self
end

function rtk.MultiImage:blur(strength, x, y, w, h)
    for density, img in pairs(self._variants) do
        img:blur(strength, x*density, y*density, w*density, h*density)
    end
    return self
end

function rtk.MultiImage:flip_vertical()
    for density, img in pairs(self._variants) do
        img:flip_vertical()
    end
    return self
end

function rtk.MultiImage:rotate(degrees)
    for density, img in pairs(self._variants) do
        img:rotate(degrees)
    end
    return self
end
