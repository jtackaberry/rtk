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

--- Base class for all widgets.  Not intended to be directly used, but rather subclassed
-- to create specific widgets.  However all widgets provide at least this interface.
--
-- @class rtk.Widget
rtk.Widget = rtk.class('rtk.Widget')


--- Alignment Constants.
--
-- Used with the `halign` and `valign` fields to control horizontal and vertical alignment
-- of a widget's contents within its own box.
--
-- Lowercase strings of these constants can be used for convenience (e.g. `'center'`
-- instead of `rtk.Widget.CENTER`).  These strings, noted in the middle columns below, are
-- automatically converted to the appropriate numeric constants.
--
-- @section alignmentconst
-- @compact

--- Align contents to widget's left edge (for `halign`)
-- @meta 'left'
rtk.Widget.static.LEFT = 0
--- Align contents to widget's top edge (for `valign`)
-- @meta 'top'
rtk.Widget.static.TOP = 0
--- Center align contents within widget boundary (used for both `valign` and `halign`)
-- @meta 'center'
rtk.Widget.static.CENTER = 1
--- Align contents to widget's right edge (for `halign`)
-- @meta 'right'
rtk.Widget.static.RIGHT = 2
--- Align contents to widget's bottom edge (for `valign`)
-- @meta 'bottom'
rtk.Widget.static.BOTTOM = 2

