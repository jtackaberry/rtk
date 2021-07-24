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


--- Boxes lay out widgets sequentially in one direction (either horizontally or
-- vertically).
--
-- This is the base class for **single-direction box layouts**.  Don't use this class
-- directly -- use `rtk.HBox` or `rtk.VBox` instead.  However, in order to avoid
-- documenting everything twice, the interface for both box orientations is documented
-- here.
--
-- @note Terminology
--  When describing the behaviors, phrases like "box orientation" or "box
--  direction" refers to the dimension children are laid out within the box.
--  For VBox the box direction refers to either vertical or height (depending on the
--  context), and for HBox it refers to either horizontal or width.
--
--  For example, if we say "fills the cell in the box direction" it means the fill is
--  horizontal for HBox, and vertical for VBox.
--
--
-- ### Scalable Layouts
--
-- While boxes support all the cell attributes documented in `rtk.Container`, the most
-- important box-specific cell attribute is `expand`.  The `expand` cell attribute
-- controls how much space is allocated to a cell in the box direction.
--
-- When `expand` isn't specified (or when it's explicitly `0`) the cell will be only as
-- big as necessary to fit its widget, but expanded cells will force the overall box to
-- fill out to its own bounding box (in the box direction) and then will compete with one
-- another for that available space.
--
-- This mechanism can be used to create fluid layouts.  For example, an `rtk.HBox` added
-- directly to an `rtk.Window` can create a multi-paned layout that scales with the
-- window.  Consider:
--
-- @code
--  local box = window:add(rtk.HBox())
--  -- Creates a 3-column layout.  fillh=true is needed for this simple example to ensure
--  -- the Spacer widgets fill the height of the box.  (stretch=true would also work for
--  -- this demonstration, although it is subtly different.)
--  box:add(rtk.Spacer(), {expand=1, fillh=true, bg='cornflowerblue'})
--  box:add(rtk.Spacer(), {expand=1, fillh=true, bg='royalblue'})
--  box:add(rtk.Spacer(), {expand=2, fillh=true, bg='tan'})
--
-- This code generates a box that looks and scales like this:
--
-- ![](../img/box-scalable-layout.gif)
--
-- @warning Widgets with relative dimensions
--  While widgets can specify fractional values for `w` and `h` which are relative to the
--  bounding box imposed by the parent, use of fractional geometry for widgets can yield
--  some surprising behavior in boxes: the available space for a given widget (and
--  therefore the bounding box against which fractional values are calculated) shrinks with
--  each subsequent widget in the box.
--
--  So for the first widget in an `rtk.HBox`, `w=0.5` will mean 50% of the overall box,
--  because it's offered all available space.  Then, having taken up half the offered
--  space, the remaining half will be offered to the second widget in the box.  If that
--  second widget also specifies `w=0.5` then it's actually half the *remaining* space,
--  which works out to 25% of the overall box.
--
--  For this reason, it's preferred to use `expand` for responsive layouts, which behaves
--  more intuitively.
--
-- @class rtk.Box
-- @inherits rtk.Container
-- @see rtk.HBox rtk.VBox
rtk.Box = rtk.class('rtk.Box', rtk.Container)
rtk.Box.static.HORIZONTAL = 1
rtk.Box.static.VERTICAL = 2


--- Flexspaces.
--
-- `rtk.Box.FLEXSPACE` can be added to boxes in place of a widget to push any subsequent
-- widgets all the way out to the far edge of the box. Flexspaces consume all
-- remaining space not used by widgets.  This is similar to adding an `rtk.Spacer` with
-- `expand=1`, except that flexspaces do not create cells, they only modify the positions
-- of cells after the flexspace. Flexspaces are therefore a tiny bit faster, and a tiny
-- bit more convenient and readable.
--
-- For example:
--
-- @code
--   local box = window:add(rtk.HBox())
--   box:add(rtk.Text{'Left side', padding=20}, {bg='cornflowerblue'})
--   box:add(rtk.Box.FLEXSPACE)
--   box:add(rtk.Text{'Right side', padding=20}, {bg='tan'})
--
-- This produces:
--
-- ![](../img/box-flexspace.gif)
--
-- If multiple flexspaces are added to a box, the unused space will be divided between them
-- (as if they had all used the same `expand` value).
--
-- Note that as flexspaces don't technically create cells, any cell attributes passed to
-- @{rtk.Container.add|add()} are ignored.  This means, for example, `bg` can't be defined
-- on flexspaces, because there's no cell to color.  If you do need this, explicitly add
-- an `rtk.Spacer` widget with `expand` instead.
--
-- @section flexspace

