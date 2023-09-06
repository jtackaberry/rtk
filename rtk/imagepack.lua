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

--- Manages a single image composed of a collection of smaller images, also known
-- as an image sprite.
--
-- Image packs allow distributing a smaller number of image files with your application.
-- An image pack contains one or more image files added via `add()`, where each file is
-- comprised of *strips*.  A strip is a horizontal band across the width of the given
-- packed image that consists of one or more *subimages* each with the same resolution,
-- @{rtk.Image.density|density}, and optionally, a @{rtk.ImagePack.default_size|size} and
-- icon *style* within the strip.
--
-- Multiple subimages can exist within the image pack using the same name, as long as they
-- have a different density, size, and/or style.
--
-- Once constructed, subimages can be fetched from the ImagePack by calling
-- `rtk.ImagePack:get()` with the name of the subimage (and, optionally, the style).
-- Names may also be qualified with a size suffix (e.g. `myimage:large`) to select among
-- different size variants. An `rtk.MultiImage` is returned encapsulating all the
-- densities for that image name, which can be use anywhere an `rtk.Image` is used within
-- rtk (because `rtk.MultiImage` is just a subclass of `rtk.Image`).
--
-- @note Useful for scalable interfaces
--   This provides a convenient means of creating scalable UIs with adaptive images: as the
--   UI scales up (such as through system DPI changes, or direct setting of
--   `rtk.scale.user`), the images within the interface adapt to pick the best resolution
--   available.
--
-- Once all image files have been @{rtk.ImagePack.add|added} and their respective strips defined,
-- `register_as_icons()` may then be called, which allows accessing the named subimages
-- via `rtk.Image.icon()`.  Consequently, any widget attribute that implicitly calls
-- `rtk.Image.icon()` when it receives a string can access images from the ImagePack.
-- For example, `rtk.Button.icon`, `rtk.Entry.icon`, `rtk.ImageBox.image`, etc.
--
-- Subimage recoloring is also handled: for example, if you register a strip with the
-- `light` style and subsequently ask `get()` for the `dark` style, it will be
-- automatically recolored to black.  (Unless of course you *also* include a strip with a
-- `dark` variant, in which case that would be returned directly.)  This behavior likewise
-- works with `rtk.Image.icon()` after `register_as_icons()` is called (because
-- `rtk.Image.icon()` simply calls `rtk.ImagePack:get()` under the hood.)
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
-- of 2*3=6 strips in our packed image, because each strip must have a distinct size, density,
-- and style.  For example, this is `icons.png`:
--
-- ![](../img/imagepack.png)
--
-- Here the medium size has 3 icons, the large size has 2 icons.  So each density needs
-- 2 distinct strips.
--
-- We can describe the above packed image like so:
--
-- @code
--   -- Say we have an 'images/' directory relative to the current script.  We can
--   -- add that as an image search path.
--   rtk.add_image_search_path('images/')
--   -- Define a table with our icon names which we'll use later.  We create a table
--   -- for this as we'll be reusing these names in multiple strips, so it avoids
--   -- duplicating them. The naming convention is entirely your choice.
--   local icons = {
--       medium = {
--           'add_circle_outline',
--           'delete',
--           'link',
--       },
--       large = {
--           'info_outline',
--           'plus',
--       },
--   }
--
--   local pack = rtk.ImagePack()
--   pack:add{
--       -- Find icons.png in all the image search paths
--       src='icons.png',
--       -- Default all strips to the 'dark' style because all the icons are black.
--       -- They will automatically be recolored to white if we get() a light style.
--       style='dark',
--       -- Now define the 6 different strips in the packed image.  These are passed
--       -- as positional elements in the table we're passing to add().  Note that if
--       -- only one dimension (w or h) is passed, the subimage is assumed to be square.
--       --
--       -- 1x density
--       {w=18, names=icons.medium, size='medium', density=1},
--       {w=24, names=icons.large, size='large', density=1},
--       -- 1.5x density
--       {w=28, names=icons.medium, size='medium', density=1.5},
--       {w=36, names=icons.large, size='large', density=1.5},
--       -- 2x density
--       {w=36, names=icons.medium, size='medium', density=2},
--       {w=48, names=icons.large, size='large', density=2},
--   }
--
-- Now, because the image names have been registered as icons, we can reference the icon
-- names in widget attributes.  Two examples below -- these icons will automatically adapt
-- to the current UI scale.
--
-- @code
--       -- There is no ':size' suffix in the icon name, so default_size is used,
--       -- which is going to be 'medium' because we didn't explicitly define otherwise
--       -- when we created the ImagePack earlier.
--       local button = rtk.Button{icon='delete', circular=true, color='crimson'}
--       local infobox = rtk.HBox{
--           valign='center', spacing=5, margin=10,
--           -- Here we ask for the large
--           rtk.ImageBox{'info_outline:large'},
--           rtk.Text{'rtk makes creating scalable interfaces easy! Ish. :)'},
--       }
--
-- @note Creating ImagePack images
--  Although you can use any image editor (such GIMP, Affinity Photo, Photoshop, etc) to create
--  the packed image, [ImageMagick](https://imagemagick.org/) provides a convenient command line
--  interface to create a packed image from individual files.  If you're comfortable on the command
--  line, you might find this approach easier than using a GUI editor.
--
-- ## Aliases
--
-- In the example above, each strip had a unique combination of size and density.  But
-- consider a scenario where you want to have a `delete` icon available at different sizes
-- -- say a `medium` variant for normal buttons, and a `large` variant for circular
-- buttons.  And because you want your UI to be appropriately responsive, you would define
-- different densities for each size.
--
-- If we simplify things slightly and assume that each image just has two densities, 1x and 2x, then
-- with two image sizes (medium and large) and two densities, we need 4 variants.  That might look
-- like this:
--
-- | Size | Density | Image Dimensions |
-- |-|-|-|
-- | medium | 1x | 24x24 |
-- | medium | 2x | 48x48 |
-- | large | 1x | 48x48 |
-- | large | 2x | 96x96 |
--
-- Notice the medium icon at 2x density has the same resolution as the large icon at 1x
-- density. It would be wasteful to define the same image content multiple times in the
-- source image just because they are different size/density combinations.
--
-- Fortunately, it's possible to define multiple size/density tuples per strip,
-- effectively creating *aliases* for the subimages in the strip without having to
-- actually create redundant content in the underlying image.  This is done by using the
-- `sizes` field in the strip's definition which contains multiple `{size, density}`
-- tables instead of single `size` and `density` fields:
--
-- @code
--    local pack = rtk.ImagePack():add{
--        src='icons.png',
--        names={'delete'},
--        style='light',
--        {w=24, size='medium', density=1},
--        {w=48, sizes={{'medium', 2}, {'large', 1}}},
--        {w=96, size='large', density=2},
--    }
--
-- Here the source image just has three strips, and the middle strip containing the 48x48 icon is
-- used for both size/density combinations.
--
-- @class rtk.ImagePack
-- @see rtk.MultiImage

rtk.ImagePack = rtk.class('rtk.ImagePack')


--- Class API
--
-- @section api
rtk.ImagePack.register{
    --- After `register_as_icons()` is called, if `rtk.Image.icon()` is called with an icon
    -- name lacking an explicit image size qualifier (e.g. `delete` instead of
    -- `delete:large`), this is the default image size that will be used (default is
    -- `"medium"`).
    --
    -- Note that changing this attribute *after* calling `add()` or `register_as_icons()` will have
    -- no effect.
    --
    -- @meta read/write
    -- @type string
    default_size = 'medium',
}

--- Constructor to create a new ImagePack.
--
-- @code
--    -- In this example, the file icons.png has two strips of icons: the first strip
--    -- has two 18x18 icons representing a pixel density of 1x, and the second strip
--    -- has two 36x36 icons for 2x density.  Both are high luminance ('light') icons.
--    local pack = rtk.ImagePack():add{
--        src='icons.png',
--        -- Defaults that apply to all strips
--        style='light',
--        -- Default icon names for each strip.  This can be defined per strip, but
--        -- for this example, each strip has the same icons so we can define it
--        -- here.
--         names={'edit', 'save'},
--        -- Now define two strips, one per density
--        {w=18, h=18, density=1},
--        {w=36, h=36, density=2},
--    }
--    -- Register the subimages as icons so they can be accessed by name
--    -- anywhere across rtk that icons are accepted.
--    pack:register_as_icons()
--    -- Now they are ready to be used
--    local button = rtk.Button{'Save File', icon='save'}
--
-- Object attributes can be passed as during construction:
--
-- @code
--    -- 'medium' is default if not defined, but we can override it
--    local pack = rtk.ImagePack{default_size='large'}
--
-- @display rtk.ImagePack
function rtk.ImagePack:initialize(attrs)
    table.merge(self, self.class.attributes.defaults)

    self._last_id = 0
    -- Array of src image tables {{src=filename, recolors={style -> rtk.Image}}, ...}
    self._sources = {}
    -- 'style:name:size' -> {density -> {id, src_idx, x, y, w, h}}
    self._regions = {}
    -- 'style:name:size' -> rtk.MultiImage
    self._cache = {}

    if attrs then
        self.default_size = attrs.default_size or self.default_size
        if attrs.src then
            self:add(attrs)
            if attrs.register then
                self:register_as_icons()
            end
        end
    end
end

--- Adds a new underlying packed image to the ImagePack and defines one or more strips
-- within that packed image.
--
-- This method receives an `attrs` table that act as keyword arguments for the overall
-- image file being read, plus one or more positional (i.e. unnamed) elements that define
-- each *strip* of the image, from top to bottom.  A strip is a horizontal band across the
-- full width of the given packed image that consists of one or more *subimages* each with
-- the same resolution, @{rtk.Image.density|density}, and optionally, a
-- @{rtk.ImagePack.default_size|size} and icon *style* within the strip.
--
-- These fields are supported in the provided `attrs` table, most of which allow setting
-- default values for the strips that follow:
--
-- | Field | Type | Required | Description |
-- |-|:-:|:-:|-|
-- | `src` | string | ✔ | The name of the packed image file to read. `rtk.add_image_search_path()` is respected. |
-- | `names` | table of strings | | The default list of icon names that are assigned to each subimage in the strip. The number of elements in this table implies the width of the source image (`w * #names`), *unless* `columns` is defined. |
-- | `size` | string |  | The default size to use when not explicitly defined in a strip table. `default_size` is used as a last resort. When calling `get()`, subimage names may be qualified with an explicit size based on this name (e.g. `settings:large`). |
-- | `density` | number |  | The default @{rtk.Image.density|pixel density} to use when not explicitly defined in a strip table. Subimages with the same name, size and style but different densities will all be included in the `rtk.MultiImage` returned by `get()`. If not defined, a density of `1.0` is assumed. |
-- | `sizes` | table |  | If the strip represents *multiple* size/density combinations, instead of specifying a single `density` and `size`, you can define an array of `{size, density}` tables to effectively create aliases for each subimage. See the Aliases section above in the class overview for more details. |
-- | `style` | string |  | The default style to associate with each subimage a strip table.  The style value corresponds to that passed to `get()`.  Technically the style is arbitrary, however if registering the image pack as icons using `register_as_icons()`, the style `light` or `dark` must be used for proper compatibility with `rtk.Image.icon()`. |
-- | `columns` | number | | The default number of columns to use when not defined in the strip table. Large numbers of subimages may require multiple rows within a strip, because the maximum image width supported by REAPER is 8192 pixels.  The `column` field defines the number of subimages per row, allowing the subimages to effectively wrap onto multiple rows.  If nil, then a strip is equivalent to a row -- all subimages are defined in one line and the strip height is equivalent to the subimage height (`h`) -- but if defined, then the strip will be considered however tall is necessary to accommodate all the given `names` within this number of columns. |
--
-- Each table (as unnamed positional elements in the table passed to `add()`) defines a
-- *strip* -- or horizontal band -- of the `src` image.  The following fields are supported
-- in these strip tables:
--
-- | Field | Type | Required | Description |
-- |-|:-:|:-:|-|
-- | `w` | number | ✔ | The width of each subimage in this strip  |
-- | `h` | number |  | The height of each subimage in this strip (`w` is used if nil assuming, a square subimage) |
-- | `names` | table of strings | ✔ | As described above but for this specific strip |
-- | `size` | string | | As described above but for this specific strip |
-- | `density` | number | | As described above but for this specific strip |
-- | `sizes` | table | | As described above but for this specific strip |
-- | `style` | string | | As described above but for this specific strip |
-- | `columns` | number | | As described above but for this specific strip |
--
-- The order of the strips is important: it must exactly correspond to the source image.
-- Each successive call to `add()` includes a separate image (and its corresponding
-- strips) to the image pack.  (The order `add()` is called doesn't matter, however.)
--
-- @example
--   local pack = rtk.ImagePack()
--   pack:add{src='cryptoactors.png', {w=64, names={'alice', 'bob', 'eve', 'mallory'}}}
--   local img = pack:get('eve')
--
-- Finally, as an alternative to passing each strip table as a positional element in the
-- outer table passed to this method, you may also pass a table of strip tables as the
-- `strips` field:
--
-- @code
--   -- This is equivalent to above.  Feel free to use whichever is most ergonomic for
--   -- the situation.
--   pack:add{src='cryptoactors.png', strips={
--       {w=64, names={'alice', 'bob', 'eve', 'mallory'}}
--   }}
--
--
-- @tparam table attrs the definition of the source image and all of its strips
-- @treturn rtk.ImagePack returns self for method chaining
function rtk.ImagePack:add(attrs)
    assert(type(attrs) == 'table', 'ImagePack:add() expects a table')
    assert(type(attrs.src) == 'string' or rtk.isa(attrs.src, rtk.Image), '"src" field is missing or is not string or rtk.Image')
    assert(not attrs.strips or type(attrs.strips) == 'table', '"strips" field must be a table')
    local strips = attrs.strips or attrs
    assert(#strips > 0, 'no strips provided (either as a "strips" field or as positional elements elements)')

    local src_idx = #self._sources + 1
    self._sources[src_idx] = {src=attrs.src, recolors={}}

    local y = 0
    for _, strip in ipairs(strips) do
        assert(type(strip) == 'table', 'ImagePack strip definition must be a table')
        assert(type(strip.w) == 'number' or type(strip.h) == 'number', 'ImagePack strip requires either "w" or "h" fields')
        local names = strip.names or attrs.names
        assert(type(names) == 'table', 'ImagePack strip missing "names" field or is not table')

        local sizes = strip.sizes
        if not sizes then
            local density = strip.density or attrs.density or 1
            if strip.size then
                sizes = {{strip.size, density}}
            elseif attrs.sizes then
                sizes = attrs.sizes
            elseif attrs.size then
                sizes = {{attrs.size, density}}
            else
                sizes = {{self.default_size, density}}
            end
        end

        strip.w = strip.w or strip.h
        strip.h = strip.h or strip.w
        local columns = strip.columns or attrs.columns
        local rowwidth = columns and (columns * strip.w)
        local style = strip.style or attrs.style
        local x = 0
        for _, name in ipairs(names) do
            local subregion = {
                id=self._last_id,
                src_idx=src_idx,
                x=x,
                y=y,
                w=strip.w,
                h=strip.h,
            }
            self._last_id = self._last_id + 1
            for _, sizedensity in ipairs(sizes) do
                local size, density = table.unpack(sizedensity)
                local key = string.format('%s:%s:%s', style, name, size)
                local densities = self._regions[key]
                if not densities then
                    densities = {}
                    self._regions[key] = densities
                elseif densities[density] then
                    error(string.format(
                        'duplicate image name "%s" for style=%s size=%s density=%s',
                        name, style, size, density
                    ))
                end
                densities[density] = subregion
            end
            x = x + strip.w
            if rowwidth and x >= rowwidth then
                x = 0
                y = y + strip.h
            end
        end
        y = y + strip.h
    end
    return self
end

function rtk.ImagePack:_get_densities(name, style)
    local key
    if not name:find(':') then
        key = string.format('%s:%s:%s', style, name, self.default_size)
    else
        key = string.format('%s:%s', style, name)
    end
    return key, self._regions[key]
end

--- Returns an `rtk.MultiImage` containing all pixel densities for the given subimage name
-- and style.
--
-- Names are as provided to `add()`, but may also be qualified with an explicit size by
-- suffixing the name with `:<size>`. For example, `info-outline:large`, where
-- `info-outline` is the subimage name and `large` is the size.  When no size qualifier is
-- given, then `default_size` is assumed.
--
-- @code
--  local pack = rtk.ImagePack()
--  pack:add{
--      src='icons.png',
--      style='light',
--      names={'add', 'edit', 'delete'},
--      {w=18, size='medium'},
--      {w=24, size='large'},
--  }
--  -- The style parameter isn't defined, so the style that matches the current theme
--  -- is automatically picked.  If we're currently using a dark theme, this means
--  -- light icons, which is exactly what we added.  Meanwhile if we're using
--  -- a light theme, then the returned icon image will automatically be recolored
--  -- to black.
--  local img = pack:get('add:large')
--  -- We can force the recolor to happen by specifically asking for the opposite style
--  -- than what we added.
--  local dark = pack:get('add:large', 'dark')
--
-- By including the size qualifier in the image name this way, it allows requesting
-- size variants in any widget attribute that implicitly calls `rtk.Image.icon()`, such
-- as `rtk.Button.icon`.  For example:
--
-- @code
--   -- Given the snippet above, register the image pack so that the image names can
--   -- be accessed by widgets.
--   pack:register_as_icons()
--   -- Now, having registered the subimages as icons, this works
--   local button = rtk.Button{icon='add:large', circular=true}
--
-- If one or more subimages are found with the given name. size, and style, they're
-- consolidated and returned in the `rtk.MultiImage`. If no matches are found, then other
-- styles are searched for the same name and style. First, if the given style is nil, then
-- the icon style appropriate for the @{rtk.theme|current theme} is searched.  Thereafter
-- the behavior is the same as `rtk.Image.icon()`, recoloring the image if needed to match
-- the requested style.
--
-- The on-disk image files are not actually read when `add()` is called, rather they are
-- lazily read on demand when `get()` is called.  By using different files for the various
-- densities you want to support, this can conserve on memory as density variants aren't
-- loaded unless the @{rtk.scale|UI scale} warrants it.
--
-- @tparam string name the name of the subimage as previously described by `add()`.
-- @tparam string|nil style the style of the subimage as previously described by `add().` If
--   no image can be found with the requested style, other styles are searched and are recolored
--   if necerssary.
-- @treturn rtk.MultiImage|nil a multi-density image encapsulating all variants of the requested
--  subimage name and style, or nil if the given image name could not be found.
function rtk.ImagePack:get(name, style)
    if not name then
        return
    end
    local key, densities = self:_get_densities(name, style)
    local multi = self._cache[key]
    if multi then
        -- Cache hit
        return multi
    end
    local recolor = false
    if not densities and not style then
        -- No icon style was given, but no image was found registered under the nil
        -- style.  Let's go ahead and try with the current theme's icon style.
        style = rtk.theme.iconstyle
        densities = self:_get_densities(name, style)
    end
    if not densities and style then
        -- An icon style was given, try the other style
        local otherstyle = style == 'light' and 'dark' or 'light'
        recolor = true
        _, densities = self:_get_densities(name, otherstyle)
        if not densities then
            -- Nothing registered under the other style.  Try the nil style as a last resort.
            -- Nil styles are not recolored, but it's better than failing outright.
            _, densities = self:_get_densities(name, nil)
            recolor = false
        end
    end
    if not densities then
        return
    end
    local multi = rtk.MultiImage()
    for density, region in pairs(densities) do
        local src = self._sources[region.src_idx]
        local img = src.img
        -- Ensure we load the source image (even though it may need to be recolored)
        if not img then
            img = rtk.Image():load(src.src)
            src.img = img
        end
        if recolor then
            img = src.recolors[style]
            if not img then
                img = src.img:clone():recolor(style == 'light' and '#ffffff' or '#000000')
                src.recolors[style] = img
            end
        end
        assert(img, string.format('could not read "%s"', src.src))
        multi:add(img:viewport(region.x, region.y, region.w, region.h, density))
    end
    multi.style = style
    self._cache[key] = multi
    return multi
end

--- Registers all subimage names previously defined via `add()` as icon names for later
-- use with `rtk.Image.icon()`.
--
--
-- Once registered, widget attributes that implicitly call `rtk.Image.icon()` can access
-- the image pack's subimages by name. For example, `rtk.Button.icon`, `rtk.Entry.icon`,
-- `rtk.ImageBox.image`, etc.
--
--- @treturn rtk.ImagePack returns self for method chaining
function rtk.ImagePack:register_as_icons()
    local default_size = self.default_size
    for key, _ in pairs(self._regions) do
        local idx = key:find(':')
        local name = key:sub(idx + 1)
        rtk.Image._icons[name] = self
        idx = name:find(':')
        local size = name:sub(idx + 1)
        if size == default_size then
            name = name:sub(1, idx - 1)
            rtk.Image._icons[name] = self
        end
    end
    return self
end