--- Position Constants.
--
-- Used with the `position` field to control how containers will position and scroll
-- widgets in relation to other widgets in the window.
--
-- Lowercase strings of these constants can be used, e.g. `'relative'` instead of
-- `rtk.Widget.RELATIVE`, or `'fixed-flow'` instead of `rtk.Widget.FIXED_FLOW`. These
-- strings are automatically converted to the appropriate numeric constants.
--
-- @note Like CSS
--   If you're familiar with the
--   [position property in CSS](https://developer.mozilla.org/en-US/docs/Web/CSS/position),
--   your intuitions here should mostly apply.
--
-- @section positionconst
-- @compact

-- Internal note: the first 4 bits of position constants is reserved for these flags
-- which control behavior that can apply to multiple position values.
--
-- Containers will incorporate widget geometry in calculating layout.  Otherwise they
-- be out-of-flow.
rtk.Widget.static.POSITION_INFLOW = 0x01
-- Widget is pinned in its initially calculated position even as the viewport scrolls.
rtk.Widget.static.POSITION_FIXED = 0x02

--- Widget is positioned normally by its parent container and respects the widget's `x` and
-- `y` coordinates, and scrolls within any @{rtk.Viewport|viewport} it belongs to.
--
-- Widgets with non-zero x and y coordinates modify their drawing position relative to
-- their parent but don't affect layout relative to siblings.  For example, a widget in an
-- `rtk.VBox` with `y=50` will spill into its siblings' space, while the overall VBox
-- layout is unchanged.
--
-- If you do want to modify the widget's position and *also* affect sibling layout, use
-- `margin` or @{rtk.Container.padding|container cell padding} (they are
-- equivalent) instead of the `x` and `y` attributes.
-- @meta 'relative'
rtk.Widget.static.RELATIVE = rtk.Widget.POSITION_INFLOW | 0x10

--- Widget is positioned normally by its parent container and respects the widget's `x` and
-- `y` coordinates, but no space is created for the widget in the container layout
-- (which applies to containers that arrange children relative to one another like `rtk.Box`,
-- but not `rtk.Container` which treats each child independently).  This means that in boxes,
-- the sibling immediately following will share the same position and overlap.
--
-- `z` order across siblings in a @{rtk.Box|box container} is respected, so it's possible
-- to draw an absolute positioned widget above or below its siblings.
-- @meta 'absolute'
rtk.Widget.static.ABSOLUTE = 0x20

--- Widget is positioned initially according to absolute positioning, but then is fixed on
-- the screen even as the parent viewport is scrolled.  As with absolute positioning, `z`
-- order between siblings applies.
--
-- Note that if a fixed widget is a child of a non-fixed container and that container
-- scrolls out of view, the fixed widget will not be drawn.
-- @meta 'fixed'
rtk.Widget.static.FIXED = rtk.Widget.POSITION_FIXED | 0x40

--- Like `FIXED` but the dimensions of the widget are incorporated in the overall flow
-- of the parent container.
-- @meta 'fixed-flow'
rtk.Widget.static.FIXED_FLOW = rtk.Widget.POSITION_INFLOW | rtk.Widget.POSITION_FIXED | 0x80




--- Scalability Constants.
--
-- Used with the `scalability` field to control how the widget should respond to
-- changes to the @{rtk.scale|global scale level}.
--
-- Lowercase strings of these constants can be used (e.g. `'box'` instead of
-- `rtk.Widget.BOX`).  These strings are automatically converted to the appropriate
-- numeric constants.
--
-- @section scaleconst
-- @compact

--- Scales box model properties (padding, margin, etc) as well as the inner contents
-- (e.g. images and font sizes) of the widget, but fixed dimensions are *not* scaled.
-- @meta 'box'
rtk.Widget.static.BOX = 1

--- Everything from `BOX`, plus user-specified static widget and height will also be
-- scaled.  Fractional relative dimensions (e.g. 0.5) are not however scaled.  This allows
-- a fixed-dimension widget to scale up and down with `rtk.scale`.
--
-- This is the default `scalability` of all widgets.
--
-- @meta 'full'
rtk.Widget.static.FULL = rtk.Widget.BOX | 2


--- Reflow Constants.
--
-- Used with `attr()` and `queue_reflow()` to influence reflow behavior.
--
-- A **reflow** is the process of calculating the geometry of one or more widgets within the
-- window.  See `reflow()` for more explanation.
--
-- @section reflowconst
-- @compact

--- Use a sensible default, which is further described by the individual methods
-- using these constants.
rtk.Widget.static.REFLOW_DEFAULT = nil
--- Do not perform any reflow at all, regardless of whether the default behavior would have
-- performed one.
rtk.Widget.static.REFLOW_NONE = 0
--- Only do a *partial* reflow, which means only the specific widget in question will be
-- reflowed, not the entire window.  This is done when the widget's own size won't change,
-- but it may need to rearrange the contents within it.  For example, changing `halign`
-- doesn't affect the widget's box but may affect where internal contents are positioned, so
-- a partial reflow is needed.
rtk.Widget.static.REFLOW_PARTIAL = 1
--- Recalculate the geometry of *all* `visible` widgets in the window.  This includes
-- widgets that are offscreen (for example in a viewport below the fold): unless
-- `visible` is false, they will be reflowed.  This is the most expensive type of reflow.
rtk.Widget.static.REFLOW_FULL = 2

rtk.Widget.static._calc_border = function(self, value)
    if type(value) == 'string' then
        -- Support CSS-like border strings.
        local parts = string.split(value)
        if #parts == 1 then
            -- Border color, assuming 1px.
            return {{rtk.color.rgba(parts[1])}, 1}
        elseif #parts == 2 then
            -- Width in pixels and border color
            local width = parts[1]:gsub('px', '')
            return {{rtk.color.rgba(parts[2])}, tonumber(width)}
        else
            error('invalid border format')
        end
    elseif value then
        assert(type(value) == 'table', 'border must be string or table')
        -- Maybe in the form {{r, g, b, a}, size}
        if #value == 1 then
            -- Table but just with border color, assume 1px.
            return {rtk.color.rgba({value[1]}), 1}
        elseif #value == 2 then
            return value
        elseif #value == 4 then
            -- Assume it's a 4-color RGBA value with automatic 1px thickness
            return {value, 1}
        else
            log.exception('invalid border value: %s', table.tostring(value))
            error('invalid border value')
        end
    end
end

rtk.Widget.static._calc_padding_or_margin = function(value)
    if not value then
        return 0, 0, 0, 0
    elseif type(value) == 'number' then
        return value, value, value, value
    else
        if type(value) == 'string' then
            -- Convert string format to numeric form
            local parts = string.split(value)
            value = {}
            for i = 1, #parts do
                local sz = parts[i]:gsub('px', '')
                value[#value+1] = tonumber(sz)
            end
        end
        if #value == 1 then
            -- Single value table applies to all sides
            return value[1], value[1], value[1], value[1]
        elseif #value == 2 then
            -- Vertical, horizontal
            return value[1], value[2], value[1], value[2]
        elseif #value == 3 then
            -- Top, horizontal, bottom
            return value[1], value[2], value[3], value[2]
        elseif #value == 4 then
            return value[1], value[2], value[3], value[4]
        else
            error('invalid value')
        end
    end
end

rtk.Widget.register{
    --- Widget Attributes.
    --
    -- The appearance and behavior of widgets in rtk is managed mostly through **attributes**.
    -- Attributes are special fields in widgets that, apart from the attribute values
    -- themselves, carry associated metadata, such as details about what should happen
    -- internally when the attribute is updated, or how it should be animated.  (These are
    -- largely internal details but you can read more about how `rtk.Attribute` works.)
    --
    -- Attributes that are read/write can be set to influence appearance or behavior, while
    -- read-only attributes are only a reflection of current state.
    --
    -- The proper way to set an attribute is via the `attr()` method that is provided by
    -- the base `rtk.Widget` class.
    --
    -- @code
    --   local button = container:add(rtk.Button{'Nuke it from orbit'})
    --   -- After 0.5 seconds, this changes the button color attribute to red,
    --   -- and modifies the label.
    --   rtk.callafter(1.5, function()
    --      button:attr('color', 'red')
    --      button:attr('label', "It's the only way to be sure")
    --   end)
    --
    -- Reading back attributes that you previously set is just a matter of access the
    -- attribute field directly on the widget.  Following the above example:
    --
    -- @code
    --   -- This will display 'red' from above
    --   log.info('Button color is: %s', button.color)
    --   -- This will display "It's the only way to be sure" (again from above)
    --   log.info('Button label is: %s', button.label)
    --
    --
    -- #### Calculated Attributes
    --
    -- When you set the value of a read/write attribute, it is ultimately translated into
    -- a low-level **calculated** value.  These calculated values can be fetched via the `calc()`
    -- method.  In the above code example:
    --
    -- @code
    --   -- This returns the 4-element {r,g,b,a} table holding the calculated color
    --   -- used internally during drawing.
    --   local c = button:calc('color')
    --   log.info('Calculated color table: %s', table.tostring(c))
    --
    -- Similarly, if you set `halign='center'` the stringified value of the alignment
    -- constant is translated to `rtk.Widget.CENTER`, which would be returned by
    -- `widget:calc('halign')`.  Or, suppose you set `w=0.5` to assign a 50% relative
    -- width to the widget (more on that later), then once the widget reflows
    -- `widget:calc('w')` will return the calculated width in pixels.
    --
    -- In most cases the value you store in the attribute -- what rtk calls the *exterior*
    -- value -- remains the way you set it, and rtk internally uses the calculated
    -- variants.  However, whenever a user interacts with a widget in that affects an
    -- attribute, the new value is synced back to both the calculated value *and* the
    -- exterior value.  For example, `rtk.Entry.caret` is modified when the user moves
    -- where the caret is positioned.  Or `rtk.Window.w` is updated when the user resizes
    -- the width of the window.
    --
    -- @section widget.attributes

    --- Geometry and Positioning Attributes.
    --
    -- **Positioning widgets** on the screen in rtk is done by adding widgets to containers.
    -- There are different containers that provide varying types of layouts.  You generally
    -- want to let the container dictate the widget's positioning, but you can define it
    -- more explicitly if you need to.
    --
    -- `x` and `y` coordinates are relative to the parent container and can be negative.
    -- If you're familiar with HTML, this is equivalent to `position: relative` in CSS.
    -- These coordinates don't affect the layout of the parent container at all, nor do
    -- they affect the geometry of any siblings in the same container, but rather they
    -- only affect this widget's position relative to where the parent container would
    -- have normally placed it.
    --
    -- Consequently, in @{rtk.Box|boxes}, setting x/y coordinates on a widget can cause it
    -- to shift into the cells of siblings (or even outside the container's own box).
    -- Sometimes this is what you want, for example to produce certain effects, but
    -- usually not.  However for the base `rtk.Container`s, since this simple type of
    -- container doesn't impose any positioning on its children, it makes more sense to
    -- specify x/y, although they are usually combined with `halign` and `valign` cell
    -- attributes.  For example, you might set the widget to `x=-20` and then add it to an
    -- `rtk.Container` with a cell attribute of `halign='right'` in which case it will
    -- cause the right edge of the widget to be positioned 20 pixels from the right edge
    -- of its parent container.
    --
    -- But even in the above example, it's more idiomatic to use an `rpadding=20` cell
    -- attribute in combination with `halign='right'` and leave the widget's `x` attribute
    -- at `0`.
    --
    -- All that's to say, you almost *never* need or want to specify `x` or `y`. You can,
    -- but there are probably more robust and more readable positioning options by
    -- combining @{container.cellattrs|container cell alignment with cell padding}.
    -- (Because remember that `x` and `y` do not affect the position of siblings in the
    -- same container, whereas cell padding does.)  See `rtk.Container` for more on cell
    -- attributes.
    --
    -- **Width and height** are unspecified by default, which means they will choose an
    -- appropriate size based on the parent-supplied bounding box, and the widget's natural
    -- desired size (called the *intrinsic size*).
    --
    -- If `w` and `h` are between 0.0 and 1.0 or negative, they are *relative sizes*. If
    -- between 0.0 and 1.0, they indicate a fraction of the bounding box imposed by our
    -- parent.  For example, `w=0.6` means 60% of the parent-specified bounding box. If
    -- they're negative, then they are relative to the far edge of the bounding box, so
    -- e.g. `w=-50` means the widget will extend to 50px left of the right edge of the
    -- bounding box.
    --
    -- When using relative sizes in widgets placed within an `rtk.Viewport`, the size will
    -- be relative to viewport's bounding box even though the widget may technically be
    -- allowed an unconstrained size (if the viewport can scroll in that direction).  For
    -- example, if an `rtk.VBox` called "box" is the immediate child of a viewport, you
    -- could do `box:add(rtk.Button{w=0.8}, {halign='center'})` which would create a
    -- button 80% of the viewport's width and center-align it within the viewport's
    -- bounding box. Meanwhile, `box:add(rtk.Button{w=800})` would add a button with a
    -- fixed width of 800 pixels, which may require scrolling the viewport horizontally to
    -- see it all.
    --
    -- The geometry attributes mentioned above all have read-only calculated variants as
    -- determined by `rtk.Widget:reflow()` stored in the `calc` table, which indicate the
    -- final geometry of the widget relative to its parent container's outer (border)
    -- coordinates. This includes padding per the `border-box` style box model (see
    -- `padding`).
    --
    -- So for example if `w`=`nil`, after the window is reflowed, `calc.w` will hold the final
    -- calculated width in pixels, at least until the next reflow.  These calculated
    -- values are guaranteed never to be nil when the widget has been `realized`.
    --
    -- @section geometry

    --- Left position of widget relative to parent in pixels (default `0`)
    -- @meta read/write
    -- @type number
    x = rtk.Attribute{
        default=0,
        reflow=rtk.Widget.REFLOW_FULL,
        reflow_uses_exterior_value=true,
    },
    --- Top position of widget relative to parent in pixels (default `0`)
    -- @meta read/write
    -- @type number
    y = rtk.Attribute{
        default=0,
        reflow=rtk.Widget.REFLOW_FULL,
        reflow_uses_exterior_value=true,
    },
    --- Width of widget in pixels, or as a fraction of parent's width (default `nil`).
    -- Where:
    --   * values between 0.0 and 1.0 (inclusive) are considered a ratio of the parent width
    --   * negative values are relative to the right edge of the parent
    --   * while nil means widget does not define a width and will use its intrisic width (up to the
    --     parent-imposed width).
    --
    -- Because `1.0` means 100% of the parent's width it does mean that you can't
    -- explicitly specify a widget width of 1px.  If you think you need to do this, you're
    -- probably doing something wrong.  But if for some reason you desperately need a
    -- widget 1px in size, you can use `1.01` as the value.  It will get rounded down to 1
    -- pixel during rendering.
    --
    -- This attribute is animatable, where animating toward relative sizes (0.0 - 1.0) or
    -- nil (intrinsic size) is supported.
    --
    -- The calculated value (`widget:calc('w')`) is also adjusted to account for `rtk.scale`,
    -- provided the `scalability` attribute is set to `FULL` (as is the default).
    --
    -- @meta read/write
    -- @type number|nil
    w = rtk.Attribute{
        type='number',
        reflow=rtk.Widget.REFLOW_FULL,
        reflow_uses_exterior_value=true,
        animate=function(self, anim, scale)
            local calculated = anim.resolve(anim.easingfunc(anim.pct))
            local exterior
            if anim.doneval and anim.doneval ~= rtk.Attribute.NIL and anim.doneval ~= rtk.Attribute.DEFAULT then
                exterior = (anim.pct < 1 and calculated or anim.doneval) / (scale or rtk.scale.value)
            end
            if anim.dst == 0 or anim.dst > 1 then
                -- Ensure if we are animating towards a non-fractional width (including 0)
                -- that we don't return a exterior value of 0 < value <= 1.0 because this
                -- will result in calculation of a relative size.
                exterior = (type(exterior) == 'number' and exterior > 0 and exterior <= 1.0) and 1.01 or exterior
            end
            return calculated, exterior
        end,
    },
    --- Like `w` but for widget height (default `nil`)
    -- @meta read/write
    -- @type number|nil
    h = rtk.Attribute{
        type='number',
        reflow=rtk.Widget.REFLOW_FULL,
        reflow_uses_exterior_value=true,
        animate=rtk.Reference('w'),
    },
    --- The z-index, or "stack level" that defines what the order the widget will be drawn
    -- in relation to its immediate siblings (default 0).  Widgets with a higher z-index
    -- will be drawn *after* lower z-index widgets (and therefore appear above them), and
    -- their events will be handled *before* lower z-index widgets.
    -- @meta read/write
    -- @type number
    z = rtk.Attribute{default=0, reflow=rtk.Widget.REFLOW_FULL},

    --- The minimum width in pixels the widget is allowed to have, or nil for no minimum
    -- (default `nil`).  When this is specified, the widget will disregard any bounding
    -- box contraints by its parent, causing the parent container to overflow its own
    -- bounding box if necessary, which may result in needing to scroll if within
    -- an `rtk.Viewport`.
    -- @meta read/write
    -- @type number|nil
    minw = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},
    --- Like `minw` but for height (default `nil`)
    -- @meta read/write
    -- @type number|nil
    minh = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},
    --- The maximum width in pixels the widget is allowed to have, or nil for no maximum
    -- (default nil).  This will constrain a widget's width if it is added to a container
    -- with the @{rtk.Container.fillw|fillw}=true cell attribute, or if the widget has
    -- a relative width (e.g. `w=0.5`).  In either case the widget will not exceed
    -- `maxw`.
    -- @meta read/write
    -- @type number|nil
    maxw = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},
    --- Like `maxw` but for height (default `nil`)
    -- @meta read/write
    -- @type number|nil
    maxh = rtk.Attribute{type='number', reflow=rtk.Widget.REFLOW_FULL, reflow_uses_exterior_value=true},

    --- Horizontal alignment of contents within the widget's calculated width
    -- (default `LEFT`).  See @{alignmentconst|alignment constants}.
    -- @meta read/write
    -- @type alignmentconst
    halign = rtk.Attribute{
        default=rtk.Widget.LEFT,
        calculate={left=rtk.Widget.LEFT, center=rtk.Widget.CENTER, right=rtk.Widget.RIGHT},
    },
    --- Vertical alignment of contents within the widget's calculated height
    -- (default `TOP`). See @{alignmentconst|alignment constants}.
    -- @meta read/write
    -- @type alignmentconst
    valign = rtk.Attribute{
        default=rtk.Widget.TOP,
        calculate={top=rtk.Widget.TOP, center=rtk.Widget.CENTER, bottom=rtk.Widget.BOTTOM},
    },
    --- A bitmap of scale constants that defines how the widget will behave
    -- with respect to `rtk.scale` (default `FULL`).
    -- See @{scaleconst|scalability constants}.
    -- @meta read/write
    -- @type scaleconst
    scalability = rtk.Attribute{
        default=rtk.Widget.FULL,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate={box=rtk.Widget.BOX, full=rtk.Widget.FULL},
    },
    --- Controls how the widget reacts when the parent viewport is scrolled
    -- (default `RELATIVE`).  See @{positionconst|position constants}.
    -- @meta read/write
    -- @type positionconst
    position = rtk.Attribute{
        default=rtk.Widget.RELATIVE,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate={
            relative=rtk.Widget.RELATIVE,
            absolute=rtk.Widget.ABSOLUTE,
            fixed=rtk.Widget.FIXED,
            ['fixed-flow']=rtk.Widget.FIXED_FLOW
        },
    },
    --- Bounding box geometry supplied from parent on last `reflow()`. Primarily maintained
    -- so that `reflow()` can be called without any arguments and still produce a useful
    -- result. The fields of this table correspond exactly to `reflow()`'s arguments.
    -- @meta read-only
    -- @type table
    box = nil,

    --- The x coordinate within our drawing target that we should offset our position
    -- as requested by our parent container in its last invocation of @{_draw|draw}.
    --
    -- If the child is parented within a `rtk.Viewport`, this will not represent
    -- client coordinates.  For client coordinates, use `clientx` instead.
    -- @meta read-only
    -- @type number
    offx = nil,
    --- Like `offx` but for the y coordinate
    -- @meta read-only
    -- @type number
    offy = nil,

    --- The x client coordinate of the widget as of last @{_draw|draw}.  Client coordinates
    -- are always relative to the @{rtk.Window|window} (where the window's top-left point is
    -- `0,0`), regardless of whether the widget is within a @{rtk.Viewport|viewport}.
    --
    -- Client coordinates are used when interacting with the mouse: the widget might be
    -- placed at the very end of a 5000px height container, but if the viewport holding
    -- that container is scrolled down such that the widget is at the very top of the
    -- screen, its `clienty` coordinate will be 0.
    --
    -- Another use case is when popping up an OS-native context menu (`rtk.NativeMenu`), where
    -- we want the menu to popup relative to the widget's current position on screen.
    -- @meta read-only
    -- @type number
    clientx = nil,
    --- Like `clientx` but for the y coordinate
    -- @meta read-only
    -- @type number
    clienty = nil,


    --- Box Model Attributes.
    --
    -- rtk's box model allows defining margin, border, and padding around the inner
    -- content of all widgets.  When the widget's @{geometry|dimensions} aren't explicitly
    -- defined, its intrinsic size will include padding and border, in addition to the
    -- widget's internal content.
    --
    -- @note Similar to CSS
    --  If you're familiar with web design, rtk's notion of inner content, padding, border,
    --  and margin are the same as CSS's box model, specifically the `border-box` box sizing
    --  model  where padding and border sizes are included in the widget's dimensions.
    --  That is, if either `w` or `h` attributes are specified, then it implicitly includes
    --  padding and border (but not margin), and the inner content will shrink accordingly.
    --
    -- ![](../img/rtk-box-model.png)
    --
    -- Widget padding affects the amount of space between the widget's border (based on
    -- its own dimensions) and its internal content.  For example, an `rtk.Button` with
    -- a padding of 10px and no explicit dimensions (i.e. it will use its intrinsic size)
    -- will ensure the width and height of the button surface fits its icon and/or label
    -- with a 10px gap to the button's edges.
    --
    -- Meanwhile, margin affects the amount of space *around* the widget's own box.  It is
    -- used by parent containers to determine how to place the widget within a container
    -- cell.  Widget margin is exactly equivalent to @{rtk.Container.padding|cell padding}
    -- which can be specified when you add the widget to a container.  In fact, if both
    -- margin and cell padding are defined, they sum together during layout.  See
    -- @{container.cellattrs|here} for more on cell attributes.
    --
    -- @section padding

    -- Note: padding and margin defaults are internally left as nil, and nil values are
    -- interpreted as 0 during layout and drawing.

    --- Shorthand to set padding on all 4 sides of the widget at once (default 0).
    --
    -- Like CSS, this can be a string in one of these forms:
    --
    --  1. `'5px'` - padding of 5 pixels on all sides
    --  2. `'10px 5px'` - padding of 10 pixels on top and bottom, and 5 pixels on left
    --      and right
    --  3. `'10px 5px 15px'` - top, horizontal (left/right), and bottom padding
    --  4. `'5px 10px 2px 4px'` - top, right, bottom, left
    --
    -- Alternatively, a table of 1 to 4 numeric values can be passed as well, with the
    -- same element ordering as above for strings.
    --
    -- @note Supported units
    --   The "px" unit suffix is optional.  Pixels are assumed and no other unit is currently
    --   supported.  Other units may be supported in the future.
    -- @meta read/write
    -- @type number|table|string
    padding = rtk.Attribute{
        replaces={'tpadding', 'rpadding', 'bpadding', 'lpadding'},
        get=function(self, attr, target)
            return {target.tpadding, target.rpadding, target.bpadding, target.lpadding}
        end,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=function(self, attr, value, target)
            local t, r, b, l = rtk.Widget.static._calc_padding_or_margin(value)
            target.tpadding, target.rpadding, target.bpadding, target.lpadding = t, r, b, l
            return {t, r, b, l}
        end
    },
    --- Top padding in pixels; if specified, overrides `padding` for the top edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    tpadding = rtk.Attribute{priority=true, reflow=rtk.Widget.REFLOW_FULL},
    --- Right padding in pixels; if specified, overrides `padding` for the right edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    rpadding = rtk.Reference('tpadding'),
    --- Bottom padding in pixels; if specified, overrides `padding` for the bottom edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    bpadding = rtk.Reference('tpadding'),
    --- Left padding in pixels; if specified, overrides `padding` for the left edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    lpadding = rtk.Reference('tpadding'),

    --- Shorthand to set margin on all 4 sides of the widget at once (default 0).  The format
    -- is the same as for `padding`.
    -- @meta read/write
    -- @type number|table|string
    margin = rtk.Attribute{
        default=0,
        replaces={'tmargin', 'rmargin', 'bmargin', 'lmargin'},
        get=function(self, attr, target)
            return {target.tmargin, target.rmargin, target.bmargin, target.lmargin}
        end,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=function(self, attr, value, target)
            local t, r, b, l = rtk.Widget.static._calc_padding_or_margin(value)
            target.tmargin, target.rmargin, target.bmargin, target.lmargin = t, r, b, l
            return {t, r, b, l}
        end
    },
    --- Top margin in pixels; if specified, overrides `margin` for the top edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    tmargin = rtk.Attribute{priority=true, reflow=rtk.Widget.REFLOW_FULL},
    --- Right margin in pixels; if specified, overrides `margin` for the right edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    rmargin = rtk.Reference('tmargin'),
    --- Bottom margin in pixels; if specified, overrides `margin` for the bottom edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    bmargin = rtk.Reference('tmargin'),
    --- Left margin in pixels; if specified, overrides `margin` for the left edge (default 0).
    -- Must be numeric.
    -- @meta read/write
    -- @type number
    lmargin = rtk.Reference('tmargin'),


    --- Border to be drawn around the widget's box (default nil).  Borders can be defined
    -- as a CSS-like string that takes border width and/or color (e.g. `'1px #ff0000'` or
    -- `'#ffff00'`) or a 2-element table holding `{color, numeric width}`.
    -- @meta read/write
    -- @type table|string
    border = rtk.Attribute{
        -- Must reflow even for border as it will affect the intrinsic size.
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=function(self, attr, value, target)
            local border = rtk.Widget.static._calc_border(self, value)
            target.tborder = border
            target.rborder = border
            target.bborder = border
            target.lborder = border
            -- Indicates that all edges are the same and we can take the fast path in drawing.
            target.border_uniform = true
            return border
        end
    },
    --- Top border; if specified overrides `border` for the top edge (default nil).
    -- @meta read/write
    -- @type table|string
    tborder = rtk.Attribute{
        priority=true,
        reflow=rtk.Widget.REFLOW_FULL,
        calculate=function(self, attr, value, target)
            target.border_uniform = false
            return rtk.Widget.static._calc_border(self, value)
        end,
    },
    --- Right border; if specified overrides `border` for the right edge (default nil).
    -- @meta read/write
    -- @type table|string
    rborder = rtk.Reference('tborder'),
    --- Bottom border; if specified overrides `border` for the bottom edge (default nil).
    -- @meta read/write
    -- @type table|string
    bborder = rtk.Reference('tborder'),
    --- Left border; if specified overrides `border` for the left edge (default nil).
    -- @meta read/write
    -- @type table|string
    lborder = rtk.Reference('tborder'),


    --- Appearance and Behavior Attributes.
    --
    -- @section appearance

    --- Indicates whether the widget should be rendered by its parent (default
    -- `true`).  If false, this is equivlent to CSS's `display:none` where it is
    -- not considered as part of layout during `reflow()`.  Parent containers will
    -- not attempt to @{_draw|draw} invisible widgets.
    -- @meta read/write
    -- @type boolean
    visible = rtk.Attribute{default=true, reflow=rtk.Widget.REFLOW_FULL},
    --- If true and the widget is interactive, it will not respond to user input and
    -- render itself in a way to indicate it's inert (usually with a lower opacity)
    -- (default `false`).
    -- @meta read/write
    -- @type boolean
    disabled = false,
    --- A ghost widget is one that takes up space in terms of layout and will
    -- have its geometry calculated in reflow() but is otherwise not drawn
    -- (default `false`).  This is similar to CSS's `visibility:hidden`.  Also,
    -- unlike `visible`=false, parent containers will invoke the draw method on
    -- ghost widgets, allowing them to implement a specific visual, but most of
    -- the time @{_draw|drawing} ghost widgets simply returns as a no-op.
    -- @meta read/write
    -- @type boolean
    ghost = rtk.Attribute{
        default=false,
        reflow=rtk.Widget.REFLOW_NONE,
    },
    --- A tooltip that pops up when the mouse hovers over the widget and remains still
    -- for `rtk.tooltip_delay` seconds.  The tooltip is styled according to
    -- @{rtk.themes.tooltip_font|the current theme}.  Explicit newlines are supported,
    -- and the tooltip will be wrapped if necessary to fit within the window.
    -- @meta read/write
    -- @type string
    tooltip = nil,
    --- The @{rtk.mouse.cursors|mouse cursor} to display when the mouse is within the
    -- widget's region (i.e. `mouseover` is true).  If nil, the default window cursor
    -- is used.
    -- @meta read/write
    -- @type cursorconst|nil
    cursor = nil,
    --- Alpha channel (opacity) level of this widget from 0.0 to 1.0 (default `1.0`)
    -- @meta read/write
    -- @type number
    alpha = rtk.Attribute{
        default=1.0,
        -- Force no reflow at all as this only affects drawing
        reflow=rtk.Widget.REFLOW_NONE,
    },
    --- Whether the widget is allowed to automatically receive focus in response to a
    -- mouse button pressed event (default `nil`).  When nil, autofocus will not occur
    -- unless you have attached a custom `onclick` handler to the widget, in which case
    -- it assume autofocus behavior in order to ensure the `onclick` handler fires.  If
    -- this attribute is explicitly false, then it will never autofocus regardless of
    -- whether there's a custom `onclick` handler.
    --
    -- @meta read/write
    -- @type boolean|nil
    autofocus = nil,
    --- The widget's background color (semantics vary by widget) or nil to have
    -- no background color (default `nil`)
    -- @meta read/write
    -- @type colortype|nil
    bg = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_NONE,
        calculate=function(self, attr, value, target, animation)
            if not value and animation then
                local parent = self.parent
                value = parent and parent.calc.bg or rtk.theme.bg
            end
            return value and {rtk.color.rgba(value)}
        end,
    },
    --- Shorthand to set the extended "hot zone" on all 4 sides of the widget at once
    -- (default 0).
    --
    -- The hot zone defines an extended area around the widget's natural boundary where
    -- mouseover events and clicks will be recognized, allowing you to extend the
    -- interactable area of a widget beyond what it visually depicts.  This can be useful
    -- when constructing a `rtk.Box` with spacing between cells, but you want the widgets
    -- occupying those cells to be clickable even within the inter-cell spacing.  Another
    -- use case is extending the area that small widgets can be clicked, improving the UX
    -- for touch devices.
    --
    -- The hot zone defines an extension relative to the widget's normal size, so, for
    -- example, a value of 5 will extend the clickable area 5 pixels beyond the widget's
    -- edge.
    --
    -- The format of this attribute is the same as `margin` and `padding`.
    --
    -- @note Supported units
    --   The "px" unit suffix is optional.  Pixels are assumed and no other unit is currently
    --   supported.  Other units may be supported in the future.
    -- @meta read/write
    -- @type number|table|string
    hotzone = rtk.Attribute{
        reflow=rtk.Widget.REFLOW_NONE,
        replaces={'thotzone', 'rhotzone', 'bhotzone', 'lhotzone'},
        get=function(self, attr, target)
            return {target.thotzone, target.rhotzone, target.bhotzone, target.lhotzone}
        end,
        calculate=function(self, attr, value, target)
            local t, r, b, l = rtk.Widget.static._calc_padding_or_margin(value)
            target.thotzone, target.rhotzone, target.bhotzone, target.lhotzone = t, r, b, l
            -- Unlike padding/margin where we're happy to blindly read the calculated
            -- values to get zero values in the default case, because these attrs are used
            -- by _is_mouse_over() which is invoked a *lot*, we optimize for the
            -- overwhelmingly common case where no hotzone is defined and skip the
            -- adjustment unless this flag is true.
            target._hotzone_set = true
            return {t, r, b, l}
        end
    },
    --- Top hot zone extension in pixels; if specified, overrides `hotzone` for the top
    -- edge (default 0). Must be numeric.
    -- @meta read/write
    -- @type number
    thotzone = rtk.Attribute{
        priority=true,
        reflow=rtk.Widget.REFLOW_NONE,
        calculate=function(self, attr, value, target)
            target._hotzone_set = true
            return value
        end,
    },
    --- Right hot zone extension in pixels; if specified, overrides `hotzone` for the right
    -- edge (default 0). Must be numeric.
    -- @meta read/write
    -- @type number
    rhotzone = rtk.Reference('thotzone'),
    --- Bottom hot zone extension in pixels; if specified, overrides `hotzone` for the bottom
    -- edge (default 0). Must be numeric.
    -- @meta read/write
    -- @type number
    bhotzone = rtk.Reference('thotzone'),
    --- Left hot zone extension in pixels; if specified, overrides `hotzone` for the left
    -- edge (default 0). Must be numeric.
    -- @meta read/write
    -- @type number
    lhotzone = rtk.Reference('thotzone'),

    --- If true, dragging this widget will cause the parent `rtk.Viewport` (if any)
    -- to scroll when the mouse is click-dragged against the viewport's edge
    -- (default `true`).
    -- @meta read/write
    -- @type boolean
    scroll_on_drag = true,
    --- If true, dragging this widget will cause the parent `rtk.Viewport` (if any)
    -- to display the scrollbar while the child is @{ondragstart|dragging}, even if
    -- the viewport's scrollbar mode would normally have it hidden.
    -- (default `true`)
    -- @meta read/write
    -- @type boolean
    show_scrollbar_on_drag = true,

    --- The amount of time in seconds a mouse button must be pressed and held over the
    -- widget before `onmousedown()` is fired, and before `ondragstart()` is eligible to
    -- be fired, where nil is adaptive based on the current value of `rtk.touchscroll`
    -- (default nil).
    --
    -- When `rtk.touchscroll` is false, `touch_activate_delay` is effectively 0 (i.e.
    -- `onmousedown()` is invoked immediately when the mouse button is pressed), however
    -- when touch scrolling is enabled the default is `rtk.touch_activate_delay`, except
    -- for `rtk.Viewport` where the default is 0ms in order to respond to touch-scrolling.
    --
    -- @meta read/write
    -- @type number
    touch_activate_delay = nil,

    --- True if the widget is ready for `_draw()`, and also ready to handle events (i.e.
    -- it is initialized and @{reflow|reflowed} and its geometry is fully known)
    -- @meta read-only
    -- @type boolean
    realized = false,
    --- True if the widget was drawn (which also implies both `realized` and `visible`)
    -- @meta read-only
    -- @type boolean
    drawn = false,
    --- The widget's closest ancestor viewport as of last reflow, which is nil if
    -- there is no containing viewport
    -- @meta read-only
    -- @type rtk.Viewport
    viewport = nil,
    --- The `rtk.Window` the widget belongs to as of the last reflow.
    -- It is safe to assume this is set in @{_draw} and event handlers.
    -- @meta read-only
    -- @type rtk.Window
    window = nil,
    --- Set to true if the mouse is within the widget's region (which is extended according
    -- to `hotzone`) and not occluded by a higher z-index widget, and false otherwise.
    -- @meta read-only
    -- @type boolean
    mouseover = false,
    --- Set to true if the mouse is within the widget's region (extended according to
    -- `hotzone`) *and* if `onmouseenter()` had returned a non-false value.  The semantics
    -- of "hovering" is that the widget is interactive and responsive to the mouse
    -- entering the widget's geometry, and so the return value of `onmouseenter()`
    -- indicates this interactivity.
    --
    -- Normally `hovering` implies `mouseover`, but one exception is that if the widget is
    -- being dragged and the mouse is outside the widget's current region, `hovering`
    -- could be true even while `mouseover` is false.
    -- @meta read-only
    -- @type boolean
    hovering = false,

    --- Other Attributes.
    --
    -- @section other

    --- If true, a translucent box will be drawn over the widget visually indicating the
    -- widget's geometry and padding, which is useful for debugging layout (default false).
    -- @meta read/write
    -- @type boolean
    debug = nil,
    --- An automatically generated identifier for the widget, which is guaranteed to be
    -- unique across the life of the program and will not be reused.  Widgets will get the
    -- same id assigned between program executions as long as the overall scene graph
    -- doesn't change.
    --
    -- The value currently happens to be a stringified numeric value, but this may change
    -- in the future and should not be assumed by applications.  Treat this value as an
    -- opaque string.
    --
    -- @meta read-only
    -- @type string
    id = nil,

    --- A name for this widget that can be accessed via the `refs` table (default nil).
    --
    -- Note that once the `ref` name is set it cannot be changed.
    -- @meta read/write-once
    -- @type string
    ref = nil,

    --- A table through which widget `ref` names can be dynamically accessed.
    --
    -- `ref` names are resolved based on fellow children (or grandchildren) of the
    -- widget's parent container(s).  For example, given `self.refs.foo`, whichever child
    -- (however nested) of the `parent` container has the `ref` name `foo` will be
    -- returned.  If there's no match, the parent's parent is consulted, and so on up
    -- the widget hierarchy.
    --
    -- @code
    --    local box = rtk.HBox{
    --        valign='center', spacing=10,
    --        -- Use the ref name 'label' for later access
    --        rtk.Text{w=40, ref='label'},
    --        rtk.Slider{
    --            onchange=function(self)
    --                -- Fetch the label via its ref name in order to update it.
    --                self.refs.label:attr('text', self.value)
    --            end
    --        },
    --    }
    --    window:add(box)
    --
    -- Ref names don't need to be globally unique: the context of which widget's `refs`
    -- table is being accessed dicates how the name is resolved.  If you try to access an
    -- ambiguous ref name -- that is, the nearest parent container which knows about the
    -- ref name actually has multiple child descendents with the same ref name -- you
    -- can't be sure which widget you'll get (and in fact you may not get any at all).
    -- The specific behavior in this case is undefined. So just make sure that when you
    -- access a ref name via a widget's `refs` table, there is a level at or above the
    -- widget where there is only one such ref name.
    --
    -- Resolving references generally requires both the widget whose `refs` table is being
    -- accessed *and* the widget being looked up to be nested somewhere under the same
    -- container.  It *is* possible to resolve an unparented reference as there is a
    -- last-ditch global lookup table that's consulted, but in this case global uniqueness
    -- of the `ref` name is required.
    --
    -- Because accessing fields on this table involves an upward traversal of the widget's
    -- parent hierarchy, there is a cost in accessing distant refs compared to standard
    -- Lua table accesses. Consequently, if repeatedly accessing a distant ref, you may
    -- want to assign it to a temporary local variable first.
    --
    -- Refs are weak, which means that in order to access a widget by its `ref` name there
    -- must be some other reference to the widget object in Lua.  Any widget added to a
    -- container widget is covered (provided a reference to the container itself exists,
    -- of course). Once the Lua garbage collector frees a widget, it can no longer be
    -- accessed by its `ref` name.
    --
    -- @meta read-only
    -- @type table
    refs = nil,
}