-- XXX: nesting boxes where the inner box is a non-expanded child of the outer box and
-- has a flexspace will consume all remaining space from the outer box, even if the outer
-- box has subsequent children.  Children after the flexspace will have no more available
-- room (their bounding box will be 0).
rtk.Box.static.FLEXSPACE = {}



--- Stretch Constants.
--
-- Used with the `stretch` cell attribute to control cell size perpendicular to the
-- box direction, where lowercase strings of these constants can be used for
-- convenience (e.g.  `'siblings'` instead of `rtk.Box.STRETCH_TO_SIBLINGS`).
-- These strings are automatically converted to the appropriate numeric
-- constants.
--
-- @section stretchconst
-- @compact

--- No stretching is done, the cell is based on the widget's desired size
-- @meta 'none'
rtk.Box.static.STRETCH_NONE = 0

--- Stretch the cell to the far edge of the box.
-- @meta 'full'
rtk.Box.static.STRETCH_FULL = 1
--- Stretch the cell only as far as the largest cell of all other siblings in the box.
-- @meta 'siblings'
rtk.Box.static.STRETCH_TO_SIBLINGS = 2


rtk.Box.register{
    --- Cell attributes.
    --
    -- Cell attributes are passed to e.g.  @{rtk.Container.add|add}() and control
    -- how a child is laid out within its cell.
    --
    -- In addition to these box-specific cell attributes described below, boxes also
    -- support all the @{container.cellattrs|cell attributes from the base rtk.Container}.
    -- However in some cases the possible values are extended, so those deltas are
    -- documented below.
    --
    -- @section box.cellattrs


    --- Dictates allocated cell size in the box direction and *only* in that direction
    -- (default nil).
    --
    -- If not defined (or `expand` is 0), which is default, then the cell will
    -- "shrinkwrap" to the child's desired size in the box direction.  By setting
    -- `expand` to a value greater than 0, the cell will be sized according its ratio of
    -- expand units relative to all other expanded siblings, minus any space needed for
    -- non-expanded children.
    --
    -- For example, if only one child in the box has `expand=1` then space for all
    -- other cells will first be reserved to fit their (non-expanded) children's desired
    -- size, and then all remaining space in the container will be given to the expanded
    -- cell.
    --
    -- Or suppose you have 3 children in the box and all of them are given `expand=1`,
    -- then the total expand units is 3, and each child will be given 1/3 of the container
    -- space.
    --
    -- Or if you have 2 children, one with `expand=1` and the second with `expand=2`, then
    -- the total expand units is again 3, and the first child is given 1/3 of the box
    -- while the second is given 2/3.  Fractional values work too: for example, one child
    -- with `expand=0.2` and another with `expand=0.8`.  (The expand units are arbitrary
    -- and don't need to add up to 1 -- only the child's ratio against the total expand
    -- units matters -- but if using fractional values you may find it less confusing to
    -- have them sum to 1.0.)
    --
    -- Note that `expand` *only* controls the cell size in the box direction.  The child
    -- will not automatically fill to fit the cell; for that use either `fillw` or `fillh`
    -- (depending on the box direction).  Non-filled children however may be aligned
    -- within an expanded cell by using either the `halign` or `valign` cell attributes
    -- (whichever corresponds to the box direction).
    --
    -- This image demonstrates `expand` with `rtk.HBox`, with the blue color indicating
    -- the background of the expanded cells.  (`rtk.VBox` works the same except of course
    -- that the expansion is in the vertical direction.)
    --
    -- ![](../img/box-expand.gif)
    --
    -- @warning Expand with flexible viewports
    --
    --   When adding a box to an `rtk.Viewport` which is *flexible* in the box direction
    --   (i.e. adding an `rtk.HBox` to a viewport with @{rtk.Viewport.flexw|flexw=true}, or
    --   adding an `rtk.VBox` to a viewport with @{rtk.Viewport.flexh|flexh=true}), if the
    --   box itself has no explicit size of its own in the box direction then `expand=1`
    --   would technically be infinite.
    --
    --   In practice obviously an infinite size isn't possible, so instead the box
    --   calculates expanded cell sizes as if the viewport *wasn't* flexible, and instead
    --   uses the viewport's own bounding box as the needed constraint.  But this behavior
    --   is subject to change in future, so it's recommended not to rely on it.
    --
    -- @type number|nil
    expand = nil,

    --- Controls how the child will fill its width within the cell (default false).  If
    -- true, the child widget will fill the full width of the cell.  Otherwise, if false,
    -- it will use its natural width.
    --
    -- For `rtk.HBox`, setting `fillw`=true implies `expand`=1 if `expand` is not already
    -- defined.  Meanwhile, for `rtk.VBox`, setting `fillw`=true implies `stretch`=true.
    --
    -- ![](../img/box-fillw.gif)
    --
    -- @type boolean
    fillw = false,

    --- Controls how the child will fill its height within the cell (default false).
    --
    -- Everything described about `fillw` applies here, except with the orientation
    -- swapped.  So for `rtk.VBox`, setting `fillh`=true implies `expand`=1 (if `expand`
    -- isn't already defined), and for `rtk.HBox` setting `fillh`=true implies `stretch`=true.
    --
    -- @type boolean
    fillh = false,

    --- Whether the cell should expand perpendicular to the box direction, unlike the
    -- `expand` attribute which is in the box direction (default false).
    --
    -- This diagram depicts the difference between `expand` and `stretch` for the different
    -- box types:
    --
    -- ![](../img/expand-vs-stretch.png)
    --
    -- Unlike `expand`, the `stretch` value is not expressed in units because there's no
    -- competition for space between siblings.  Instead, the @{stretchconst|stretch
    -- constants} apply here. However, for convenience, a boolean can also be used for
    -- the most common cases, where `true` is equivalent to `STRETCH_FULL` and `false` is
    -- equivalent to `STRETCH_NONE`.
    --
    -- Like `expand`, `stretch` dictates the cell size, not whether the widget should
    -- itself fill out to the cell's edge.  For this, `fillw` or `fillh` (whichever is
    -- opposite of the box direction) is still required.
    --
    -- Stretching can be useful for alignment purpose.  For example, if you have an
    -- `rtk.HBox` and set the cell attribute `valign`='center' the question is what should
    -- the widget be centered vertically against?  Unless `stretch` is explicitly set to
    -- `STRETCH_FULL`, the implied value is `STRETCH_TO_SIBLINGS`, so that the widget
    -- will be centered relative to its tallest sibling.  If `stretch` meanwhile is
    -- `STRETCH_FULL`, a `valign`='center' widget in the `rtk.HBox` will be vertically
    -- centered relative to the box's own parent-imposed height limit.
    --
    -- Here are two examples showing the behavior of `stretch` in the context of two HBoxes,
    -- where `stretch` applies in the vertical (i.e. perpendicular) direction.  The thick
    -- black rectangle is the boundary of the HBox.  In the left example where, the
    -- center-valigned purple sibling is centered relative to the grey `h=0.7` widget
    -- because `stretch`=siblings is implied due to non-top alignment. In the right
    -- example where stretch is true, now the purple widget is centered relative to the
    -- HBox's full height.
    --
    -- ![](../img/box-stretch.gif)
    --
    -- @type stretchconst|boolean|string
    stretch = rtk.Attribute{
        calculate={
            none=rtk.Box.STRETCH_NONE,
            full=rtk.Box.STRETCH_FULL,
            siblings=rtk.Box.STRETCH_TO_SIBLINGS,
            -- Parallels with fill
            [true]=rtk.Box.STRETCH_FULL,
            [false]=rtk.Box.STRETCH_NONE,
            [rtk.Attribute.NIL]=rtk.Box.STRETCH_NONE,
        }
    },

    -- Background color of cell.  Different than widget bg as the entire cell is painted
    -- this color even if the inner widget does not fill it.
    bg = nil,

    -- NOTE: minw (for horiz boxes) and minw (for vert boxes): if combining with expand
    -- currently can result in an overflow of the container.  May be fine for
    -- boxes that fully fill an rtk.Window or rtk.Viewport both which support clipping. So
    -- could be used for full-window layouts.

    --- Class API
    --- @section api

    -- Specified by subclasses, either rtk.Box.HORIZONTAL or rtk.Box.VERTICAL
    orientation = nil,

    --- Amount of space in pixels to insert between cells (default 0). Spacing is not added
    -- around the edges of the container, only inside the container and between cells.
    --
    -- The `bg` cell attribute does not apply to the spacing area, however the box's
    -- own @{rtk.Widget.bg|bg} does.
    --
    -- @type number
    -- @meta read/write
    spacing = rtk.Attribute{
        default=0,
        reflow=rtk.Widget.REFLOW_FULL,
    },

}

