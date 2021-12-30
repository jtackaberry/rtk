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

--- Manages a single image composed of a collection of smaller images, also known
-- as an image sprite.
--
-- Image packs allow distributing a smaller number of images files with your application.
-- They are comprised of *rows*, defined by successive calls to `rtk.ImagePack:add_row()`,
-- where each row contains a collection of named images with the same resolution and
-- @{rtk.Image.density|density}, and optionally an icon *style* that describes whether the
-- image, if treated as an icon, is a `dark` or `light` icon style.
--
-- Multiple images can exist within the image pack using the same name, as long as they
-- have a different `density` or `style` attribute.
--
-- Once constructed, sub-images can be fetched from the ImagePack by calling
-- `rtk.ImagePack:get()` with the name of the image (and, optionally, the style).
-- An `rtk.MultiImage` is returned encapsulating all the densities for that image
-- name, which can be use anywhere an `rtk.Image` is used within rtk (because
-- `rtk.MultiImage` is just a subclass of `rtk.Image`).
--
-- This provides a convenient means of creating scalable UIs with adaptive images:
-- as the UI scales up (such as through system DPI changes, or direct setting of
-- `rtk.scale.user`), the images within the interface adapt to pick the best resolution
-- available.
--
-- @note Conserves REAPER image ids
--   The `rtk.MultiImage` objects returned by `get()` contains @{rtk.Image.viewport|viewports}
--   relative to the single underlying image.  Image viewports refer to a subregion within the
--   packed image, so only a single @{rtk.Image.id|REAPER image id} is used per ImagePack.
--
-- After all rows have been @{rtk.ImagePack.add_row|added}, the ImagePack be
-- @{rtk.ImagePack.register|registered}, which allows accessing the named image
-- via `rtk.Image.icon()`.  Consequently, any widget attribute that implicitly calls
-- `rtk.Image.icon()` when it receives a string can access images from the ImagePack.
-- For example, `rtk.Button.icon`, `rtk.Entry.icon`, `rtk.ImageBox.image`, etc.
--
--
-- ## Example
--
-- Suppose we want to create an image pack with "medium" and "large" sized icons, with
-- both those sizes at 1x, 1.5x and 2x densities for higher DPI display.  Here, density
-- is different than size: perhaps the medium sized icons would be used for buttons,
-- while the large icons would be used for section headers, but you'd still want
-- high-DPI variants for these different use cases.
--
-- With 2 icon sizes, and 3 different pixel densities per icon size, we will need a total
-- of 2*3=6 rows in our packed image.  For example, this is `icons.png`:
--
-- ![](../img/imagepack.png)
--
-- Here the medium size has 3 icons, the large size has 2 icons.  So each density needs
-- 2 distinct rows.
--
-- We can describe the above packed image like so:
--
-- @code
--   -- Say we have an 'images/' directory relative to the current script.  We can
--   -- add that as an image search path.
--   rtk.add_image_search_path('images/')
--   -- Define a table with our icon names which we'll use later.  We create a table
--   -- for this as we'll be reusing these names in multiple rows, so it avoids
--   -- duplicating them. The naming convention is entirely your choice.
--   local icons = {
--       medium = {
--           'medium-add_circle_outline',
--           'medium-delete',
--           'medium-link',
--       },
--       large = {
--           'large-info_outline',
--           'large-plus',
--       },
--   }
--
--   local pack = rtk.ImagePack{
--       -- Find icons.png in all the image search paths
--       src='icons.png',
--       -- Register these names for use with rtk.Image.icon()
--       register=true,
--       -- Now define the 6 different rows in the packed image.  We use the 'dark'
--       -- icon style here as the icons are black.  They will automatically be
--       -- recolored to white if we get() a light style.
--       --
--       -- 1x density
--       {w=18, h=18, names=icons.medium, density=1, style='dark'},
--       {w=24, h=24, names=icons.large, density=1, style='dark'},
--       -- 1.5x density
--       {w=28, h=28, names=icons.medium, density=1.5, style='dark'},
--       {w=36, h=36, names=icons.large, density=1.5, style='dark'},
--       -- 2x density
--       {w=36, h=36, names=icons.medium, density=2, style='dark'},
--       {w=48, h=48, names=icons.large, density=2, style='dark'},
--   }
--
-- Now, because the image names have been registered as icons, we can reference the icon
-- names in widget attributes.  Two examples below -- these icons will automatically adapt
-- to the current UI scale.
--
-- @code
--       local button = rtk.Button{icon='medium-delete', circular=true, color='crimson'}
--       local infobox = rtk.HBox{
--           valign='center', spacing=5, margin=10,
--           rtk.ImageBox{'large-info_outline'},
--           rtk.Text{'rtk makes creating scalable interfaces easy! Ish. :)'},
--       }
--
-- @note Creating ImagePack images
--  Although you can use any image editor (such GIMP, Affinity Photo, Photoshop, etc) to create
--  the packed image, [ImageMagick](https://imagemagick.org/) provides a convenient command line
--  interface to create a packed image from individual files.  If you're comfortable on the command
--  line, you might find this approach easier than using a GUI editor.
--
-- @class rtk.ImagePack
-- @see rtk.MultiImage

rtk.ImagePack = rtk.class('rtk.ImagePack')


--- Class API
--
-- @section api

--- Constructor to create a new ImagePack.
--
-- For convenience, a table can be passed to the initializer to automatically
-- add an arbitrary number of rows via `add_row()`, `load` an image using the *src* field,
-- and optionally `register` the image pack for use with `rtk.Image.icon()` using the
-- *register* field.
--
-- @code
--    -- In this example, the file icons.png has two rows of icons: the first row
--    -- has two 18x18 icons representing a pixel density of 1x, and the second row
--    -- has two 36x36 icons for 2x density.  Both are high luminance icons when
--    -- light icon styles are needed.
--    rtk.ImagePack{
--        src='icons.png',
--        register=true,
--        {w=18, h=18, names={'medium-edit', 'medium-save'}, density=1, style='light'},
--        {w=36, h=36, names={'medium-edit', 'medium-save'}, density=2, style='light'},
--    }
--    -- Because register is true, these image names can now be referenced as
--    -- icon names, so this works:
--    local button = rtk.Button{'Save File', icon='medium-save'}
--
-- @display rtk.ImagePack
function rtk.ImagePack:initialize(attrs)
    -- The rtk.Image() from load()
    self._img = nil
    -- Recolored versions of _img for icon styles, keyed on style name
    self._img_recolored = {}
    -- style -> {name -> {density -> {x, y, w, h}}}
    self._images = {}
    -- 'style.name' -> rtk.MultiImage
    self._cache = {}
    -- Running total of height for each add_row()
    self._height = 0
    if attrs then
        for _, row in ipairs(attrs) do
            self:add_row(row)
        end
        if attrs.src then
            self:load(attrs.src)
        end
        if attrs.register then
            self:register()
        end
    end
end

--- Defines a new row in an image sourced with `load()`.
--
-- This method receives a table that describes the row.  The following fields
-- are supported in the table.
-- | Field | Type | Required | Description |
-- |-|:-:|:-:|-|
-- | **`w`** | number | ✔ | The width of each subimage in this row |
-- | **`h`** | number | ✔ | The height of each subimage in this row |
-- | **`names`** | table of strings | ✔ | A table of strings that define the names of each image in the row. The number of elements in this table implicitly defines the number of images in the row. |
-- | `density` | number | | The @{rtk.Image.density|pixel density} of each image in the row. Subimages with the same name and style but different densities will all be included in the `rtk.MultiImage` returned by `get()`. If not defined, a density of `1.0` is assumed. |
-- | `style` | string | | An optional style to associate with each subimage in the row, and can be used to differentiate images with the same name.  The style value would then correspond to that passed to `get()`.  Technically the style is arbitrary, however if registering the image pack as icons using `register()`, the style `light` or `dark` must be used for proper compatibility with `rtk.Image.icon()`. |
--
-- Each successive call to `add_row()` defines a new row in the packed image.  The order
-- is important: the rows must be added in the order they appear in the packed image. Rows
-- may be added before or after `load()` is called.
--
-- @example
--   local pack = rtk.ImagePack()
--   pack:add_row{w=64, h=64, names={'alice', 'bob', 'eve', 'mallory'}}
--   pack:load('cryptoactors.png')
--
-- @tparam table attrs the definition of the row
function rtk.ImagePack:add_row(attrs)
    assert(type(attrs) == 'table', 'ImagePack row attributes must be a table')
    assert(type(attrs.w) == 'number', 'ImagePack row missing "w" attribute or is not number')
    assert(type(attrs.h) == 'number', 'ImagePack row missing "h" attribute or is not number')
    assert(type(attrs.names) == 'table', 'ImagePack row missing "names" attribute or is not table')

    local x = 0
    for _, name in ipairs(attrs.names) do
        -- Lookup names table for this row's style
        local names = self._images[attrs.style or rtk.Attribute.NIL]
        if not names then
            names = {}
            self._images[attrs.style] = names
        end
        -- Lookup density table for this image's name
        local densities = names[name]
        if not densities then
            densities = {
                -- rtk.MultiImage that's lazy-created in get()
                img=nil,
            }
            names[name] = densities
        end
        local density = attrs.density or 1
        assert(
            not densities[density],
            string.format(
                'duplicate image name "%s" for style "%s" and density "%s"',
                name, attrs.style, density
            )
        )
        densities[density] = {
            x=x,
            y=self._height,
            w=attrs.w,
            h=attrs.h,
        }
        x = x + attrs.w
    end
    self._height = self._height + attrs.h
end

--- Loads an image and assigns it as the underlying image for the image pack.
--
-- @tparam rtk.Image|string img_or_path if a string, is considered a filename and loaded via
--  `rtk.Image:load()` (which supports image search paths added with
--   `rtk.add_image_search_path()`). If an `rtk.Image`, then this image is directly used.
-- @treturn rtk.Image|nil if successfully loaded, the underlying `rtk.Image` is returned, or
--  nil is returned if the image failed to be loaded.
function rtk.ImagePack:load(img_or_path)
    if rtk.isa(img_or_path, rtk.Image) then
        self._img = img_or_path
    else
        self._img = rtk.Image():load(img_or_path)
    end
    return self._img
end

function rtk.ImagePack:_get_densities(name, style)
    local names = self._images[style or rtk.Attribute.NIL]
    if not names then
        return
    end
    return names[name]
end

--- Returns an `rtk.MultiImage` containing all pixel densities for the given subimage name
-- and style.
--
-- If one or more subimages are found with the given name and style, they're consolidated
-- and returned in the `rtk.MultiImage`. If not, then other styles are searched. First, if
-- the given style is nil, then the icon style appropriate for the @{rtk.theme|current theme}
-- is searched.  Thereafter the behavior is the same as `rtk.Image.icon()`, recoloring the
-- image if needed to match the requested style.
--
-- Before `get()` may be called, `load()` and at least one invocation of `add_row()` must
-- first have occurred.
--
-- @tparam string name the name of the subimage as previously described by `add_row()`.
-- @tparam string|nil style the style of the subimage as previously described by `add_row().` If
--   no image can be found with the requested style, other styles are searched and are recolored
--   if necerssary.
-- @treturn rtk.MultiImage a multi-density image encapsulating all variants of the requested
--  subimage name and style.
function rtk.ImagePack:get(name, style)
    -- First check cache
    local cachekey = string.format('%s.%s', style, name)
    local multi = self._cache[cachekey]
    if multi then
        return multi
    end

    -- Not in cache, so we need to generate the rtk.MultiImage
    local imgpack = self._img
    assert(imgpack, 'rtk.ImagePack:load() has not yet been called with a valid image')
    assert(self._height > 0, 'rtk.ImagePack:add_row() has not yet been called')

    local densities = self:_get_densities(name, style)
    if not densities and not style then
        -- No icon style was given, but no image was found registered under the nil
        -- style.  Let's go ahead and try with the current theme's icon style.
        style = rtk.theme.iconstyle
        densities = self:_get_densities(name, style)
    end
    if not densities and style then
        -- An icon style was given, try the other style
        local otherstyle = style == 'light' and 'dark' or 'light'
        densities = self:_get_densities(name, otherstyle)
        if not densities then
            -- Nothing registered under the other style.  Try the nil style as a last resort.
            -- We'll be recoloring it anyway.
            densities = self:_get_densities(name, nil)
        end
        if densities then
            imgpack = self._img_recolored[style]
            if not imgpack then
                -- Image hasn't been recolored to the requested style yet. Do that now and
                -- store it for later.
                imgpack = self._img:clone():recolor(style == 'light' and '#ffffff' or '#000000')
                self._img_recolored[style] = imgpack
            end
        end
    end
    if not densities then
        return
    end
    multi = rtk.MultiImage()
    for density, info in pairs(densities) do
        multi:add(imgpack:viewport(info.x, info.y, info.w, info.h, density))
    end
    multi.style = style
    self._cache[cachekey] = multi
    return multi
end

--- Registers all subimage names defined via `add_row()` as icon names for later use
-- with `rtk.Image.icon()`.
--
-- Once registered, widget attributes that implicitly call `rtk.Image.icon()` can access
-- the image pack's subimages by name. For example, `rtk.Button.icon`, `rtk.Entry.icon`,
-- `rtk.ImageBox.image`, etc.
function rtk.ImagePack:register()
    for style, names in pairs(self._images) do
        for name, densities in pairs(names) do
            rtk.Image._icons[name] = self
        end
    end
end