-- Metatable for rtk.Widget.refs, which proxies to rtk.Widget:_ref().
local _refs_metatable = {
    __mode='v',
    __index=function(table, key)
        return table.__self:_ref(table, key)
    end,
    __newindex=function (table, key, value)
        rawset(table, key, value)
        table.__empty=false
    end
}

-- Metatable for rtk.Widget.calc, which proxies to rtk.Widget:_calc()
local _calc_metatable = {
    __call=function(table, _, attr, instant)
        return table.__self:_calc(attr, instant)
    end
}

--- Public Methods.
--
-- These methods are intended to be used to control rtk's built-in widgets, in contrast to
-- the @{subclassapi|subclass API} which is used to implement custom widgets.
--
-- @section methods

-- The last unique id assigned to a widget object
rtk.Widget.static.last_index = 0

function rtk.Widget:__allocate()
    self.__id = tostring(rtk.Widget.static.last_index)
    rtk.Widget.static.last_index = rtk.Widget.static.last_index + 1
end

-- Not documenting widget constructor as it's not intended to be invoked
-- directly.  Use subclasses instead.
function rtk.Widget:initialize(attrs,...)
    -- Create refs table, which proxies to _ref() when accessing an element not in
    -- the refs table, and which sets __empty to false when something is added.
    -- The __empty flag is checked by container implementations in order to avoid
    -- upward propagation of an empty table when we are parented.
    self.refs = setmetatable({__empty=true, __self=self}, _refs_metatable)
    self.calc = setmetatable({__self=self, border_uniform=true}, _calc_metatable)
    local clsattrs = self.class.attributes
    local tables = {clsattrs.defaults, ...}
    local merged = {}
    for n = 1, #tables do
        for k, v in pairs(tables[n]) do
            merged[k] = v
        end
    end
    if attrs then
        -- Loop through user-provided attributes and if there are any shorthand attributes
        -- used with 'replaces' defined, remove those replaced attributes from the
        -- defaults before we merge user-supplied attributes.
        --
        -- What this means is that widget implementations can *not* mix shorthand and
        -- their replaced attributes in the same class hierarchy.  For performance
        -- reasons, handling this case only applies to user-provided attributes.
        for k, v in pairs(attrs) do
            local meta = clsattrs[k] or rtk.Attribute.NIL
            -- Handle positional attributes and other aliases, including into the merged
            -- attribute table based on the alias name.
            local attr = meta.alias
            if attr then
                merged[attr] = v
            end
            local replaces = meta.replaces
            if replaces then
                for n = 1, #replaces do
                    merged[replaces[n]] = nil
                end
            end
            -- Merge non-positional user-applied attributes on top of the defaults.
            if not tonumber(k) then
                merged[k] = v
            end
        end
        if attrs.ref then
            rtk._refs[attrs.ref] = self
            self.refs[attrs.ref] = self
        end
    end

    -- Do this after setting attributes in case the user gets cheeky and adds
    -- an id attribute, which will break so many things.
    self.id = self.__id
    self:_setattrs(merged)

    -- These fields are internal only, not part of the API, and so not
    -- documented above.
    --
    -- Time of last mouse down time (for measuring double clicks)
    self._last_mousedown_time = 0
    -- rtk.scale.value as of previous reflow.  Each _reflow() method interested in
    -- detecting scale changes needs to set this field to the uiscale parameter passed
    -- to _reflow().
    self._last_reflow_scale = nil
end

function rtk.Widget:__tostring()
    local clsname = self.class.name:gsub('rtk.', '')
    if not self.calc then
        -- allocate() was explicitly called() and we're stringifying
        -- before initialize().
        return string.format('<%s (uninitialized)>', clsname)
    end
    local info = self:__tostring_info()
    info = info and string.format('<%s>', info) or ''
    return string.format('%s%s[%s] (%s,%s %sx%s)',
        clsname, info, self.id,
        self.calc.x, self.calc.y, self.calc.w, self.calc.h
    )
end

function rtk.Widget:__tostring_info() end