function rtk.Box:initialize(attrs, ...)
    rtk.Container.initialize(self, attrs, self.class.attributes.defaults, ...)
    assert(self.orientation, 'rtk.Box cannot be instantiated directly, use rtk.HBox or rtk.VBox instead')
end

function rtk.Box:_validate_child(child)
    if child ~= rtk.Box.FLEXSPACE then
        rtk.Container._validate_child(self, child)
    end
end

function rtk.Box:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, viewport, window)
    local calc = self.calc
    calc.x, calc.y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp = self:_get_content_size(boxw, boxh, fillw, fillh, clampw, clamph)
    -- Our default size is the given box without our padding
    local inner_maxw = w or (boxw - lp - rp)
    local inner_maxh = h or (boxh - tp - bp)
    -- If we have a constrained width or height, ensure we tell children to clamp to it
    -- regardless of what our parent told us.
    clampw = clampw or w ~= nil or fillw
    clamph = clamph or h ~= nil or fillh

    self._reflowed_children = {}
    self._child_index_by_id = {}

    -- Now determine our intrinsic size based on child widgets.
    local innerw, innerh, expand_unit_size, expw, exph = self:_reflow_step1(inner_maxw, inner_maxh, clampw, clamph, viewport, window)
    if self.orientation == rtk.Box.HORIZONTAL then
        expw = (expand_unit_size > 0) or expw
    elseif self.orientation == rtk.Box.VERTICAL then
        exph = (expand_unit_size > 0) or exph
    end

    innerw, innerh = self:_reflow_step2(
        inner_maxw, inner_maxh,
        innerw, innerh,
        clampw, clamph,
        expand_unit_size,
        viewport, window,
        tp, rp, bp, lp
    )

    -- self.w/self.h could be negative or fractional, which is ok because
    -- _get_content_size() returns the correct value.  If that's the case, force
    -- fill to be enabled so our final calculated w/h below uses the resolved
    -- values.
    fillw = fillw or (self.w and self.w < 1.0)
    fillh = fillh or (self.h and self.h < 1.0)
    -- Our children may have ignored the bounding box we imposed on them, causing the
    -- inner dimension to exceed either our own bounding box or our own explicitly defined
    -- size.  Here we report our explicitly defined size if specified, and if not then
    -- allow the overflow to occur and let our parent deal with it (maybe it's able to
    -- clip us, e.g. a viewport)
    innerw = w or math.max(innerw, fillw and inner_maxw or 0)
    innerh = h or math.max(innerh, fillh and inner_maxh or 0)
    -- Calculate border box to include our padding
    calc.w = innerw + lp + rp
    calc.h = innerh + tp + bp

    return expw, exph