-- Initial processing of all attributes on instantiation.
function rtk.Widget:_setattrs(attrs)
    if not attrs then
        return
    end
    local clsattrs = self.class.attributes
    local priority = {}
    local calc = self.calc
    -- First exclude priority attributes.
    for k, v in pairs(attrs) do
        -- Accessing class attributes table directly improves performance only slightly,
        -- but it's just enough that it's worth bypassing attributes.get().
        local meta = clsattrs[k]
        if meta and not meta.priority then
            -- We can only invoke the default value function for non priority attributes,
            -- as default funcs for priority attributes may depend on non-priority ones.
            if v == rtk.Attribute.FUNCTION then
                v = clsattrs[k].default_func(self, k)
            elseif v == rtk.Attribute.NIL then
                v = nil
            end
            local calculated = self:_calc_attr(k, v, nil, meta)
            self:_set_calc_attr(k, v, calculated, calc, meta)
        else
            priority[#priority+1] = k
        end
        self[k] = v
    end
    if #priority == 0 then
        -- No priority attributes to override those set above.
        return
    end
    -- Now pass over all priority attributes.
    for _, k in ipairs(priority) do
        local v = self[k]
        if v == rtk.Attribute.FUNCTION then
            v = clsattrs[k].default_func(self, k)
            self[k] = v
        end
        if v ~= nil then
            if v == rtk.Attribute.NIL then
                v = nil
                self[k] = nil
            end
            local calculated = self:_calc_attr(k, v)
            self:_set_calc_attr(k, v, calculated, calc)
        end
    end
end

-- Called (via metatable __index method) when a ref name is accessed that doesn't already
-- exist in the refs table.  If it exists, it's either because we're a container with a
-- child with that ref name, or it's our own ref name.  In either case, this method won't
-- be invoked.
--
-- So this is only invoked when we need to search up the widget hierarchy.
function rtk.Widget:_ref(table, key)
    if self.parent then
        return self.parent.refs[key]
    else
        -- We either aren't parented or we're a root widget, so look in the global refs
        -- table as a last resort. This allows accessing unparented widgets by ref,
        -- although collisions are going to be more commonplace.
        return rtk._refs[key]
    end
end

function rtk.Widget:_get_debug_color()
    if not self.debug_color then
        -- Generate a debug color based on the widget id using a simple xorshift PRNG.
        local x = self.id:hash() * 100
        x = x ~ (x << 13)
        x = x ~ (x >> 7)
        x = x ~ (x << 17)
        -- Take it as a packed 24-bit RGB value
        local color = table.pack(rtk.color.rgba(x % 16777216))
        -- To make sure it's relatively visible for both dark and light themes, adjust
        -- luma if it's below 0.2 or above 0.8.
        local luma = rtk.color.luma(color)
        if luma < 0.2 then
            color = table.pack(rtk.color.mod(color, 1, 1, 2.5))
        elseif luma > 0.8 then
            color = table.pack(rtk.color.mod(color, 1, 1, 0.75))
        end
        self.debug_color = color
    end
    return self.debug_color
end

function rtk.Widget:_draw_debug_box(offx, offy, event)
    local calc = self.calc
    if not self.debug and not rtk.debug or not calc.w then
        return false
    end
    if not self.debug and event.debug ~= self then
        return false
    end
    local color = self:_get_debug_color()
    gfx.set(color[1], color[2], color[3], 0.2)
    local x = calc.x + offx
    local y = calc.y + offy
    gfx.rect(x, y, calc.w, calc.h, 1)
    gfx.set(color[1], color[2], color[3], 0.4)
    gfx.rect(x, y, calc.w, calc.h, 0)
    local tp, rp, bp, lp = self:_get_padding_and_border()
    if tp > 0 or rp > 0 or bp > 0 or lp > 0 then
        gfx.set(color[1], color[2], color[3], 0.8)
        gfx.rect(x + lp, y + tp, calc.w - lp - rp, calc.h - tp - bp, 0)
    end
    return true
end

function rtk.Widget:_draw_debug_info(event)
    local calc = self.calc
    local parts = {
        { 15, "#6e2e2e", tostring(self.class.name:gsub("rtk.", "")) },
        { 15, "#378b48", string.format('#%s', self.id) },
        { 17, "#cccccc", " | " },
        { 15, "#555555", string.format("%.1f", calc.x) },
        { 15,  "#777777", " , " },
        { 15, "#555555", string.format("%.1f", calc.y) },
        { 17, "#cccccc", " | " },
        { 15, "#555555", string.format("%.1f", calc.w) },
        { 13,  "#777777", "  x  " },
        { 15, "#555555", string.format("%.1f", calc.h) },
    }
    local sizes = {}
    local bw, bh = 0, 0
    for n, part in ipairs(parts) do
        local sz, _, str = table.unpack(part)
        gfx.setfont(1, rtk.theme.default_font, sz)
        local w, h = gfx.measurestr(str)
        sizes[n] = {w, h}
        bw = bw + w
        bh = math.max(bh, h)
    end

    -- Padding
    bw = bw + 20
    bh = bh + 10
    -- Calculate client coordinates
    local x = self.clientx
    local y = self.clienty
    if x + bw > self.window.calc.w then
        x = self.window.calc.w - bw
    elseif x < 0 then
        x = 0
    end
    if y - bh >= 0 then
        y = math.max(0, y - bh)
    else
        y = math.min(y + calc.h, self.window.calc.h - bh)
    end

    rtk.color.set('#ffffff')
    gfx.rect(x, y, bw, bh, 1)
    rtk.color.set('#777777')
    gfx.rect(x, y, bw, bh, 0)

    gfx.x = x + 10
    for n, part in ipairs(parts) do
        local sz, color, str = table.unpack(part)
        rtk.color.set(color)
        gfx.y = y + (bh - sizes[n][2]) / 2
        gfx.setfont(1, rtk.theme.default_font, sz)
        gfx.drawstr(str)
    end
end

--- Set an attribute on the widget to the given value.
--
-- This method is the proper way to dynamically modify any of the widget's fields to
-- ensure they are properly reflected. In most cases the value is immediately calculated
-- and the calculated form is accessible via the `calc()` method. (The exception is attributes
-- that depend on parent geometry, in which case the value will not be calculated until
-- next reflow.)
--
-- Setting a different value will cause the `onattr` handler to fire, in addition
-- to any other widget-specific handlers if applicable (for example
-- @{rtk.OptionMenu.onchange|onchange} if setting the `selected` attribute on a
-- `rtk.OptionMenu`).  However if the given `value` is the same as the current value,
-- this will be a no-op unless `trigger` is true, in which case all the event handlers
-- associated with `attr` are forced and will fire whether or not the value changed.
--
-- Meanwhile, setting `trigger` to false will suppress event handlers (except for
-- `onattr` which always fires if the value has changed), which can be useful if
-- setting the attribute in another `on*` handler to prevent circular calls.
--
-- @tparam string attr the attribute name
-- @tparam any value the target value for the attribute.  A special value `rtk.Attribute.DEFAULT`
--   restores the attribute to rtk's built-in default.
-- @tparam bool|nil trigger if false, event handlers that would normally fire
--   will be suppressed even if the value changed (except for `onattr` which is *always* fired
--   if the value changes); conversely, if true, all handlers will fire even if the value
--   hasn't changed.  If nil, the default behavior will be used, which is typically that
--   handlers will only fire if the value changed (unless indicated otherwise by the event
--   handler's documentation).
-- @tparam reflowconst|nil reflow controls how the widget should be reflowed after the
--   attribute is set.  If nil, then `REFLOW_DEFAULT` is used, where either a partial reflow
--   or a full reflow will be performed, depending on what is appropriate for `attr`.  Most of
--   the time you want to leave this as nil, but if you're changing an attribute that
--   normally affects geometry but, due to external constraints the widget may not know
--   about, the geometry actually can't change as a result of modifying this attribute,
--   passing false here will nontrivially improve performance as the costly reflow can be
--   avoided.
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:attr(attr, value, trigger, reflow)
    return self:_attr(attr, value, trigger, reflow, nil, false)
end

-- XXX: internal function for now while reactives are fleshed out
--
-- calculated forces direct setting of the calculated value, bypassing the attributes
-- calculate() function.  This can be used to forcefully sync a value that might otherwise
-- be out of bounds, for example, or because the calculated value is already known and
-- there's no need to recompute it.
function rtk.Widget:sync(attr, value, calculated, trigger, reflow)
    return self:_attr(attr, value, trigger, reflow, calculated, true)
end

function rtk.Widget:_attr(attr, value, trigger, reflow, calculated, sync)
    local meta = self.class.attributes.get(attr)
    if value == rtk.Attribute.DEFAULT then
        if meta.default == rtk.Attribute.FUNCTION then
            value = meta.default_func(self, attr)
        else
            value = meta.default
        end
    elseif value == rtk.Attribute.NIL then
        value = nil
    end
    local oldval = self[attr]
    local oldcalc = self.calc[attr]
    -- If the attribute we're setting is a shorthand attribute that replaces
    -- other attributes (e.g. padding), we force invocation of _handle_attr()
    -- even if the shorthand value hasn't changed, because we don't know here if
    -- changing the shorthand value will end up modifying a replaced attribute.
    local replaces = meta.replaces
    if replaces then
        for i = 1, #replaces do
            self[replaces[i]] = nil
        end
    end
    if calculated == nil then
        calculated = self:_calc_attr(attr, value, nil, meta)
    end
    -- Use rawequal here to ensure we detect replacement of a reactive when the
    -- underlying value is the same between old and new.
    if not rawequal(value, oldval) or calculated ~= oldcalc or replaces or trigger then
        self[attr] = value
        self:_set_calc_attr(attr, value, calculated, self.calc, meta)
        self:_handle_attr(attr, calculated, oldcalc, trigger == nil or trigger, reflow, sync)
    end
    -- Return self to allow chaining multiple attributes
    return self
end

-- Returns the calculated version of the attribute value.
--
-- Subclasses generally don't need to implement this unless they're doing
-- something fairly custom.  Use rtk.Attribute calculate instead.
function rtk.Widget:_calc_attr(attr, value, target, meta, namespace, widget)
    target = target or self.calc
    meta = meta or self.class.attributes.get(attr)
    if meta.type then
        value = meta.type(value)
    end
    local calculate = meta.calculate
    if calculate then
        local tp = type(calculate)
        if tp == 'table' then
            if value == nil then
                value = calculate[rtk.Attribute.NIL]
            else
                value = calculate[value] or value
            end
        elseif tp == 'function' then
            if value == rtk.Attribute.NIL then
                value = nil
            end
            value = calculate(self, attr, value, target)
        end
    end
    return value
end

function rtk.Widget:_set_calc_attr(attr, value, calculated, target, meta)
    meta = meta or self.class.attributes.get(attr)
    if meta.set then
       meta.set(self, attr, value, calculated, target)
    else
        self.calc[attr] = calculated
    end
end

--- Returns the calculated value of the given attribute.
--
-- @rename calc
--
-- Calculated attributes have been parsed and transformed into efficient values that are
-- used for internal operations.
--
-- @code
--    local b = rtk.Button{"Don't Panic", halign='right', padding='10px 30px'}
--    log.info('halign=%s is calculated as %s', b.halign, b:calc('halign'))
--    log.info('padding=%s is calculated as %s', b.padding, table.tostring(b:calc('padding')))
--    b:attr('color', 'indigo')
--    log.info('color=%s is calculated as %s', b.color, table.tostring(b:calc('color')))
--
-- The above example outputs something along these lines:
--
-- ```
-- 17:32:30.292 [INFO]  halign=right is calculated as 2
-- 17:32:30.292 [INFO]  padding=10px 30px is calculated as {10,30,10,30}
-- 17:32:30.292 [INFO]  color=indigo is calculated as {0.29411764705882,0.0,0.50980392156863,1}
-- ```
--
-- @warning Calculated Geometry
--   In the example above, the calculated attributes were all available immediately after
--   setting, but most attributes related to @{geometry} first require a `reflow()` before
--   they're available.  Consider:
--
--     @code
--        local text = rtk.Text{"They've gone to plaid!", wrap=true}
--        -- What should this output?
--        log.info('calculated width is %s', text:calc('w'))
--
--   Here the size of the `rtk.Text` widget depends on its bounding box, but it hasn't
--   been added to a container yet, and even if it were, that container may not yet have
--   been added to its own container yet, and so on, until this `rtk.Text` widget ultimately
--   descends from `rtk.Window`.  So widget geometry is not calculated until reflow has
--   occurred.  It is always safe to access in @{ondraw|drawing handlers}, however.
--
-- More on attributes @{widget.attributes|here}.
--
-- Note that `calc` can also be accessed as a table.  For example, instead of
-- `widget:calc('attr')` you can access `widget.calc.attr`.  This means of access is
-- much faster as it bypasses the abstractions provided when invoking as a method,
-- but is also more limited: @{rtk.Attribute.get|attribute getters} are not taken into
-- account, and the table value is *always* the current point-in-time value of an
-- attribute being animated.
--
-- Due to the significant performance benefit which can be useful in certain cases, table
-- access is a supported API, but be aware of its limitations.  When in doubt, invoke
-- `calc()` as a method.
--
-- @tparam string attr the name of the attribute whose calculated value to return
-- @tparam bool|nil instant if true, the point-in-time calculated value of the attribute
--   is returned even if it's in the middle of an animation.  False (or nil) will return
--   the ultimate target value of the attribute if it's animating.
-- @treturn any the target value of the attribute if animating, or current value otherwise
function rtk.Widget:_calc(attr, instant)
    if not instant then
        local anim = self:get_animation(attr)
        if anim and anim.dst then
            return anim.dst
        end
    end
    local meta = self.class.attributes.get(attr)
    if meta.get then
        return meta.get(self, attr, self.calc)
    else
        return self.calc[attr]
    end
end

--- Moves the widget to explicit coordinates relative to its parent.
--
-- This is just a shorthand for calling `attr()` on the `x` and `y` attributes.
--
-- @tparam number x the x position relative to parent in pixels
-- @tparam number y the y position relative to parent in pixels
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:move(x, y)
    self:attr('x', x)
    self:attr('y', y)
    return self
end

--- Resizes the widget.
--
-- This is just a shorthand for calling `attr()` on the `w` and `h` attributes,
-- so fractional values (0.0 to 1.0) and negative values can be used for
-- relative sizing, as well as nil to have the widget pick its own size.
--
-- @tparam number w the width of the widget
-- @tparam number h the height of the widget
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:resize(w, h)
    self:attr('w', w)
    self:attr('h', h)
    return self
end

-- Returns the widget's position relative to its viewport (or the root widget if there is
-- no viewport).
--
-- This is different than self.offy + self.calc.y because offy is only set if the
-- widget is drawn.  If the widget's parent container isn't visible (scrolled outside the
-- viewport say) then that approach doesn't work.  This function takes the more expensive
-- but reliable route of crawling up the widget hierarchy.  Consequently, this should not
-- be called frequently.
function rtk.Widget:_get_relative_pos_to_viewport()
    local x, y = 0, 0
    local widget = self
    while widget do
        x = x + widget.calc.x
        y = y + widget.calc.y
        if widget.viewport and widget.viewport == widget.parent then
            break
        end
        widget = widget.parent
    end
    return x, y
end

--- Ensures the widget is fully visible within its `rtk.Viewport`.
--
-- If the widget is not placed within a viewport then this function is a
-- no-op.
--
-- The margin argument ensure the widget is visible plus the supplied margin as a buffer,
-- depending which direction the viewport is being scrolled.
--
--  @example
--    -- Allow scrolling in any directions with 0 margin.
--    widget:scrolltoview()
--
--    -- Allow scrolling in any direction with a 15 pixel margin if scrolling
--    -- vertically, and a 10 pixel margin if scrolling horizontally.
--    widget:scrolltoview{15, 10}
--
--    -- Only allow vertical scrolling with a 50 pixel top margin if scrolling
--    -- up, and a 20 pixel bottom margin if scrolling down.
--    widget:scrolltoview({50, 0, 20}, false)
--
-- @tparam number|table|string|nil margin amount of space to leave on the side of the
--   widget opposite the direction being scrolled, which takes the same format as the
--   `padding` attribute.  If nil, 0 margin is assumed for all sides.
-- @tparam bool|nil allowh if false, horizontal scrolling will be prevented, otherwise
--   any other value allows it
-- @tparam bool|nil allowv if false, vertical scrolling will be prevented, otherwise any
--   other value allows it
-- @tparam boolean|nil smooth true to force smooth scrolling even if the containing viewport's
--   @{rtk.Viewport.smoothscroll|smoothscroll attribute} is false; false to force-disable
--   smooth scrolling even if `rtk.Viewport.smoothscroll` is true, or nil to use whatever
--   smooth scrolling behavior is default for the viewport (or globally via `rtk.smoothscroll`).
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:scrolltoview(margin, allowh, allowv, smooth)
    if not self.visible or not self.box or not self.viewport then
        -- Not visible or not reflowed yet, or the widget has no viewport to scroll.
        return self
    end
    local calc = self.calc
    local vcalc = self.viewport.calc
    local tmargin, rmargin, bmargin, lmargin = rtk.Widget.static._calc_padding_or_margin(margin or 0)
    local left, top = nil, nil
    local absx, absy = self:_get_relative_pos_to_viewport()
    if allowh ~= false then
        if absx - lmargin < self.viewport.scroll_left then
            -- Scroll left
            left = absx - lmargin
        elseif absx + calc.w + rmargin > self.viewport.scroll_left + vcalc.w then
            -- Scroll right
            left = absx + calc.w + rmargin - vcalc.w
        end
    end
    if allowv ~= false then
        if absy - tmargin < self.viewport.scroll_top then
            -- Scroll up
            top = absy - tmargin
        elseif absy + calc.h + bmargin > self.viewport.scroll_top + vcalc.h then
            -- Scroll down
            top = absy + calc.h + bmargin - vcalc.h
        end
    end
    self.viewport:scrollto(left, top, smooth)
    return self
end

--- Hides the widget, removing it from the layout flow and not drawing it.
--
-- This is mainly a shorthand for calling `attr()` on the `visible` attribute
-- but includes a small optimization, which makes it preferred for performance
-- and readability.
--
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:hide()
    -- Tiny optimization: checking here avoids the call to _calc_attr if unchanged.
    if self.calc.visible ~= false then
        return self:attr('visible', false)
    end
    return self
end

--- Shows the widget after it was hidden.
--
-- This is mainly a shorthand for calling `attr()` on the `visible` attribute
-- but includes a small optimization, which makes it preferred for performance
-- and readability.
--
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:show()
    -- Tiny optimization: checking here avoids the call to _calc_attr if unchanged.
    if self.calc.visible ~= true then
        return self:attr('visible', true)
    end
    return self
end

--- Toggles the widget's visibility.
--
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:toggle()
    if self.calc.visible == true then
        return self:hide()
    else
        return self:show()
    end
end

--- Check if the widget currently has focus.
--
-- This simply just checks is this widget is the same as `rtk.focused`.  In rtk, exactly
-- one (or zero) widgets can grab focus.  A container that holds a focused widget is not
-- itself considered focused, but depending on the type of event, it may invoke event
-- handlers for certain events when one of its children has focus.
--
-- A widget obtains focus when it is `autofocus` and the mouse clicks on it (and the
-- widget is using the default `onmousedown()` handler), or if `focus()` is explicitly
-- called.
--
-- @tparam rtk.Event|nil event if specified, is the event which will be dispatched
--   to event handlers if this functions returns true.  This is ignored by rtk.Widget,
--   but subclasses can override.  For example, `rtk.Container` overrides this and
--   considers itself focused for `rtk.Event.KEY` events when one of its children
--   has focus.
-- @treturn bool true if focused, false otherwise
function rtk.Widget:focused(event)
    return rtk.focused == self
end

--- Makes the widget focused.
--
-- The semantics of a focused widget varies by subclass.  For example, with
-- `rtk.Entry` it means that the widget will render an accented border, the cursor
-- will blink, and keyboard events will be captured by the widget.
--
-- If another widget currently has focus, `blur()` will be called on it.  If that
-- widget's `onblur()` handler returns false, it will block the focus, in which
-- case this function will return false.  This condition is fairly rare but it
-- can occur, for example, when the currently-focused widget is modal.
--
-- If the request to blur the currently-focused widget was successful (or there
-- wasn't any focused widget to begin with), then our `onfocus()` handler is
-- called to determine if focus should be accepted.  If that returns anything
-- other than false, focus is accepted.  The default implementation is to accept
-- the focus.
--
-- Note that the `autofocus` attribute doesn't come into play here.  That
-- attribute controls whether focus occurs on a mouse down, but if `focus()` is
-- explicitly called on a widget, the only deciding factor is the return value
-- from the `onfocus()` handler.
--
-- @tparam rtk.Event|nil event when `focus()` is called as a result of some
--   event (usually a mouse click) then the event should be included here so
--   it can be passed along to the `onfocus()` handler. But when no event was
--   involved, this argument can be excluded.
-- @treturn bool true if the focus succeeded, false otherwise
function rtk.Widget:focus(event)
    if rtk.focused and rtk.focused ~= self then
        -- Ask existing focused widget to blur.  It may refuse, in which case
        -- rtk.focused not be set to nil.
        rtk.focused:blur(event, self)
    end
    if rtk.focused == nil and self:_handle_focus(event) ~= false then
        rtk.focused = self
        if self.parent then
            self.parent:_set_focused_child(self)
        end
        self:queue_draw()
        return true
    end
    return false
end

--- Removes focus from the widget.
--
-- Our `onblur()` handler is first called to determine if focus should be
-- relinquished.  If that returns anything other than false then focus is
-- surrendered.
--
-- @tparam rtk.Event|nil event when `blur()` is called as a result of some
--   event, then the event should be included here so it can be passed along
--   to the `onblur()` handler.  When no event was involved, this argument can
--   be excluded
-- @tparam rtk.Widget|nil other when we are being asked to be blurred because
--   some other widget wants focus, then this parameter is set to that other
--   widget
-- @treturn bool true if focus was relinquished and the blur succeeded, false
--   otherwise
function rtk.Widget:blur(event, other)
    if not self:focused(event) then
        -- Widget wasn't focused
        return true
    end
    if self:_handle_blur(event, other) ~= false then
        rtk.focused = nil
        if self.parent then
            self.parent:_set_focused_child(nil)
        end
        self:queue_draw()
        return true
    end
    -- Widget is focused but blur was refused by the onblur handler.
    return false
end


--- Begin an animation against one of the widget's attributes.
--
-- All numeric attributes can be animated, as well as tables containing numeric values.
-- This means that colors can be animated, as colors are @{calc|calculated} as their
-- 4-element rgba values.
--
-- All other attributes are animatable only where indicated.
--
-- Multiple attributes can be animated in parallel using successive calls to `animate()`.
--
-- The argument is a key/value table that describes the animation.  Valid
-- fields are as follows, with mandatory fields in bold:
--
--   * **attr** (string): the name of the attribute to animate.  This can optionally
--     be passed as the first positional argument without the need to specify the
--     `attr` field.
--   * dst (number|table|nil): the destination value to animate toward. If nil,
--     0 is usually assumed, but if attr is `w` or `h` then the widget's
--     intrinsic size will be calculated and animated toward.  (This also
--     supports @{w|fractional values}.)
--   * src (number|table): the starting value of the attribute.  Default is the
--     current attribute's calculated value as the starting value.
--   * easing (string): the name of an @{rtk.easing|easing function} that controls
--     the contour of the animation.
--   * duration (number): the amount of time in seconds the animation should
--     occur over.  Fractional values are fine.  Default is `0.5`.  Frame timing
--     isn't guaranteed so the animation not complete in *exactly* this amount,
--     but the margin of error is typically below 50ms.
--   * reflow (`reflowconst`): by default, a full window `reflow()` will occur if attr
--     is one that could affect the geometry of the widget, and a partial reflow
--     will be done for all other attributes.  Specifying `rtk.Widget.REFLOW_FULL` here will
--     force a full reflow at each step of the animation; conversely, specifying
--     `rtk.Widget.REFLOW_PARTIAL` will force a partial reflow even if the attribute is one
--     that would normally warrant a full reflow.
--
-- This function returns an `rtk.Future` so you can attach callbacks to be invoked when
-- the animation is finished (via @{rtk.Future:done|done()}) or when it's cancelled
-- (via @{rtk.Future:cancelled|cancelled()}).
--
-- You can also cancel a running animation by calling @{rtk.Future:cancel|cancel()} on
-- the `rtk.Future`.
--
-- If there is an existing animation for the given attribute, it will be
-- replaced only if the `dst` value has changed, in which case the animation
-- will be restarted from its current mid-animation value toward the new `dst`
-- value.  If the `dst` is the same, then the in-flight animation will continue
-- to run without interruption.
--
-- During an animation, the attribute's calculated value is updated to reflect each
-- individual step of the animation, and this can be fetched by calling `calc()` with the
-- `instant` argument set to true.  However, the exterior value -- that is, the direct
-- fields of the widget object, such as `button.color` or `box.alpha` -- are not updated
-- during the animation.  Exterior attributes are updated either at the start of end of the
-- animation, depending on what makes sense in the context of the attribute.
--
-- @code
--   -- This example causes the button width to animate back and forth between
--   -- 300px and its intrinsic size with different speeds each time it's clicked.
--   -- For good measure, we also animate the opacity via the alpha attribute.
--   button.onclick = function()
--      if not button.w then
--          -- Use a bouncing effect for the width animation
--          button:animate{'w', dst=300, duration=1, easing='out-bounce'}
--          button:animate{'alpha', dst=0.5, duration=1}
--      else
--          button:animate{'w', dst=nil, duration=0.25, easing='out-bounce'}
--          button:animate{'alpha', dst=1, duration=0.25}
--              :done(function()
--                  log.info('widget opacity is returned to normal')
--              end)
--      end
--   end
--
-- @tparam table kwargs the table describing the animation as above
-- @treturn rtk.Future a Future object tracking the state of the asynchronous animation
-- @see rtk.queue_animation
function rtk.Widget:animate(kwargs)
    assert(kwargs and (kwargs.attr or #kwargs > 0), 'missing animation arguments')
    local calc = self.calc
    local attr = kwargs.attr or kwargs[1]
    local meta = self.class.attributes.get(attr)
    local key = string.format('%s.%s', self.id, attr)
    -- Current animation (if any)
    local curanim = rtk._animations[key]
    -- Current destination value (if in-flight animation) or current calculated value
    -- for this attribute.
    local curdst = curanim and curanim.dst or self.calc[attr]

    -- Fast path: when we already know the new dst value at this point, don't queue animation
    -- if there is already an active animation with this same dst value.
    if curdst == kwargs.dst and not meta.calculate and attr ~= 'w' and attr ~= 'h' then
        if curanim then
            return curanim.future
        elseif not kwargs.src then
            -- Unless there's an explicit src value, return a pre-resolved Future
            -- to maintain a consistent API.
            return rtk.Future():resolve(self)
        end
    end

    -- Assign in case attr was passed as a positional argument.
    kwargs.attr = attr
    kwargs.key = key
    kwargs.widget = self
    kwargs.attrmeta = meta
    kwargs.stepfunc = (meta.animate and meta.animate ~= rtk.Attribute.NIL) and meta.animate
    kwargs.calculate = meta.calculate
    -- Exterior values are normally only updated at the end of the animation.  In some
    -- cases, such as x/y/w/h, where the exterior value is used during reflow instead of
    -- the calculated value (because the act of calculating geometry _is_ a reflow),
    -- we need the animation step function to also sync the exterior value.
    kwargs.sync_exterior_value = meta.reflow_uses_exterior_value
    if kwargs.dst == rtk.Attribute.DEFAULT then
        if meta.default == rtk.Attribute.FUNCTION then
            kwargs.dst = meta.default_func(self, attr)
        else
            kwargs.dst = meta.default
        end
    end

    -- Flags to track whether src and dst have been converted to calculated variants.
    local calcsrc, calcdst
    -- Set the done value to the supplied destination value.  We may override
    -- the dst val later if it's width/height set to nil, in which case we want
    -- to ensure that once the animation is complete, the attribute will be
    -- reset from the explicit calculated value back to nil, so it will continue
    -- to reflow with its intrinsic size after the animation is done.
    --
    -- Because rtk.queue_animation() will set doneval to dst if it's nil, and
    -- for width/height we will calculate dst, convert nil to rtk.Attribute.DEFAULT
    -- which will be passed to attr() when the animation finishes.
    local doneval = kwargs.dst or rtk.Attribute.DEFAULT
    if attr == 'w' or attr == 'h' then
        -- If src value is nil or fractional and we're animating one of the
        -- dimensions, set the animation src to the current calculated size.
        if (not kwargs.src or kwargs.src == rtk.Attribute.NIL) or (kwargs.src <= 1.0 and kwargs.src >= 0) then
            -- Source attribute was nil or relative.  Use the calculated value,
            -- interpreting src as a relative value (if not nil).
            if kwargs.src == rtk.Attribute.NIL then
                kwargs.src = nil
            end
            kwargs.src = (calc[attr] or 0) * (kwargs.src or 1)
            calcsrc = true
        end
        if (not kwargs.dst or kwargs.dst == rtk.Attribute.NIL) or (kwargs.dst <= 1.0 and kwargs.dst > 0) then
            if kwargs.dst == rtk.Attribute.NIL then
                kwargs.dst = nil
            end
            -- Another special case.  If we want to animate width or height toward nil
            -- (intrinsic size) or value <= 1.0 (size relative to parent), force a full reflow
            -- to determine new calculated geometry and then animate toward that.
            --
            -- Remember current exterior and calculated values so they can be restored.
            local current = self[attr]
            local current_calc = calc[attr]
            -- Set the attribute to nil and force full reflow on our window to calculate
            -- the new geometry in order to determine correct target value.
            self[attr] = kwargs.dst
            -- Also generate the calculated variant in case the widget's reflow function
            -- depends upon previous calculated value (as can happen with rtk.Window, for
            -- example).
            calc[attr] = meta.calculate and meta.calculate(self, attr, kwargs.dst, {}, true) or kwargs.dst
            local window = self:_slow_get_window()
            if not window then
                -- Trying to animate the geometry of a widget that's not parented
                -- up to a window.  Treat this as a no-op by returning a pre-resolved
                -- Future.
                return rtk.Future():resolve(self)
            end
            window:reflow(rtk.Widget.REFLOW_FULL)
            kwargs.dst = calc[attr] or 0
            calcdst = true
            -- Now restore original vales for this dimension.  Unfortunately we need to do
            -- another full reflow, because all the other widgets in the scene would also
            -- have been reflowed around our new target geometry.
            self[attr] = current
            calc[attr] = current_calc
            window:reflow(rtk.Widget.REFLOW_FULL)
        end
    end
    if not calcdst and meta.calculate then
        -- We pass an empty table here in case the attribute is a shorthand attr (like
        -- padding) that injects other calculated attributes (like tpadding, etc.)  We
        -- are just fishing for the calculated dst value, we don't want to actually
        -- change our current calculated attributes.
        kwargs.dst = meta.calculate(self, attr, kwargs.dst, {}, true)
        -- Update doneval now that we've got a calculated value.
        doneval = kwargs.dst or rtk.Attribute.DEFAULT
    end
    -- As earlier, but the slow path: now that we've calculated the dst value,
    -- avoid scheduling a new animation with the same dst.
    if curdst == kwargs.dst then
        if curanim then
            return curanim.future
        elseif not kwargs.src then
            return rtk.Future():resolve(self)
        end
    end
    if kwargs.doneval == nil then
        kwargs.doneval = doneval
    end

    if not kwargs.src then
        -- Fetch the point-in-time calculated value -- if the attribute is animating we
        -- want to start from the current mid-animation value, not the current animation's
        -- dst value.
        kwargs.src = self:calc(attr, true)
        calc[attr] = kwargs.src
        calcsrc = kwargs.src ~= nil
    end
    if not calcsrc and meta.calculate then
        -- Convert given exterior value to a calculated value.
        kwargs.src = meta.calculate(self, attr, kwargs.src, {}, true)
        calc[attr] = kwargs.src
    end
    return rtk.queue_animation(kwargs)
end

--- Cancels any ongoing animation for the given attribute.
--
-- If there are no animations currently running for the attribute,
-- then this function is a no-op.
--
-- You can also call @{rtk.Future:cancel|cancel()} on the `rtk.Future` returned
-- by `animate()` but if you don't have a reference to the `rtk.Future` you can
-- call this function.
--
-- @tparam string attr the attribute name to stop animating
-- @treturn table|nil nil if no animation was cancelled, otherwise it's the
--   animation state table (see `get_animation()`).
function rtk.Widget:cancel_animation(attr)
    local anim = self:get_animation(attr)
    if anim then
        anim.future:cancel()
    end
    return anim
end

--- Gets the current ongoing animation for the given attribute, if any.
--
-- This can also be used to easily test if the attribute is currently animating,
-- as the return value's truthiness behaves like a boolean.
--
-- @tparam string attr the attribute name to check if animating
-- @treturn table|nil nil if no animation is running for the attribute, otherwise
--   it's a table containing the current animation state, which includes everything
--  passed to `animate()` (including any user-custom keys).
function rtk.Widget:get_animation(attr)
    -- Faster than string.format().  This method is called from calc() so small
    -- optimizations are useful.
    local key = self.id .. '.' .. attr
    return rtk._animations[key]
end

--- Sets the graphic context to the given color while respecting the widget's `alpha`.
--
-- This is considered a low-level function but is useful when implementing custom
-- widget drawing under/overlays via `ondrawpre()` and `ondraw()`.
--
-- See `rtk.color.set()` for more information, which this method wraps.
--
-- @tparam colortype color the color value to set
-- @tparam number|nil amul alpha muliplier to apply to `alpha`
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:setcolor(color, amul)
    rtk.color.set(color, (amul or 1) * self.calc.alpha)
    return self
end

--- Requests a full redraw from the widget's `rtk.Window` on next update.
--
-- It's usually not necessary to call this function as widgets know when to
-- redraw themselves, but if you're doing any custom drawing over widgets
-- and need to trigger a redraw based on some event rtk doesn't know about,
-- this can be explicitly called.
--
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:queue_draw()
    if self.window then
        self.window:queue_draw()
    end
    return self
end

--- Requests a reflow by the widget's `rtk.Window` on next update.
--
-- As with `queue_draw()`, this method also usually doesn't need to be directly invoked as
-- it is done automatically when attributes are changed via `attr()`.
--
-- If the reflow is expected to change the widget's geometry then `mode` *must* be
-- `rtk.Widget.REFLOW_FULL` or else sibling and ancestor widgets that may be affected by
-- this widget's geometry will not properly readjust.  However, if no geometry change has
-- occurred, a partial reflow is preferred as it's much faster.
--
-- @tparam reflowconst|nil mode the type of reflow to occur, where the default is `REFLOW_PARTIAL`
-- @tparam rtk.Widget|nil widget for partial reflows, this is the widget requesting the reflow
--   (`nil` implies `self`)
-- @treturn rtk.Widget returns self for method chaining
function rtk.Widget:queue_reflow(mode, widget)
    -- If self.window isn't set yet, it could be because a reflow hasn't yet occurred
    -- (because self.window is initialized in rtk.Widget:reflow()) but it could also be
    -- because the widget was parented but not visible on previous reflows, which would
    -- cause reflow() to be skipped.
    --
    -- So in the worst (and fortunately uncommon) case we will traverse up our parent
    -- hierarchy until we find a window.
    local window = self:_slow_get_window()
    if window then
        window:queue_reflow(mode, widget or self)
    end
    return self
end

--- Calculates and returns the widget's geometry given the bounding box.
--
-- This is called by parent containers on their children and usually does not need to be
-- directly invoked.
--
-- A reflow is required when the widget's geometry could be affected due to a geometry
-- change of a parent (this is called a *full reflow* because every visible widget must be
-- reflowed at the same time) or when some attribute of a widget changes that, while not
-- affecting its geometry, may affect its internal layout (called a *partial reflow*
-- because only the affected widgets need to be reflowed).  Reflows are not needed when
-- viewports are scrolled.
--
-- The *bounding box* is our maximum allowed geometry as dictated by the parent container.
-- Our parent itself has its own bounding box (dictated by its parent container, and so
-- on) and its job is to manage our position, relative to all our siblings, such that we
-- collectively fit within the parent's box.  Parents will clamp any offered boxes based
-- on `minw`/`maxw` and `minh`/`maxh`.
--
-- If `fillw` or `fillh` is specified, it requests that the widget consume the entirety
-- of the bounding box in that dimension.  The semantics of this varies by widget.
-- For example, buttons will stretch their surface to fit, while labels will
-- render normally but consider the filled dimension for alignment purposes.
--
-- This function will set `calc.x`, `calc.y`, `calc.w`, and `calc.h` for the widget (i.e.
-- the calculated geometry) and also returns them.
--
-- The box model is akin to CSS's `border-box` which means that any explicitly provided
-- width and height (and their calculated counterparts) includes the widget's padding
-- and border.
--
-- If the function is invoked with no parameters, then the parameters used in the
-- previous invocation will be reused (as cached in `rtk.Widget.box`).   This is
-- needed to implement partial reflows, in which the widget recalculates its own
-- internal content positioning within its previously calculated geometry.  In
-- contrast, a full reflow starts at the `rtk.Window` and recalculates the entire
-- widget tree.
--
-- @tparam number boxx bounding box of widget relative to parent's left edge
-- @tparam number boxy bounding box of widget relative to parent's top edge
-- @tparam number boxw bounding box width imposed by parent
-- @tparam number boxh bounding box height imposed by parent
-- @tparam bool fillw if true, widget should fill the full bounding box width
-- @tparam bool fillh if true, widget should fill the full bounding box height
-- @tparam bool clampw if true, the widget will clamp to the bounding box width; false
--   implies the widget can overflow the bounding box width, usually because it is
--   parented within an `rtk.Viewport` that allows horizontal scrolling
-- @tparam bool clamph like `clampw`, but applies in the vertical direction
-- @tparam number uiscale the current `rtk.scale.value` at the time of reflow
-- @tparam rtk.Viewport viewport the viewport the widget is rendered into
-- @tparam rtk.Window window the window the widget is ultimately parented within
-- @tparam bool greedyw if false avoid greedily expanding up to boxw even if fillw
--   is true, while if true (as is usually the case), allow expansion.  Greediness
--   is disabled when windows are doing an autosize reflow.
-- @tparam bool greedyh like `greedyw` but for height
-- @treturn number calculated x position of widget relative to parent
-- @treturn number calculated y position of widget relative to parent
-- @treturn number calculated width of widget
-- @treturn number calculated height of widget
-- @treturn bool true if the widget expanded to use all of boxw, which information is
--   used by parent containers for more robust positioning. If fillw is true, then it
--   implies true here as well, but there are cases when fillw is false but the widget
--   decides to use all offered space anyway (e.g. for boxes with expand=1).
-- @treturn bool true if the widget expanded to use all of boxh
function rtk.Widget:reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    -- Note that parent containers invoke this method, not the internal `_reflow()`.
    local calc = self.calc
    local expw, exph
    if not boxx then
        -- reflow() called with no arguments to indicate local reflow needed without
        -- any change to bounding box, so we can reuse the previous bounding box.
        if self.box then
            expw, exph = self:_reflow(table.unpack(self.box))
        else
            -- We haven't ever reflowed before, so no prior bounding box.   Caller isn't
            -- allowed to depend on our return arguments when called without supplying a
            -- bounding box.
            return
        end
    else
        self.viewport = viewport
        self.window = window
        self.box = {boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh}
        expw, exph = self:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    end
    self.realized = true
    self:onreflow()
    return calc.x, calc.y, calc.w, calc.h, expw or fillw, exph or fillh
end


--- Subclass API.
--
-- These methods are internal (as denoted by the prefixed underscore), but comprise the
-- subclass API that can be used to implement custom widgets.
--
-- Quite a lot of customization can be accomplished without creating a custom widget
-- subclass by using @{widget.handlers|event handlers}.  If you're looking for some
-- modest change in appearance of behavior of an existing widget, you might find it
-- more easily accomplished by hooking one or more event handlers, such as `ondraw()`.
--
-- Otherwise, for more sophisticated or complete widget implementations, you can subclass
-- `rtk.Widget` (or any other widget you want to build on top of) and use this subclass API
-- (or any @{methods|public method} as needed) for the implementation.
--
-- @warning
--   These methods are considered somewhat less stable than the @{methods|public methods}
--   and are more subject to change as rtk approaches 1.0.
--
-- #### Event Handling for Custom Widgets
--
-- Subclasses must not use any of the `on*` @{widget.handlers|event handlers} as a
-- means of implementing custom behavior, as these methods are intended to be replaced
-- wholesale by users for their own custom behaviors.
--
-- Instead, subclasses should override the internal `_handle_*` methods.  For every
-- `onfoo()` event handler there is a corresponding `_handle_foo()` (with the same
-- arguments) that's called first and which dispatches to `onfoo()`.  Subclasses can call
-- up to the superclass implementations for the default behavior.
--
-- The most common such method is `_handle_attr()` which subclasses commonly implement to
-- perform some customizations when some attribute is set.  For example:
--
-- @code
--   -- Create a custom widget subclassed directly from rtk.Widget
--   local MyWidget = rtk.class('MyWidget', rtk.Widget)
--   function MyWidget:_handle_attr(attr, value, oldval, trigger)
--       -- First delegate to the superclass implementation.  This example assumes
--       -- MyWidget subclasses directly from rtk.Widget.
--       local ok = rtk.Widget._handle_attr(self, attr, value, oldval, trigger)
--       -- We test for false explicitly because the superclass could return nil,
--       -- which means we would still be ok to proceed with our own logic.
--       if ok == false then
--          -- User-supplied onattr() handler returned false to bypass default behavior.
--          return ok
--       end
--       if attr == 'myattr' then
--          -- Just riffing here ...
--          self._whatever = value * 2
--       end
--       -- Indicates that we handled the event
--       return true
--   end
--
--
-- @section subclassapi

--- Returns padding from all 4 sides.
--
-- @treturn number top padding
-- @treturn number right padding
-- @treturn number bottom padding
-- @treturn number left padding
function rtk.Widget:_get_padding()
    -- Returns direct padding for now, but this abstraction lets us do fancier things
    -- later, like relative padding values.
    local calc = self.calc
    local scale = rtk.scale.value
    return
        (calc.tpadding or 0) * scale,
        (calc.rpadding or 0) * scale,
        (calc.bpadding or 0) * scale,
        (calc.lpadding or 0) * scale
end

--- Returns the border thickness from all 4 sides.
--
-- @treturn number top border thickness
-- @treturn number right border thickness
-- @treturn number bottom border thickness
-- @treturn number left border thickness
function rtk.Widget:_get_border_sizes()
    local calc = self.calc
    return
        calc.tborder and calc.tborder[2] or 0,
        calc.rborder and calc.rborder[2] or 0,
        calc.bborder and calc.bborder[2] or 0,
        calc.lborder and calc.lborder[2] or 0
end

--- Returns combined padding and border thickness.
--
-- @treturn number top border and padding thickness
-- @treturn number right border and padding thickness
-- @treturn number bottom border and padding thickness
-- @treturn number left border and padding thickness
function rtk.Widget:_get_padding_and_border()
    local tp, rp, bp, lp = self:_get_padding()
    local tb, rb, bb, lb = self:_get_border_sizes()
    return tp+tb, rp+rb, bp+bb, lp+lb
end

-- Conditionally multiplies the given value with rtk.scale.value if the scalability
-- attribute allows for full scaling of dimensions.  If relative is true, values
-- where 0 > value <= 1.0 will be left untouched.
function rtk.Widget:_adjscale(val, scale, box)
    if not val then
        return
    elseif val > 0 and val <= 1.0 and box then
        return val * box
    elseif (self.calc.scalability & rtk.Widget.FULL ~= rtk.Widget.FULL) then
        return val
    else
        return val * (scale or rtk.scale.value)
    end
end

--- Returns the top left position of the widget's box relative to its parent based on the
-- given bounding box position.
--
-- This method is usually called from `_reflow()` and it expects the `boxx` and `boxy`
-- parameters that were provided there.  And the return value is almost certainly what
-- custom widgets should assign to `calc.x` and `calc.y`.
--
-- Subclasses are expected to draw widget content relative to these coordinates, and need
-- to explicitly account for `lpadding` and `tpadding` as offsets from these coordinates.
function rtk.Widget:_get_box_pos(boxx, boxy)
    -- Tolerate nil x/y for e.g. rtk.Window
    local x = self.x or 0
    local y = self.y or 0
    if self.calc.scalability & rtk.Widget.FULL == rtk.Widget.FULL then
        local scale = rtk.scale.value
        return scale*x + boxx, scale*y + boxy
    else
        return x + boxx, y + boxy
    end
end

local function _get_content_dimension(size, box, padding, fill, clamp, greedy, scale)
    if size then
        if box and size < -1 then
        -- Relative to the far edge.
            return box + (size * scale) - padding
        elseif box and size <= 1.0 then
            -- A percentage of the bounding box.  This includes 1.0, which is equivalent
            -- to 100% of the bounding box, which means that an explicit size of 1 is not
            -- possible.
            return greedy and math.abs(box * size) - padding
        else
            return (size * scale) - padding
        end
    end
    -- If we're here, size was not specified.
    if fill and box and greedy then
        return box - padding
    end
end

--- Returns the dimensions allowed for the widget's inner content based on the `w` and `h`
-- attributes (if defined), but ignoring min/max size attributes.
--
-- This method is usually called from `_reflow()` as part of calculating the widget's
-- geometry, where the box, fill, and clamp parameters are those that were passed to
-- `_reflow()`.  This is also where relative sizes (i.e. when `w` or `h` is between
-- 0.0 and 1.0) are resolved into pixels.
--
-- If this method returns nil for either dimension, then the widget is not constrained
-- in that dimension and the widget implementation must calculate its intrinsic
-- size in that dimension (which varies by widget type).
--
-- The `minw`/`maxw` and `minh`/`maxh` attributes are ignored by this method. It is up to
-- the caller to subsequently clamp the resulting calculated width and height based on
-- these attributes.
--
-- @note
--   Remember that in rtk's box model any padding and border thickness is subtracted
--   from `w` and `h` which results in the size available for content.  In other words,
--   non-nil values returned here will exclude any `padding` in that dimension.
--
-- @tparam number boxw as in `reflow()`
-- @tparam number boxh as in `reflow()`
-- @tparam bool fillw as in `reflow()`
-- @tparam bool fillh as in `reflow()`
-- @tparam bool clampw as in `reflow()`
-- @tparam bool clamph as in `reflow()`
-- @tparam number|nil scale if the widget instance's `scalability` flags permit @{FULL|scaling
--   dimensions} then non-nil return values will be multipled by this amount (in addition
--   to `rtk.scale.value` which is implcitly included even when this argument is nil).
-- @tparam bool greedyw as in `reflow()`
-- @tparam bool greedyh as in `reflow()`
-- @treturn number|nil the content width, or nil if caller should use intrinsic width
-- @treturn number|nil the content height, or nil if caller should use intrinsic height
-- @treturn number the combined top padding and border size in pixels
-- @treturn number the combined right padding and border size in pixels
-- @treturn number the combined bottom padding and border size in pixels
-- @treturn number the combined left padding and border size in pixels
-- @treturn number|nil the minimum width, resolved from relative size if applicable, less padding,
--    or nil if `minw` is nil
-- @treturn number|nil as above, except maximum width
-- @treturn number|nil as above, except minimum height
-- @treturn number|nil as above, except maximum height
function rtk.Widget:_get_content_size(boxw, boxh, fillw, fillh, clampw, clamph, scale, greedyw, greedyh)
    scale = self:_adjscale(scale or 1)
    local tp, rp, bp, lp = self:_get_padding_and_border()
    local w = _get_content_dimension(self.w, boxw, lp + rp, fillw, clampw, greedyw, scale)
    local h = _get_content_dimension(self.h, boxh, tp + bp, fillh, clamph, greedyh, scale)
    local minw, maxw, minh, maxh = self:_get_min_max_sizes(boxw, boxh, greedyw, greedyh, scale)
    -- If clamping is enabled, clamp to the smaller of max size and box size
    maxw = maxw and clampw and math.min(maxw, boxw) or maxw
    maxh = maxh and clamph and math.min(maxh, boxh) or maxh
    -- Adjust min/max for border/padding.
    minw = minw and minw - lp - rp
    maxw = maxw and maxw - lp - rp
    minh = minh and minh - tp - bp
    maxh = maxh and maxh - tp - bp
    return w, h, tp, rp, bp, lp, minw, maxw, minh, maxh
end

-- Calculates min/max sizes based on the given box, converting relative values to absolute
-- values (relative to the box) if necessary, and adjusting non-relative values by scale.
function rtk.Widget:_get_min_max_sizes(boxw, boxh, greedyw, greedyh, scale)
    local minw, maxw, minh, maxh = self.minw, self.maxw, self.minh, self.maxh
    -- This mess adjusts non-relative min/max sizes by scale, and calculates relative sizes
    -- based on the given box but only if greedy -- when not greedy, nil is returned instead
    -- to allow use of intrinsic size.
    return minw and ((minw > 1 or minw <= 0) and (minw*scale) or (greedyw and minw*boxw)),
           maxw and ((maxw > 1 or maxw <= 0) and (maxw*scale) or (greedyw and maxw*boxw)),
           minh and ((minh > 1 or minh <= 0) and (minh*scale) or (greedyh and minh*boxh)),
           maxh and ((maxh > 1 or maxh <= 0) and (maxh*scale) or (greedyh and maxh*boxh))
end

--- Internal implementation of `reflow()`, using the same arguments and return values.
-- Subclasses override and there is no need to call up to this method: the default
-- rtk.Widget implementation merely sets the @{calc|calculated box geometry} based on sane
-- defaults, but widget implementations almost always need something slightly different.
--
-- Parent containers may directly modify a child's geometry (e.g. for alignment purposes)
-- after calling `reflow()`.  This means that subclass implementations of _reflow() must
-- not precompute any values to be used by `_draw()` that depend on geometry.  Use
-- `_realize_geometry()` for that instead, as the parent will invoke that method after
-- laying out the child (whether or not any modifications were made)
function rtk.Widget:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    local calc = self.calc
    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    -- The sizes returned by this method have padding and border removed.  When
    -- calculating final size later, they will need to be added in.
    local w, h, tp, rp, bp, lp, minw, maxw, minh, maxh = self:_get_content_size(
        boxw, boxh, fillw, fillh, clampw, clamph, nil, greedyw, greedyh
    )
    -- Intrinsic size of a no-op widget is purely based on given dimensions (w/h) or,
    -- if nil, the box size if filling, otherwise clamped to min/max, with padding
    -- added in (becuase rtk's box model is such that w/h include padding and border
    -- sizes).
    calc.w = rtk.clamp(w or (fillw and greedyw and (boxw - lp - rp) or 0), minw, maxw) + lp + rp
    calc.h = rtk.clamp(h or (fillh and greedyh and (boxh - tp - bp) or 0), minh, maxh) + tp + bp
    return fillw and greedyw, fillh and greedyh
end

--- Invoked by parent containers after the child's `reflow()` was called,
-- and after any parent-controlled geometry modifications (if any).
--
-- This is where subclasses should do any precalculations for `_draw()` that
-- depend on its geometry.  They mustn't do this within `_reflow()` because
-- parent containers can make direct modifications to the widget's calculated
-- geometry after `_reflow()` was called, for example to arrange the widget within
-- a box relative to siblings, or to implement cell alignment.
--
-- The default implementation simply sets `realized` to true.
function rtk.Widget:_realize_geometry()
    self.realized = true
end

function rtk.Widget:_slow_get_window()
    if self.window then
        -- Fast path before we try slow hierarchy traversal.
        return self.window
    end
    local w = self.parent
    while w do
        if w.window then
            return w.window
        end
        w = w.parent
    end
end

--- Tests to see if the mouse is currently over the widget.
--
-- The given coordinates is current the client position of the widget's parent,
-- which is identical to the arguments of the same name from `_handle_event()`
-- because this method is called from there.
--
-- You probably don't ever need to call this method directly and should instead
-- test the `mouseover` attribute instead as that takes into account any occluding
-- widgets.
--
-- That said, subclasses may need to override this method if they implement
-- non-default shapes, such as circular buttons.
--
-- @tparam number clparentx the x client coordinate of our parent's position
-- @tparam number clparenty the y client coordinate of our parent's position
-- @tparam rtk.Event event a mouse event that contains current mouse coordinates
-- @treturn bool true if the mouse is currently over the widget's area, false otherwise.
function rtk.Widget:_is_mouse_over(clparentx, clparenty, event)
    local calc = self.calc
    local x, y = calc.x + clparentx, calc.y + clparenty
    local w, h = calc.w, calc.h
    if calc._hotzone_set then
        local scale = rtk.scale.value
        local l = (calc.lhotzone or 0) * scale
        local t = (calc.thotzone or 0) * scale
        x = x - l
        y = y - t
        w = w + l + (calc.rhotzone or 0) * scale
        h = h + t + (calc.bhotzone or 0) * scale
    end
    return self.window and self.window.in_window and
           rtk.point_in_box(event.x, event.y, x, y, w, h)
end


--- Draws the widget.
--
-- This is an internal function not meant to be called directly but rather implemented by
-- subclasses.  It is invoked by parent containers, and the widget is expected to paint
-- itself on the current drawing target as setup by the parent (via `rtk.pushdest()`).
--
-- The default implementation simply sets `offx` and `offy`, calculates `clientx` and
-- `clienty`, and sets `drawn` to true.
--
-- Note that unlike `_handle_event()` which deals with client coordinates, implementations
-- of `_draw()` typically just need to use the given offsets (`offx` and `offy`) as they
-- refer to the widget's intended drawing location on the current drawing target.
--
-- However, if client coordinates are needed by implementations, once you call up to the
-- superclass method, `clientx` and `clienty` will be available for use.  (You can always
-- calculate this explicitly by summing cltargetx/cltargety with offx/offy, which
-- provides our client position less our own `x`/`y` position.  But it's usually
-- easier to just use `clientx` and `clienty`.)
--
-- @tparam number offx the x coordinate on the current drawing target that the
--   widget should offset its position as requested by the parent container.
-- @tparam number offy like `offx` but the y coordinate
-- @tparam number alpha the opacity (from 0.0 to 1.0) as imposed by the
--   parent container, which must be multiplied with `rtk.Widget.alpha` for drawing
-- @tparam rtk.Event event the event that occurred at the time of the redraw
-- @tparam number clipw the width of the drawing target beyond which anything the
--   widget draws will be automatically clipped.  This can be used by subclass
--   implementations for optimizations, not bothering to draw elements that won't
--   be visible.
-- @tparam number cliph like `clipw` but for height
-- @tparam number cltargetx the x coordinate of the current drawing target (typically a
--   `rtk.Viewport` backing store) relative to the window (where 0 indicates
--   the left edge of the `rtk.Window`).
-- @tparam number cltargety like cltargetx but the y coordinate
-- @tparam number parentx the x coordinate of our parent's position relative to the
--   current drawing target.  Rarely needed, but useful in certain limited
--   cases (for example when drawing fixed position widgets).
-- @tparam number parenty like `parentx` but the y coordinate
function rtk.Widget:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    self.offx = offx
    self.offy = offy
    self.clientx = cltargetx + offx + self.calc.x
    self.clienty = cltargety + offy + self.calc.y
    self.drawn = true
end

--- Draws the widget background.
--
-- This isn't called by the default _draw() method and is left up to direct subclasses of
-- rtk.Widget to call explicitly at the appropriate time.
--
-- All arguments are the same as `_draw()`.
function rtk.Widget:_draw_bg(offx, offy, alpha, event)
    local calc = self.calc
    if calc.bg and not calc.ghost then
        self:setcolor(calc.bg, alpha)
        gfx.rect(calc.x + offx, calc.y + offy, calc.w, calc.h, 1)
    end
end

--- Draws the widget's tooltip according to the `tooltip` attribute and
-- @{rtk.themes.tooltip_font|the current theme}.
--
-- @tparam number clientx the client x coordinate of the requested tooltip position
-- @tparam number clienty the client y coordinate of the requested tooltip position
-- @tparam number clientw the maximum width of the client area which the tootip
--   must not exceed.  The clientx value should also be adjusted if necessary to
--   ensure the tooltip doesn't exceed the width.
-- @tparam number clienth like clientw except for height
-- @tparam string tooltip the text of the tooltip to draw
function rtk.Widget:_draw_tooltip(clientx, clienty, clientw, clienth, tooltip)
    tooltip = tooltip or self.calc.tooltip
    -- This is undoubtedly very inefficient, allocating a new font and doing the layout
    -- each time.  However, the dependence on window geometry means we can't easily
    -- precalculate the segments as geometry can change.  Font is certainly cacheable, but
    -- this function is called so rarely it's scarcely worth the effort to make it more
    -- efficient.
    local font = rtk.Font(table.unpack(rtk.theme.tooltip_font))
    -- Some hardcoded magic in here, like fixed padding (5px around all edges).
    local segments, w, h = font:layout(tooltip, clientw - 10, clienth - 10, true)
    rtk.color.set(rtk.theme.tooltip_bg)
    local x = rtk.clamp(clientx, 0, clientw - w - 10)
    local y = rtk.clamp(clienty + 16, 0, clienth - h - 10 - self.calc.h)
    gfx.rect(x, y, w + 10, h + 10, 1)
    rtk.color.set(rtk.theme.tooltip_text)
    gfx.rect(x, y, w + 10, h + 10, 0)
    font:draw(segments, x + 5, y + 5, w, h)
end



function rtk.Widget:_unpack_border(border, alpha)
    local color, thickness = table.unpack(border)
    if color then
        self:setcolor(color or rtk.theme.button, alpha * self.calc.alpha)
    end
    return thickness or 1
end

--- Draws borders around the widget.
--
-- All arguments are the same as `_draw()`.
function rtk.Widget:_draw_borders(offx, offy, alpha, all)
    if self.ghost then
        return
    end
    local calc = self.calc
    if not all and calc.border_uniform and not calc.tborder then
        -- No border defined for this widget.
        return
    end
    local x, y, w, h = calc.x + offx, calc.y + offy, calc.w, calc.h
    local tb, rb, bb, lb
    all = all or (calc.border_uniform and calc.tborder)
    if all then
        local thickness = self:_unpack_border(all, alpha)
        -- If the border thickness is 1, which is the common case, we can paint it with a
        -- single gfx.rect() call.  Otherwise we fall back to the slower path that paints
        -- each edge separately.
        if thickness == 1 then
            gfx.rect(x, y, w, h, 0)
            return
        elseif thickness == 0 then
            -- Border disabled
            return
        else
            tb, rb, bb, lb = all, all, all, all
        end
    else
        tb, rb, bb, lb = calc.tborder, calc.rborder, calc.bborder, calc.lborder
    end
    if tb then
        local thickness = self:_unpack_border(tb, alpha)
        gfx.rect(x, y, w, thickness, 1)
    end
    if rb and w > 0 then
        local thickness = self:_unpack_border(rb, alpha)
        gfx.rect(x + w - thickness, y, thickness, h, 1)
    end
    if bb and h > 0 then
        local thickness = self:_unpack_border(bb, alpha)
        gfx.rect(x, y + h - thickness, w, thickness, 1)
    end
    if lb then
        local thickness = self:_unpack_border(lb, alpha)
        gfx.rect(x, y, thickness, h, 1)
    end
end

function rtk.Widget:_get_touch_activate_delay(event)
    if not rtk.touchscroll then
        return self.touch_activate_delay or 0
    else
        if not self.viewport or not self.viewport:scrollable() then
            -- Either no viewport or the child within the viewport is smaller
            -- than the viewport itself, so we don't need to delay the mousedown
            -- for touch scrolling.
            return 0
        end
        return (not self:focused(event) and event.button == rtk.mouse.BUTTON_LEFT) and
               self.touch_activate_delay or rtk.touch_activate_delay
    end
end

-- Whether the event should be handled by us, which currently just checks if
-- we (or our parent, via `listen`) is modal.
--
-- Not considering this part of the subclass API for now, as it mainly apples to
-- containers and custom container widgets are expected to subclass rtk.Container.
function rtk.Widget:_should_handle_event(listen)
    if not listen and rtk._modal and rtk._modal[self.id] ~= nil then
        -- Parent has told us not to listen, but we are registered as modal.
        return true
    else
        -- Parent is listening or we aren't modal, either way just return what
        -- the parent did.
        return listen
    end
end

--- Process an event.
--
-- This is an internal function not meant to be called directly, but rather it is invoked
-- by our parent container to handle an @{rtk.Event|event}, usually some user
-- interaction, but may be a generated event based on some timed action.
--
-- Subclasses can override, but most of the time subclasses will want to use one of the
-- `_handle_*` events that are internal analogues to the user-facing
-- @{widget.handlers|event handlers}.
--
-- @warning May be called before draw
--   Our parent will not invoke this method before a `reflow` and so calculated geometry is
--   guaranteed to be available, but it *may* call us before we're drawn, so event handlers
--   should be cautious about using `clientx` and `clienty` as they may not be calculated
--   yet, depending on the event.  (Specifically, when handling
--   @{rtk.Event.simulated|simulated events}, widgets should not expect fields set
--   during @{_draw|draw} to be valid.)
--
-- The parent will also call us even if the event was already handled by some other widget
-- so that we have the opportunity to perform any necessary finalization actions (for
-- example firing the `onmouseleave` handler).  It's our responsibility to determine if we
-- *should* handle this event, and if so, to dispatch to the appropriate internal
-- `_handle_*` method (which in turn calls the user-facing `on*` handlers), declare the
-- event handled by calling `rtk.Event:set_handled()`, and @{queue_draw|queuing a draw} if
-- necessary.
--
-- `clparentx` and `clparenty` refer to our parent's position relative to top-left of the
-- client window (in other words, these are *client* coordinates).
--
-- If `clipped` is true, it means the `rtk.Viewport` we belong to has indicated that the
-- mouse is currently outside the viewport bounds.  This can be used to filter mouse
-- events -- we must not fire `onmouseenter()` for a clipped event, for example -- but it
-- *can* be used to fire `onmouseleave()`.  (This is the reason that our parent even
-- bothers to call us for handled events.)
--
-- The `listen` parameter is somewhat the opposite of `clipped`.  If true, the event is
-- processed as normal.  If false, the event will propagate to children but otherwise will
-- be ignored unless the widget is @{rtk.add_modal|modal}, in which case `listen` is
-- flipped to true for us and our children.
--
-- When an event is marked as handled, a @{_draw|redraw} is automatically performed. If
-- a redraw is required when an event isn't explicitly marked as handled, such as in
-- the case of a @{onblur|blur} event, then `queue_draw()` must be called.
--
-- @tparam number clparentx the x client coordinate of our parent's position
-- @tparam number clparenty the y client coordinate of our parent's position
-- @tparam rtk.Event event the event to handle
-- @tparam bool clipped whether the mouse is outside our `rtk.Viewport`'s bounds
-- @tparam bool listen whether we should handle the event at all, or blindly
--   propagate the event to children
-- @treturn bool whether we determined we should listen to this event. Subclasses can
--   use this return value in their implementations.
function rtk.Widget:_handle_event(clparentx, clparenty, event, clipped, listen)
    local calc = self.calc
    if not listen and rtk._modal and rtk._modal[self.id] == nil then
        return false
    end
    local dnd = rtk.dnd
    if not clipped and self:_is_mouse_over(clparentx, clparenty, event) then
        -- Here, the mouse is inside our viewport (if applicable) and the mouse is within
        -- our region.  The mouse *may* be over a higher z-order widget that's occluding
        -- us: we know if that's the case because event.handled will be true.
        event:set_widget_mouseover(self, clparentx, clparenty)
        if event.type == rtk.Event.MOUSEMOVE and not calc.disabled then
            if dnd.dragging == self then
                if calc.cursor then
                    self.window:request_mouse_cursor(calc.cursor)
                end
                self:_handle_dragmousemove(event, dnd.arg)
            elseif self.hovering == false then
                -- Mousemove event over a widget that's not currently marked as hovering.
                if event.buttons == 0 or self:focused(event) then
                    -- No mouse buttons pressed or the widget currently has focus.  We set
                    -- the widget as hovering and mark the event as handled if the
                    -- onmouseenter() handler returns true, and assuming we haven't
                    -- already called onmouseenter() (which we know isn't the case if
                    -- self.mouseover is false).
                    if not event.handled and not self.mouseover and self:_handle_mouseenter(event) then
                        self.hovering = true
                        self:_handle_mousemove(event)
                        self:queue_draw()
                    elseif event.handled and self.mouseover then
                        -- We *were* in mouseover, but some other widget has handled the
                        -- mousemove widget. If we're a container, the subclass's
                        -- _handle_event() will correct for this if the widget that handled
                        -- the event was actually a child, but for now we reset to false
                        -- under the assumption that a higher z-index widget has occluded
                        -- us.
                        self.mouseover = false
                    elseif rtk.debug then
                        -- Widget didn't respond to onmouseenter() but we have global box debugging
                        -- enabled to queue a redraw anyway.
                        self:queue_draw()
                    end
                else
                    -- If here, mouse is moving while buttons are pressed.
                    if dnd.arg and not event.simulated and rtk.dnd.droppable then
                        -- We are actively dragging a widget
                        if dnd.dropping == self or self:_handle_dropfocus(event, dnd.dragging, dnd.arg) then
                            if dnd.dropping then
                                if dnd.dropping ~= self then
                                    dnd.dropping:_handle_dropblur(event, dnd.dragging, dnd.arg)
                                elseif not event.simulated then
                                    -- self is the drop target
                                    dnd.dropping:_handle_dropmousemove(event, dnd.dragging, dnd.arg)
                                end
                            end
                            event:set_handled(self)
                            self:queue_draw()
                            dnd.dropping = self
                        end
                    end
                end
                -- Set mouseover here now that onmouseenter() has had a chance to be invoked above,
                -- which prevents repeated firings of onmouseenter() if it doesn't return true.
                -- We only set mouseover to true if the event wasn't already handled by a higher
                -- z-index widget (or we handled it above).  And if a mouse button was pressed while
                -- the mouse was dragged over the widget region, we don't count that.
                if not self.mouseover and (not event.handled or event.handled == self) and event.buttons == 0 then
                    self.mouseover = true
                    self:queue_draw()
                end
            else
                -- In here, mousemove event with self.hovering true.
                if event.handled then
                    -- We were and technically still are hovering, but another widget has handled this
                    -- event.  One scenario is a a higher z-index container that's partially obstructing
                    -- our view and it has absorbing the event.
                    self:_handle_mouseleave(event)
                    self.hovering = false
                    self.mouseover = false
                    self:queue_draw()
                else
                    -- It's possible for mouseover to have been false even while hovering is true
                    -- if we were dragging.  Flip mouseover back to true just in case this scenario
                    -- occurred.
                    self.mouseover = true
                    self:_handle_mousemove(event)
                    -- The mouse is still hovering over this widget.  We implicitly mark
                    -- the mousemove event as handled to prevent any lower z-index widget
                    -- from changing the mouse cursor on us.
                    event:set_handled(self)
                end
            end
        elseif event.type == rtk.Event.MOUSEDOWN and not calc.disabled then
            local duration = event:get_button_duration()
            if duration == 0 then
                -- This is the initial non-simulated MOUSEDOWN event for this button
                -- press. Register ourselves as having been pressed, so we become eligible
                -- for dragging, and also to track state for deferred onmousedown().
                event:set_widget_pressed(self)
            end
            if not event.handled then
                -- State is a bitmap with the following bits:
                --     bit 0 (1): mousedown was dispatched
                --     bit 1 (2): mousedown was accepted
                --     bit 2 (4): doubleclick detected
                --     bit 3 (8): longpress dispatched
                --     bit 4 (16): longpress accepted
                local state = event:get_button_state(self) or 0
                -- If touch scrolling, apply the widget's mousedown delay unless it's already
                -- focused, in which case we send the mousedown immediately.
                local threshold = self:_get_touch_activate_delay(event)
                if duration >= threshold and state == 0 and event:is_widget_pressed(self) then
                    -- Indicate that onmousedown() has been dispatched for this button on this widget.
                    event:set_button_state(self, 1)
                    -- If mousedown handler returns false, then the mousedown was *not*
                    -- accepted, in which case bit 1 will not be set and onclick later
                    -- will not fire.
                    if self:_handle_mousedown(event) ~= false then
                        -- This will set the mousedown-handled button state to track the
                        -- fact that mousedown was handled by this widget.  We use this to
                        -- prevent generating a simulated deferred mousedown on mouseup
                        -- later.
                        self:_accept_mousedown(event, duration, state)
                    end
                elseif state & 8 == 0 then
                    if duration >= rtk.long_press_delay then
                        if self:_handle_longpress(event) then
                            self:queue_draw()
                            -- This flag prevents onclick() from firing later during
                            -- mouseup, as the contract says onclick() will not fire if
                            -- onlongpress() was handled.
                            event:set_button_state(self, state | 8 | 16)
                        else
                            -- Invoked but not handled, so just set a flag now to prevent
                            -- us from refiring onlongpress.
                            event:set_button_state(self, state | 8)
                        end
                    end
                end
                if self:focused(event) then
                    -- This is a refired (simulated) mousedown event and as we were
                    -- previously focused we'll hold onto the focus by marking the event
                    -- as handled.
                    event:set_handled(self)
                end
            end
        elseif event.type == rtk.Event.MOUSEUP and not calc.disabled then
            if not event.handled then
                if not dnd.dragging then
                    -- Mousedown had occurred over us, but the button wasn't pressed long enough
                    -- to exeed the threshold to trigger onmousedown originally, so we simulate a
                    -- mousedown now just prior to the real mouseup event.
                    self:_deferred_mousedown(event)
                end
                if self:_handle_mouseup(event) then
                    event:set_handled(self)
                    self:queue_draw()
                end
                local state = event:get_button_state(self) or 0
                -- Bit 1 is set when mousedown was accepted
                if state & 2 ~= 0 then
                    -- Don't fire an onclick() if we had already experienced a *handled*
                    -- onlongpress (where the mouse button state for this widget will be
                    -- have bit 4 set).
                    if state & 16 == 0 and not dnd.dragging then
                        if self:_handle_click(event) then
                            event:set_handled(self)
                            self:queue_draw()
                        end
                        local last = rtk.mouse.last[event.button]
                        -- Require the mouse cursor not to have moved more than some
                        -- threshold in order to register a double click.  The threshold
                        -- is adjusted for UI scale and the tolerance is much greater with
                        -- touch scrolling is enabled, as double-tap with a touch screen
                        -- will result in more pixel drift than an actual mouse click.
                        --
                        -- XXX: threshold disabled for now, until I can remember the use case
                        -- for why I added it to begin with, and then improve UX of normal
                        -- double clicks relative ot that use case.
                        --
                        -- local dx = last and math.abs(last.x - event.x) or 0
                        -- local dy = last and math.abs(last.y - event.y) or 0
                        -- local thresh = (rtk.touchscroll and 30 or 5) * rtk.scale.value
                        if state & 4 ~= 0 then --and dx < thresh and dy < thresh then
                            -- If state has bit 2 set, then it means the mousedown handler
                            -- determined this is a double click.  Now that the button has
                            -- been released, let's fire the event handler.
                            if self:_handle_doubleclick(event) then
                                event:set_handled(self)
                                self:queue_draw()
                            end
                            -- Double click finished, reset the timer.
                            self._last_mousedown_time = 0
                        end
                    end
                end
            end
            -- dnd.dragging and dnd.dropping are also nulled (as needed) in rtk.Window.update()
            if dnd.dropping == self then
                self:_handle_dropblur(event, dnd.dragging, dnd.arg)
                if self:_handle_drop(event, dnd.dragging, dnd.arg) then
                    event:set_handled(self)
                    self:queue_draw()
                end
            end
            self:queue_draw()
        elseif event.type == rtk.Event.MOUSEWHEEL and not calc.disabled then
            if not event.handled and self:_handle_mousewheel(event) then
                event:set_handled(self)
                self:queue_draw()
            end
        elseif event.type == rtk.Event.DROPFILE and not calc.disabled then
            if not event.handled and self:_handle_dropfile(event) then
                event:set_handled(self)
                self:queue_draw()
            end
        end

    -- Cases below are when mouse is not over over widget
    elseif event.type == rtk.Event.MOUSEMOVE then
        self.mouseover = false
        if dnd.dragging == self then
            -- If we're dragging, then set our mouse cursor.
            self.window:request_mouse_cursor(calc.cursor)
            self:_handle_dragmousemove(event, dnd.arg)
        end
        if self.hovering == true then
            -- Be sure not to trigger mouseleave if we're dragging this widget
            if dnd.dragging ~= self then
                self:_handle_mouseleave(event)
                self:queue_draw()
                self.hovering = false
            end
        elseif event.buttons ~= 0 and dnd.dropping then
            if dnd.dropping == self then
                -- Dragging extended outside the bounds of the last drop target (we know because
                -- we're not hovering), so need to reset.
                self:_handle_dropblur(event, dnd.dragging, dnd.arg)
                dnd.dropping = nil
            end
            self:queue_draw()
        end
    else
        -- All other events, ensure mouseover is cleared.
        self.mouseover = false
    end
    -- When touchscroll is enabled, ensure we also mark the mouseup as handled if we had
    -- previously handled mousedown and were focused as a result. This prevents rtk.Window
    -- from blurring us when touchscroll is enabled.
    if rtk.touchscroll and event.type == rtk.Event.MOUSEUP and self:focused(event) then
        if event:get_button_state('mousedown-handled') == self then
            event:set_handled(self)
            self:queue_draw()
        end
    end
    -- Key events don't depend on where the mouse is (as above) just whether we are
    -- focused.
    if event.type == rtk.Event.KEY and not event.handled then
        -- Dispatch the keypress if we're considered focused.
        if self:focused(event) and self:_handle_keypress(event) then
            event:set_handled(self)
            self:queue_draw()
        end
    end
    if event.type == rtk.Event.WINDOWCLOSE then
        self:_handle_windowclose(event)
    end
    -- Regardless of whether we have focus, if the mouse is over us be sure to set the
    -- custom cursor.
    if (self.mouseover or dnd.dragging == self) and calc.cursor then
        self.window:request_mouse_cursor(calc.cursor)
    end
    -- Indicates we listened to the event.
    return true
end

-- Emit a simulated mousedown event to handle touchscroll cases, where we don't want to
-- send mousedown immediately to give the user the opportunity to pan the viewport. This
-- is called during mouseup, or by rtk.Window during drag operations.
--
-- Even with touch scrolling, there are some cases where mousedown would already have been
-- fired, for example if the viewport contents fits on screen such that no scrolling is
-- needed, the touch activate delay will be 0 (as a small UX optimization).  So it's
-- possible that mousedown would already have been emitted and possibly handled.
function rtk.Widget:_deferred_mousedown(event, x, y)
    local mousedown_handled = event:get_button_state('mousedown-handled')
    if not mousedown_handled and event:is_widget_pressed(self) and not event:get_button_state(self) then
        local downevent = event:clone{type=rtk.Event.MOUSEDOWN, simulated=true, x=x or event.x, y=y or event.y}
        if self:_handle_mousedown(downevent) then
            -- Ensure mouseup gets handled so the window doesn't blur us. It's intentional
            -- that we handle the original event here, because we want to prevent
            -- propagation of e.g. mouseup if a widget responded to the simulated
            -- mousedown.
            self:_accept_mousedown(event)
        end
    end
end

function rtk.Widget:_accept_mousedown(event, duration, state)
    -- Track the fact that mousedown was handled by this widget.  When touch scrolling is
    -- enabled, this will prevent generating a simulated deferred mousedown on mouseup
    -- later.
    event:set_button_state('mousedown-handled', self)
    event:set_handled(self)
    if not event.simulated and event.time - self._last_mousedown_time <= rtk.double_click_delay then
        -- Bit 1 is mousedown accepted, bit 2 indicates a doubleclick occurred, which is
        -- checked during mouseup.
        event:set_button_state(self, (state or 0) | 2 | 4)
        self._last_mousedown_time = 0
    else
        -- Bit 1 is mousedown accepted
        event:set_button_state(self, (state or 0) | 2)
        self._last_mousedown_time = event.time
    end
    self:queue_draw()
end

--- Called when the widget (or one of its ancestors) is hidden.
--
-- Subclasses should use this to release resources that aren't needed when the
-- widget isn't being rendered, such as image buffers.
function rtk.Widget:_unrealize()
    self.realized = false
end


--- Called by the parent @{rtk.Window|window} when the widget is being asked to give up its
-- modal state.
--
-- When the widget was previously registered with `rtk.add_modal()` and the
-- user either clicks somewhere else within the window or if the window's
-- focus is lost, then this method is invoked.
--
-- It's not required that implementations honor the request, but if it does it can call
-- `rtk.reset_modal()`.  For example, a popup menu probably should close itself and
-- release its hijacking of input events when the user clicks outside of the popup area.
--
-- @tparam rtk.Event|nil event the event, if any, that was the cause of the invocation
function rtk.Widget:_release_modal(event)
end



--- Event Handlers.
--
-- These are special methods that are automatically dispatched when certain events
-- occur, such as mouse or keyboard actions.  This is the primary mechanism by which
-- user logic is hooked into rtk widgets, allowing the user to modify a widget's
-- default behavior or appearance.
--
-- These methods are designed to be replaced wholesale by your own functions. In most cases,
-- returning false from a handler prevents the widget's default behavior.
--
-- @code
--   local b = rtk.Button{label='Click me'}
--   b.onclick = function(button, event)
--       log.info('Button %s was clicked', button)
--   end
--
-- @warning Beware the first parameter
--   When you assign a custom function to an event handler as in the above example, take
--   note that the first parameter is *always* the widget itself, even though the handler
--   function signatures documented below don't explicitly include it.
--
--   While it is possible to rewrite the above example using implicit receiver passing ...
--
--   @code
--     function b:onclick(event)
--        log.info('Button %s was clicked', button)
--     end
--
--   ... this is not considered idiomatic for event handlers and should be avoided, in
--   part because if the handler body is defined within some other method (as is typical),
--   the handler will mask the outer receiver (as
--   [there can be only one](https://youtu.be/sqcLjcSloXs) `self`).
--
-- @section widget.handlers
-- @order before subclassapi


--- Called when an attribute is set via `attr()`, which is the proper way to modify any
--  attribute on a widget.
--
-- The default implementation ensures that appropriate reflow and redraw behavior
-- is preserved depending on which attribute was updated.
--
-- @tparam string attr the name of the changed attribute
-- @tparam any value the attribute's new calculated value
-- @tparam any oldval the attribute's previous calculated value
-- @tparam bool trigger if true, we are expected to emit any other
--   `on*()` handlers even if the value did not actually change.
-- @tparam bool sync if true, the attribute was set via `sync()`. This implies the
--   attribute value was set from within the widget in response to a user interaction
--   as opposed to programmatically.
-- @treturn bool|nil if false, suppresses the default behavior. Any other
--   value will execute default behavior.
function rtk.Widget:onattr(attr, value, oldval, trigger, sync) return true end

function rtk.Widget:_handle_attr(attr, value, oldval, trigger, reflow, sync)
    local ok = self:onattr(attr, value, oldval, trigger, sync)
    if ok ~= false then
        -- Always queue a reflow on attribute change, but only queue a more expensive full
        -- reflow if the rtk.Attribute has marked it for reflow. Otherwise we just request
        -- a partial reflow specifically for ourselves under the assumption that geometry
        -- did not change.
        local redraw
        if reflow == rtk.Widget.REFLOW_DEFAULT then
            local meta = self.class.attributes.get(attr)
            -- No explicit reflow direction given, use the attribute defined mode, or
            -- fallback to partial if attribute doesn't specify anything.
            reflow = meta.reflow or rtk.Widget.REFLOW_PARTIAL
            redraw = meta.redraw
        end
        if reflow ~= rtk.Widget.REFLOW_NONE then
            self:queue_reflow(reflow)
        elseif redraw ~= false then
            -- No reflow for this widget, but at least queue a draw.
            self:queue_draw()
        end
        if attr == 'visible' then
            if not value then
                self:_unrealize()
            end
            -- As we have changed visibility, set realized to false in case show() has
            -- been called from within a draw() handler for another widget earlier in the
            -- scene graph.  We need to make sure that this widget isn't drawn until it
            -- has a chance to reflow.
            self.realized = false
            self.drawn = false
        elseif attr == 'ref' then
            assert(not oldval, 'ref cannot be changed')
            self.refs[self.ref] = self
            rtk._refs[self.ref] = self
            if self.parent then
                -- A bit lame, but forces propagation of the ref up through the ancestors.
                self.parent:_sync_child_refs(self, 'add')
            end
        end
    end
    return ok
end

--- Called before any drawing from within the internal draw method.
--
-- There is no default implementation.
--
-- User-provided handlers can use this to customize the widget's appearance
-- by drawing underneath the widget's standard rendering.  The offx and offy
-- arguments indicate the widget's top left corner that all manual drawing
-- operations must explicitly take into account.
--
-- @tparam number offx the same value per `_draw()`
-- @tparam number offy the same value per `_draw()`
-- @tparam number alpha the same value per `_draw()`
-- @tparam rtk.Event event the same value per `_draw()`
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Widget:ondrawpre(offx, offy, alpha, event) end

function rtk.Widget:_handle_drawpre(offx, offy, alpha, event)
    return self:ondrawpre(offx, offy, alpha, event)
end


--- Called after the widget is finished drawing from within the internal
-- draw method.
--
-- There is no default implementation.
--
-- User-provided handlers can use this to customize the widget's appearance
-- by drawing over top of the widget's standard rendering.
--
-- @tparam number offx the same value per `_draw()`
-- @tparam number offy the same value per `_draw()`
-- @tparam number alpha the same value per `_draw()`
-- @tparam rtk.Event event the same value per `_draw()`
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Widget:ondraw(offx, offy, alpha, event) end

function rtk.Widget:_handle_draw(offx, offy, alpha, event)
    return self:ondraw(offx, offy, alpha, event)
end


--- Called when any mouse button is pressed down over the widget.
--
-- The default implementation focuses the widget if `autofocus` is true and returns true
-- if the focus was accepted to indicate the event is considered handled.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEDOWN` event, where
--   `rtk.Event.button` will indicate which mouse button was pressed.
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets. Returning false will
--   suppress the default behavior.
function rtk.Widget:onmousedown(event) end

function rtk.Widget:_handle_mousedown(event)
    local ok = self:onmousedown(event)
    if ok ~= false then
        local autofocus = self.calc.autofocus
        if autofocus or
           -- If the user has added a custom onclick handler then we implicitly assume
           -- autofocus, otherwise the user's onclick handler would never fire.
           (autofocus == nil and self.onclick ~= rtk.Widget.onclick) then
            self:focus(event)
            return ok or self:focused(event)
        else
            return ok or false
        end
    end
    return ok
end


--- Called when any mouse button is released over the widget.
--
-- The default implementation does nothing.
--
-- This event will fire even if the mouse button wasn't previously pressed over the same
-- widget (in other words, `onmousedown()` was never called).  The widget doesn't have to
-- be `focused`.  The only condition for this event is that the mouse button was
-- *released* over top of the widget.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEUP` event, where `rtk.Event.button` will
--   indicate which mouse button was released.
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets.
function rtk.Widget:onmouseup(event) end

function rtk.Widget:_handle_mouseup(event)
    return self:onmouseup(event)
end


--- Called when the mousewheel is moved while the mouse cursor is over the widget.
--
-- The default implementation does nothing.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEWHEEL` event, where `rtk.Event.wheel`
--   will indicate the wheel direction and distance.
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets, including (and
--   especially) parent @{rtk.Viewport|viewports}.
function rtk.Widget:onmousewheel(event) end

function rtk.Widget:_handle_mousewheel(event)
    return self:onmousewheel(event)
end


--- Called when the mouse button is pressed and subsequently released over a widget quickly
-- enough that it's not considered a @{onlongpress|long press}.
--
-- The default implementation does nothing.
--
-- @tparam rtk.Event event an `rtk.Event.MOUSEUP` event, where
--   `rtk.Event.button` will indicate which mouse button was pressed.
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets.
function rtk.Widget:onclick(event) end

function rtk.Widget:_handle_click(event)
    return self:onclick(event)
end


--- Called after two successive `onclick` events occur within `rtk.double_click_delay`
-- over a widget.
--
-- The default implementation does nothing.
--
-- @tparam rtk.Event event the `rtk.Event.MOUSEUP` event that triggered the double click
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets.
function rtk.Widget:ondoubleclick(event) end

function rtk.Widget:_handle_doubleclick(event)
    return self:ondoubleclick(event)
end


--- Called after the mouse has been consistently held down for `rtk.long_press_delay` over
-- a widget.
--
-- The default implementation does nothing.
--
-- @tparam rtk.Event event an `rtk.Event.MOUSEDOWN` event that triggered the long press
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets and also `onclick()` will
--  **not** fire after the mouse button is released.
function rtk.Widget:onlongpress(event) end

function rtk.Widget:_handle_longpress(event)
    return self:onlongpress(event)
end


--- Called once when the mouse is moved within the widget's region.
--
-- The default implementation returns true if `autofocus` is set to true.
--
-- If the mouse moves while the pointer stays within the widget's geometry
-- this handler isn't retriggered.  It will fire again once the mouse exits
-- and re-enters the widget's region.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets, and moreover the widget
--   will be considered `hovering`.  Returning false suppresses the default
--   behavior.
function rtk.Widget:onmouseenter(event) end

function rtk.Widget:_handle_mouseenter(event)
    local ok = self:onmouseenter(event)
    if ok ~= false then
        return self.calc.autofocus or ok
    end
    return ok
end

--- Called once when the mouse was previously `hovering` over a widget but then moves
-- outside its geometry.
--
-- The default implementation does nothing.
--
-- If `onmouseenter()` hadn't returned true such that the widget isn't marked as
-- `hovering`, then this handler won't be called.
--
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @treturn bool|nil returning true indicates the event is to be marked as handled
--   and it will not propagate to lower z-index widgets, and moreover the widget
--   will be considered `hovering`.
function rtk.Widget:onmouseleave(event) end

function rtk.Widget:_handle_mouseleave(event)
    return self:onmouseleave(event)
end


--- Called when the mouse is moved within a `hovering` widget.
--
-- The default implementation does nothing.
--
-- If `onmouseenter()` hadn't returned true such that the widget isn't marked as
-- `hovering`, then this handler won't be called.
--
-- Unlike most other event handlers, the return value has no significance.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
function rtk.Widget:onmousemove(event) end

rtk.Widget.onmousemove = nil

function rtk.Widget:_handle_mousemove(event)
    if self.onmousemove then
        return self:onmousemove(event)
    end
end


--- Called when a key is pressed while the widget is `focused`.
--
-- @tparam rtk.Event event a `rtk.Event.KEY` event
-- @treturn bool if true, the event is considered handled; if false, the default
--   behavior of the widget is circumvented; any other value will perform the
--   default behavior.
function rtk.Widget:onkeypress(event) end

function rtk.Widget:_handle_keypress(event)
    return self:onkeypress(event)
end

--- Called when a widget is about to be focused where the handler can decide
-- whether to accept the `focus` request.
--
-- The default implementation always returns true, accepting the focus.
-- Rejecting focus largely means the widget is non-interactive, and
-- events that depend on focus (such as `onclick()` or `onkeypress()`) won't fire.
--
-- @tparam rtk.Event|nil event if defined, is the event that caused the
--   focus to be requested (usually a mouse click).  But it can be nil
--   if `focus()` was directly called by the user.
-- @treturn bool if true, focus is accepted.  False rejects the focus.
function rtk.Widget:onfocus(event)
    return true
end

function rtk.Widget:_handle_focus(event)
    return self:onfocus(event)
end


--- Called when a widget is about to lose focus where the handler can decide
-- whether or not to relinquish focus.
--
-- The default implementation always returns true, relinquishing focus.
--
-- @tparam rtk.Event|nil event if defined, is the event that caused the
--   focus to be requested (usually a mouse click).  But it can be nil
--   if `blur()` was directly called by the user.
-- @tparam rtk.Widget|nil other if we are being blurred because another widget
--   wants focus, this will be that other widget.
-- @treturn bool if true, we relinquish focus, while false hangs onto it.
function rtk.Widget:onblur(event, other)
    return true
end

function rtk.Widget:_handle_blur(event, other)
    return self:onblur(event, other)
end


--- Called when a widget is dragged and dictates the widget's draggability.
--
-- The default implementation returns false, indicating that it is not
-- draggable.
--
-- This event fires when any mouse button is clicked on a widget, the button
-- is held down, and the mouse is moved.
--
-- The callback's return value controls whether the drag operation should
-- occur, and whether the widget is considered droppable.  (An example of a
-- draggable-but-not-droppable widget is `rtk.Viewport`, which uses the
-- drag-and-drop system for its scrollbar implementation.)
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @tparam number x the x position of the mouse pointer when the mousedown first occurred.
--   This is different from `event.x` because the latter reflects the new mouse position
--   where the change in position is what caused the drag to occur, while the x parameter
--   is the original position.  `math.abs(event.x - x)` represents the delta.
-- @tparam number y like x, but for the y coordinate
-- @tparam number t the original `rtk.Event.time` when the mousedown first occurred
-- @treturn any if the first return value is truthy value (i.e. neither false
--   nor nil), then the widget is considered dragging and this return value
--   is the user-provided drag argument that will be supplied to other `ondrag*`
--   and `ondrop*` handlers as `dragarg`.
-- @treturn bool|nil if false, the widget will not be droppable and
--   the `ondrop*` handlers of widgets this one hovers over will not be triggered,
--   while with any other value (including nil), `ondrop*` handlers will be called
--   on widgets we hover over.
function rtk.Widget:ondragstart(event, x, y, t) end

-- Subclasses shouldn't call us as we always return not draggable (unless the
-- user overrides).
function rtk.Widget:_handle_dragstart(event, x, y, t)
    local draggable, droppable = self:ondragstart(event, x, y, t)
    if draggable == nil then
        -- Not draggable, and not droppable (although not draggable implies that
        -- already)
        return false, false
    end
    return draggable, droppable
end



--- Called on a dragging widget when the mouse button is released.
--
-- The default implementation does nothing.
--
-- A widget is dragging when `ondragstart()` returned true when a drag was
-- attempted.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @tparam any dragarg the first value returned by `ondragstart()`.
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Widget:ondragend(event, dragarg) end

function rtk.Widget:_handle_dragend(event, dragarg)
    -- Reset double click timer
   self._last_mousedown_time  = 0
    return self:ondragend(event, dragarg)
end


--- Called on a dragging widget while the button is being held.
--
-- In order to support `scroll_on_drag`, this event is fired periodically
-- on a dragging widget even if the mouse didn't actually move.  When this
-- happens, the @{rtk.Event.simulated|simulated} field on the event will be
-- true.
--
-- The default implementation does nothing.
--
-- @note
--   While the widget is dragging, its `cursor` (if set) will always be active even if the
--   mouse moves over another widget that defines its own cursor.  If you want a particular
--   mouse cursor to appear while dragging a widget that's *different* from the dragging
--   widget's `cursor` you can call `rtk.Window:request_mouse_cursor()` from this handler.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @tparam any dragarg the first value returned by `ondragstart()`.
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Widget:ondragmousemove(event, dragarg) end

function rtk.Widget:_handle_dragmousemove(event, dragarg)
    return self:ondragmousemove(event, dragarg)
end


--- Called when some other dragging widget has moved within our boundary.
--
-- This event determines if we are a potential drop target for the dragging
-- widget.  If so, we return true to subscribe to future `ondropmousemove()`,
-- `ondropblur()`, or `ondrop()` events for this drag operation from the
-- other widget.
--
-- The default implementation returns false, refusing being a drop target.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @tparam rtk.Widget source the other widget that is the source of drag operation
-- @tparam any dragarg the first value returned by `ondragstart()`.
-- @treturn bool true if we are a potential drop target, and false otherwise.
function rtk.Widget:ondropfocus(event, source, dragarg)
    return false
end

function rtk.Widget:_handle_dropfocus(event, source, dragarg)
    return self:ondropfocus(event, source, dragarg)
end


--- Called when some other dragging widget has moved within our boundary after we
-- previously accepted being a potential drop target in `ondropfocus()`.
--
-- The default implementation does nothing.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @tparam rtk.Widget source the other widget that is the source of drag operation
-- @tparam any dragarg the first value returned by `ondragstart()`.
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Widget:ondropmousemove(event, source, dragarg) end

function rtk.Widget:_handle_dropmousemove(event, source, dragarg)
    return self:ondropmousemove(event, source, dragarg)
end


--- Called when some other dragging widget has left our boundary after we previously
-- accepted being a potential drop target in `ondropfocus()`.
--
-- The default implementation does nothing.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @tparam rtk.Widget source the other widget that is the source of drag operation
-- @tparam any dragarg the first value returned by `ondragstart()`.
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Widget:ondropblur(event, source, dragarg) end

function rtk.Widget:_handle_dropblur(event, source, dragarg)
    return self:ondropblur(event, source, dragarg)
end


--- Called when some other dragging widget has been dragged over us and the mouse button
-- was released, after having accepted being a potential drop target in `ondropfocus()`.
--
-- The default implementation returns false, refusing the drop.
--
-- @tparam rtk.Event event a `rtk.Event.MOUSEMOVE` event
-- @tparam rtk.Widget source the other widget that is the source of drag operation
-- @tparam any dragarg the first value returned by `ondragstart()`.
-- @treturn bool|nil returning true indicates the drop was accepted, and the event is
--   to be marked as handled so it will not propagate to lower z-index widgets.
function rtk.Widget:ondrop(event, source, dragarg)
    return false
end

function rtk.Widget:_handle_drop(event, source, dragarg)
    return self:ondrop(event, source, dragarg)
end

--- Called after a reflow occurs on the widget, for example when the geometry
-- of the widget (or any of its parents) changes, or the widget's visibility
-- is toggled.
--
-- The default implementation does nothing.
--
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Widget:onreflow() end

function rtk.Widget:_handle_reflow()
    return self:onreflow()
end


--- Called when files are dropped over the widget from outside the application.
--
-- The `rtk.Event.files` field holds the list of file paths that were dropped.  If the
-- callback returns a non-false value then the event is considered handled.
--
-- @tparam rtk.Event event a `rtk.Event.DROPFILE` event, where
--   `rtk.Event.files` will hold the list of file paths that were dropped.
-- @treturn bool|nil returning true indicates the drop was accepted, and the event is
--   to be marked as handled so it will not propagate to lower z-index widgets.
function rtk.Widget:ondropfile(event) end

function rtk.Widget:_handle_dropfile(event)
    return self:ondropfile(event)
end


-- Called just before the main window closes.
--
-- Internal only event for now.
function rtk.Widget:_handle_windowclose(event)
end