end

-- First pass over non-expanded children to compute available width/height
-- remaining to spread between expanded children.
function rtk.Box:_reflow_step1(w, h, clampw, clamph, viewport, window)
    local calc = self.calc
    local orientation = calc.orientation
    local remaining_size = orientation == rtk.Box.HORIZONTAL and w or h

    local expand_units = 0
    local maxw, maxh = 0, 0
    local spacing = 0
    local expw, exph = false, false

    for n, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        local wcalc = widget.calc
        attrs._cellbox = nil
        if widget.id then
            self._child_index_by_id[widget.id] = n
        end
        if widget == rtk.Box.FLEXSPACE then
            expand_units = expand_units + (attrs.expand or 1)
            spacing = 0
        elseif widget.visible == true then
            local ww, wh = 0, 0
            local ctp, crp, cbp, clp = self:_get_cell_padding(widget, attrs)
            -- Fill in the box direction implies expand.
            local fill_box_orientation
            if orientation == rtk.Box.HORIZONTAL then
                fill_box_orientation = attrs.fillw
            else
                fill_box_orientation = attrs.fillh
            end
            attrs._calculated_expand = attrs.expand or (fill_box_orientation and 1) or 0
            if attrs._calculated_expand == 0 and fill_box_orientation then
                log.error('rtk.Box: %s: fill=true overrides explicit expand=0: %s will be expanded', self, widget)
            end
            -- Reflow at 0,0 coords just to get the native dimensions.  Will adjust position in second pass.
            if attrs._calculated_expand == 0 then
                if orientation == rtk.Box.HORIZONTAL then
                    -- Horizontal box
                    local child_maxw = rtk.clamprel(
                        remaining_size - clp - crp - spacing,
                        attrs.minw or wcalc.minw,
                        attrs.maxw or wcalc.maxw
                    )
                    local child_maxh = rtk.clamprel(
                        h - ctp - cbp,
                        attrs.minh or wcalc.minh,
                        attrs.maxh or wcalc.maxh
                    )
                _, _, ww, wh, wexpw, wexph = widget:reflow(
                        0,
                        0,
                        child_maxw,
                        child_maxh,
                        attrs.fillw,
                        -- If stretching to siblings we don't fill at this stage, we'll fill
                        -- in the subclass step2 implementation
                        attrs.fillh and attrs.stretch ~= rtk.Box.STRETCH_TO_SIBLINGS,
                        clampw,
                        clamph,
                        viewport,
                        window
                    )
                    expw = wexpw or expw
                    exph = wexph or exph
                    -- We can expand the child to minw/h (for alignment purposes) but can't
                    -- reduce it to maxw/h (if defined) as only viewports support clipping.
                    ww = math.max(ww, attrs.minw or widget.minw or 0)
                    wh = math.max(wh, attrs.minh or widget.minh or 0)
                    if wexpw and clampw and ww >= child_maxw and n < #self.children then
                        -- This child is non-expanded but now after reflowing it we
                        -- see that it's reporting as having expanded width, and it's
                        -- using all (or more) of the box width we offered.  It could be
                        -- another box that itself has expanded children, for example.
                        --
                        -- Since we're also clamping to width, this means that this child
                        -- will starve subsequent siblings (and we've verified that there
                        -- indeed are some) from space. So this is a bit of a false start:
                        -- we declare this non-explicitly-expanded child as being
                        -- implicitly expanded so that it'll get picked up in the second
                        -- pass. Unfortunately it means a second reflow.
                        attrs._calculated_expand = 1
                    end
                else
                    -- Vertical box
                    local child_maxw = rtk.clamprel(
                        w - clp - crp,
                        attrs.minw or wcalc.minw,
                        attrs.maxw or wcalc.maxw
                    )
                    local child_maxh = rtk.clamprel(
                        remaining_size - ctp - cbp - spacing,
                        attrs.minh or wcalc.minh,
                        attrs.maxh or wcalc.maxh
                    )
                    _, _, ww, wh, wexpw, wexph = widget:reflow(
                        0,
                        0,
                        child_maxw,
                        child_maxh,
                        -- If stretching to siblings we don't fill at this stage, we'll fill
                        -- in the subclass step2 implementation
                        attrs.fillw and attrs.stretch ~= rtk.Box.STRETCH_TO_SIBLINGS,
                        attrs.fillh,
                        clampw,
                        clamph,
                        viewport,
                        window
                    )
                    expw = wexpw or expw
                    exph = wexph or exph
                    -- We can expand the child to minw/h (for alignment purposes) but can't
                    -- reduce it to maxw/h (if defined) as only viewports support clipping.
                    wh = math.max(wh, attrs.minh or widget.minh or 0)
                    ww = math.max(ww, attrs.minw or widget.minw or 0)
                    if wexph and clamph and wh >= child_maxh and n < #self.children then
                        -- Prevent starvation of subsequent children. See comment above.
                        attrs._calculated_expand = 1
                    end

                end
                expw = expw or attrs.fillw
                exph = exph or attrs.fillh
                if attrs._calculated_expand == 0 and wcalc.position & rtk.Widget.POSITION_INFLOW ~= 0 then
                    maxw = math.max(maxw, ww + clp + crp)
                    maxh = math.max(maxh, wh + ctp + cbp)
                    if orientation == rtk.Box.HORIZONTAL then
                        remaining_size = remaining_size - (clampw and (ww + clp + crp + spacing) or 0)
                    else
                        remaining_size = remaining_size - (clamph and (wh + ctp + cbp + spacing) or 0)
                    end
                else
                    expand_units = expand_units + attrs._calculated_expand
                end
            else
                -- FIXME: what do we do about minw/h?   It can eat into remaining size,
                -- causing children to overflow the container.
                expand_units = expand_units + attrs._calculated_expand
            end
            -- Stretch applies to the opposite orientation of the box, unlike expand
            -- which is the same orientation.  So e.g. stretch in a VBox will force the
            -- box's width to fill its parent.
            if orientation == rtk.Box.VERTICAL and attrs.stretch == rtk.Box.STRETCH_FULL then
                maxw = w
            elseif orientation == rtk.Box.HORIZONTAL and attrs.stretch == rtk.Box.STRETCH_FULL then
                maxh = h
            end
            spacing = (attrs.spacing or self.spacing) * rtk.scale
            self:_add_reflowed_child(widgetattrs, attrs.z or wcalc.z or 0)
        else
            widget.realized = false
        end
    end
    self:_determine_zorders()
    local expand_unit_size = expand_units > 0 and (remaining_size / expand_units) or 0
    return maxw, maxh, expand_unit_size, expw, exph
end