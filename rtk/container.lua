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

--- In rtk, containers are special widgets that can hold one or more other
-- widgets (called *children*) and manage their position and dimension according to the
-- semantics of the specific container type.  Containers can be nested to create complex
-- layouts.  And because containers are themselves widgets, the attributes, methods, and
-- event handlers defined by `rtk.Widget` are all applicable here as well.
--
-- `rtk.Container` is the simplest type of container, and serves as the base class to all
-- other container widgets, and so other containers also offer at least this interface.
-- It is a generic, unopinionated container that expects children to specify their
-- geometry (relative to the parent container position).
--
-- Children of containers are placed into **cells**.  A cell is that portion of the container
-- that has been allocated to one child widget.  In an rtk.Container, cells given to child
-- widgets are independent and don't affect one another. Subclasses can and do change this
-- aspect.  For example, @{rtk.Box|box containers} layout children adjacent to each other,
-- so prior siblings will affect the position of later siblings.
--
-- Containers ask their children to constrain their dimensions so that all
-- children can fit within the container (whether the container has an explicit
-- size, or its own bounding box specified by its parent), but sometimes children
-- can ignore these constraints, for example if you have specified an explicit
-- size of a child widget that's larger than the container can hold without
-- itself overflowing.  Containers don't clip their children, rather it's up to the
-- child widgets to clip themselves if necessary (e.g. `rtk.Text.overflow`).
--
-- As with all widgets, container @{geometry} (coordinates and dimensions) can be static
-- values, or specified relative to the parent (e.g. 80% of parent width).
--
-- When no explicit @{rtk.Widget.w|width} or @{rtk.Widget.h|height} is set, a container's
-- *intrinsic size* is dictated by the children contained within it.
--
-- @example
--   -- Create a new container that's 50% the width of its parent.
--   local c = rtk.Container{w=0.5}
--   -- This centers the label within the button but doesn't affect its
--   -- position within the container because it's an attribute on the
--   -- widget itself, not a cell attribute.
--   local b = rtk.Button{label='Hello world', halign='center'}
--   -- Ask the button to fill its container.
--   c:add(b, {fillw=true})
--   -- rtk.Windows are themselves rtk.Containers.  This adds the container
--   -- to the window, and because the container has w=0.5, it will end up
--   -- having a width that's 50% of the window's widget (its parent).
--   -- Meanwhile, these alignment cell attributes center the container
--   -- within the window both horizontally and vertically.
--   window:add(c, {halign='center', valign='center'})
--
--
-- ### Box Model With Containers
--
-- The diagram below depicts how the widget box model works in the context of containers,
-- using a 200px fixed height container.  The blue area represents the cell, while the purple
-- box is the widget itself.
--
-- ![](../img/container-box-model.png)
--
-- The following code generated the above image (minus the dotted border around the text which
-- was added later as a visual aid to denote the boundary of the inner content):
--
-- @code
--   local c = window:add(rtk.Container{h=200, border='4px black'})
--   local text = rtk.Text{'intrinsic\nsize', halign='center', padding=20, bg='purple', border='violet'}
--   c:add(text, {bg='cornflowerblue', padding=30})
--
--
-- ### Cell Alignment
--
-- With `rtk.Container`, cells are all overlaid one atop the other, with either
-- @{rtk.Widget.margin|widget margin} or @{padding|cell padding} affecting the position of
-- each cell.
--
-- Unless the container is given an explicit size, alignment is done relative to the
-- current size of the container based on all *previous* siblings.  For example:
--
-- @code
--   local c1 = rtk.Container()
--   -- Makes a big orange box
--   c1:add(rtk.Spacer{w=0.5, h=0.5, bg='orange'})
--   -- Because the rtk.Spacer widget was first, this button will be
--   -- aligned relative to the previous widget, which dictates the
--   -- current intrinsic size of the container when the button is
--   -- reflowed.
--   c1:add(rtk.Button{'Hello'}, {valign='center', halign='center'})
--
--   -- Meanwhile, let's reverse the order.
--   local c2 = rtk.Container()
--   -- Add the button first, but use a higher z-index so it's drawn above
--   -- the rtk.Spacer.  But here the center alignment is relative to the
--   -- current container size, which is empty.  So it ends up being top/left
--   -- of the container.
--   c2:add(rtk.Button{'Hello', z=1}, {valign='center', halign='center'})
--   -- Now the spacer stretches out the container further, but doesn't affect
--   -- the alignment of the button, which was already decided.
--   c2:add(rtk.Spacer{w=0.5, h=0.5, bg='orange'})
--
-- @class rtk.Container
-- @inherits rtk.Widget
-- @see rtk.HBox rtk.VBox rtk.FlowBox rtk.Window
rtk.Container = rtk.class('rtk.Container', rtk.Widget)

rtk.Container.register{
    --- Cell attributes.
    --
    -- When adding a child to a container (e.g. via `add()`), you can optionally set
    -- additional attributes that control how the container will layout that specific child
    -- widget within its cell.
    --
    -- These are the base layout attributes for all containers, but specific container
    -- implementations usually include additional ones, or may extend the possible values for
    -- these cell attributes, or change the semantics.
    --
    -- @section container.cellattrs
    -- @compact fields

    --- If true, the child widget is asked to fill its width to the right edge of the container
    -- (unless the child itself has an explicitly defined width in which case this cell
    -- attribute is ignored).
    -- @type boolean
    fillw = nil,
    --- Like `fillw` but for height, where the child widget is asked to fill its height to
    -- the bottom edge of the container.
    -- @type boolean
    fillh = nil,
    --- One of the @{alignmentconst|alignment constants} (or a corresponding string, e.g.
    -- `'center'`) that defines how the child widget will be horizontally aligned
    -- within its cell.
    --
    -- @note
    --  Cell alignment is distinct from @{rtk.Widget.halign|widget alignment} because it
    --  controls how the container positions the widget within its cell, but doesn't affect
    --  the visual appearance of the widget itself, while the alignment attributes defined
    --  on child widgets controls how the child displays its contents within its own box.
    --
    --  When @{rtk.Widget.halign|halign} is specified as an attribute on the container widget
    --  overall, it affects the *default* horizontal alignment of all cells.  Cells can
    --  override this default by explicitly specifying the halign cell attribute.
    --
    -- @type alignmentconst
    halign = nil,
    --- Like `halign` but for vertical alignment
    -- @type alignmentconst
    valign = nil,
    --- The amount of padding around the child widget within the cell.  This is equivalent
    -- to @{rtk.Widget.margin|widget margin} and if both are defined then they add together.
    -- Value formats are also the same as `rtk.Widget.padding`.
    -- @type number|table|string
    padding = nil,
    --- Top cell padding in pixels; if specified, overrides `padding` for the top edge of
    -- the cell (default 0).
    -- @type number
    tpadding = nil,
    --- Right padding in pixels; if specified, overrides `padding` for the right edge of
    -- the cell (default 0).
    -- @type number
    rpadding = nil,
    --- Bottom padding in pixels; if specified, overrides `padding` for the bottom edge of
    -- the cell (default 0).
    -- @type number
    bpadding = nil,
    --- Left padding in pixels; if specified, overrides `padding` for the left edge of
    -- the cell (default 0).
    -- @type number
    lpadding = nil,
    --- The minimum cell width allowed for the child widget.  This doesn't necessarily mean
    -- the widget will be this width, rather just that the container will allow the widget
    -- at least this amount of space.  To ensure the widget itself is at least this width,
    -- also specify `fillw`.
    --
    -- Relative values are supported, so for example a value of `0.5` indicates the
    -- child widget in this cell should be offered a box width that is 50% of the
    -- containers own width.
    --
    -- This is distinct from the @{rtk.Widget.minw|minw widget attribute} in that the
    -- `minw` cell attribute dictates how much space the container offers to the child
    -- (its box), while `rtk.Widget.minw` controls how much of that box it will use. In
    -- other words, the two combine together. For example, if the minw cell attribute is
    -- `200`, and the minw widget attribute is 0.5, then the effective minimum width for
    -- the widget will be 100px.
    --
    -- @type number|nil
    minw = nil,
    --- Like `minw` but for height.
    -- @type number|nil
    minh = nil,
    --- The maximum cell width allowed for the child widget.  Unless the widget explicitly
    -- defines a larger width for itself, it is expected to shrink or clip as needed
    -- to fit within this value.
    --
    -- As with `minw`, relative values are supported and may be combined with the
    -- @{rtk.Widget.maxw|maxw widget attribute}.
    --
    -- @type number|nil
    maxw = nil,
    --- Like `maxw` but for height.
    -- @type number|nil
    maxh = nil,
    --- Background of the cell or nil for transparent.  This is different from `rtk.Widget.bg`
    -- in that cell `padding` (or widget `margin`) is also colored.  Opacity of the color
    -- is respected, if specified.
    -- @type colortype|nil
    bg = nil,
    --- The z-index or "stack level" of the child widget, which is exactly equivalent to
    -- `rtk.Widget.z`. If defined, it will override `rtk.Widget.z`.  Widgets at the same
    -- z-index will be drawn in the order they were added to the container, so that
    -- widgets added later will appear above those added before.
    --
    -- The z-index doesn't affect the order widgets are reflowed, only drawn.
    --
    -- @type number
    z=nil,


    --- Class API
    --- @section api

    --- An array of child widgets, where each element in the array is {widget, cell
    -- attributes table}
    -- @meta read-only
    -- @type table
    children = nil,
}

--- Create a new container, initializing with the given attributes.
--
-- Any positional arguments passed will be automatically added as children
-- of the container via `add()`.   In this case, cell attributes can optionally be
-- specified via a `cell` field on the child widget.
--
-- @example
--   local c = rtk.Container{
--       bg='red',
--       padding=10,
--       w=200,
--       rtk.Text{'Some Random Text'},
--       rtk.Button{'I Do Nothing', cell={halign='center'}},
--   }
--
-- Which is equivalent to:
--
-- @code
--   local c = rtk.Container{bg='red', padding=10, w=200}
--   c:add(rtk.Text{'Some Random Text'})
--   c:add(rtk.Button{'I Do Nothing'}, {halign='center'})
--
-- This makes it possible to specify a full widget hierarchy for the entire window (or
-- arbitrary subsections of it) using a single declaration of nested widgets (otherwise
-- known as an S-expression).
--
-- @display rtk.Container
function rtk.Container:initialize(attrs, ...)
    self.children = {}
    -- Maps child id to the index in self.children.  This is nil if the map
    -- needs to be regenerated (it is invalidated whenever a child is added,
    -- removed, or reordered).  It's generated during reflow, or on-demand
    -- in get_child_index()
    self._child_index_by_id = nil
    -- Children from last reflow().  This list is the one that's drawn on next
    -- draw() rather than self.children, in case a child is added or removed
    -- in an event handler just prior to _draw().
    self._reflowed_children = {}
    -- Ordered distinct list of z-indexes for reflowed children.  Generated by
    -- _determine_zorders().  Used to ensure we draw and propagate events to
    -- children in the correct order.
    self._z_indexes = {}
    rtk.Widget.initialize(self, attrs, self.class.attributes.defaults, ...)

    -- Automatically add() any widgets passed as positional arguments
    if attrs and #attrs > 0 then
        for i = 1, #attrs do
            local w = attrs[i]
            self:add(w)
        end
    end
end

function rtk.Container:_handle_mouseenter(event)
    local ret = self:onmouseenter(event)
    if ret ~= false then
        if self.bg or self.autofocus then
            -- We have a background, block widgets underneath us from receiving the event.
            return true
        end
    end
    return ret
end

function rtk.Container:_handle_mousemove(event)
    local ret = rtk.Widget._handle_mousemove(self, event)
    if ret ~= false and self.hovering then
        -- If onmouseenter() above returned true, prevent mouse movements from passing
        -- through to lower z-index widgets.
        event:set_handled(self)
        return true
    end
    return ret
end

function rtk.Container:_draw_debug_box(offx, offy, event)
    if not rtk.Widget._draw_debug_box(self, offx, offy, event) then
        return
    end
    gfx.set(1, 1, 1, 1)
    for i = 1, #self.children do
        local widget, attrs = table.unpack(self.children[i])
        local cb = attrs._cellbox
        if cb and widget.visible then
            gfx.rect(offx + self.calc.x + cb[1], offy + self.calc.y + cb[2], cb[3], cb[4], 0)
        end
    end
end

-- Adds or removes refs from the given child to/from our own refs.  Additions are
-- propagated upward, while removals are not as it shouldn't affect correctness and
-- is faster (and refs are weak anyway)
function rtk.Container:_sync_child_refs(child, action)
    if child.refs and not child.refs.__empty then
        if action == 'add' then
            local w = self
            while w do
                -- Can't use table.merge() as otherwise the internal __self and __empty
                -- fields would get cloned as well, with __self being particularly
                -- problematic.
                for k, v in pairs(child.refs) do
                    if k ~= '__self' and k ~= '__empty' then
                        w.refs[k] = v
                    end
                end
                w = w.parent
            end
        else
            for k in pairs(child.refs) do
                self.refs[k] = nil
            end
        end
    end
end

function rtk.Container:_set_focused_child(child)
    local w = self
    while w do
        w._focused_child = child
        w = w.parent
    end
end

function rtk.Container:_validate_child(child)
    assert(rtk.isa(child, rtk.Widget), 'object being added to container is not subclassed from rtk.Widget')
end

function rtk.Container:_reparent_child(child)
    self:_validate_child(child)
    if child.parent and child.parent ~= self then
        -- Ask current parent (who's not us) to remove this child.
        child.parent:remove(child)
    end
    -- Yay mark and sweep GC!
    child.parent = self
    -- Set the window immediately in case some attribute is subsequently
    -- changed so it is able to request a reflow from the window.
    child.window = self.window
    self:_sync_child_refs(child, 'add')
    if rtk.focused == child then
        self:_set_focused_child(child)
    end
end

function rtk.Container:_unparent_child(pos)
    local child = self.children[pos][1]
    if child then
        if child.visible then
            child:_unrealize()
        end
        child.parent = nil
        child.window = nil
        self:_sync_child_refs(child, 'remove')
        if rtk.focused == child then
            self:_set_focused_child(nil)
        end
        return child
    end
end

function rtk.Container:focused(event)
    return rtk.focused == self or (
        -- If the event is a keypress and the focused widget is a child, we consider
        -- containers focused as well.  This means keypress events not handled by
        -- widgets will be dispatched to their parent container(s).
        event and event.type == rtk.Event.KEY and rtk.focused and rtk.focused == self._focused_child
    )
end

--- Adds a widget to the container.
--
-- The @{container.cellattrs|cell attributes} table is optional, and may be passed either
-- as the second argument, or as the `cell` field in the widget instance itself.
--
-- @code
--   -- Given this box ...
--   local box = rtk.HBox()
--   -- ... these two lines are equivalent
--   box:add(rtk.Text{'Hello World'}, {halign='center', valign='center'})
--   box:add(rtk.Text{'Hello World', cell={halign='center', valign='center'}})
--
-- The second form, while slightly more verbose, may be preferred when you want to dictate
-- the cell behavior at widget instantiation time, rather than during `add()`.
--
-- @tparam rtk.Widget widget the widget to add to the container
-- @tparam table|nil attrs the @{container.cellattrs|cell attributes} to apply to
--   the given widget
function rtk.Container:add(widget, attrs)
    self:_reparent_child(widget)
    self.children[#self.children+1] = {widget, self:_calc_cell_attrs(widget, attrs)}
    -- Invalidate the index cache
    self._child_index_by_id = nil
    self:queue_reflow(rtk.Widget.REFLOW_FULL)
    return widget
end

--- Updates the cell attributes of a previously @{add|added} widget.
--
-- @tparam rtk.Widget widget the widget whose cell attributes are to be updated
-- @tparam table|nil attrs the new @{container.cellattrs|cell attributes}
-- @tparam bool|nil merge if false (default), the cell attributes will be completely
--   replaced with the given attrs, otherwise they will be merged such that previous
--   cell attributes will be preserved unless overridden in attrs.
function rtk.Container:update(widget, attrs, merge)
    local n = self:get_child_index(widget)
    assert(n, 'Widget not found in container')
    attrs = self:_calc_cell_attrs(widget, attrs)
    if merge then
        local cellattrs = self.children[n][2]
        table.merge(cellattrs, attrs)
    else
        self.children[n][2] = attrs
    end
    self:queue_reflow(rtk.Widget.REFLOW_FULL)
end


--- Adds a widget to the container at a specific position.
--
-- For `rtk.Container` containers, it isn't really necessary to insert
-- widgets at specific positions as the @{z|z-index} more easily
-- controls display order.  But for subclasses such as @{rtk.Box|boxes} where
-- widget order is visually relevant and independent of z-index, this method can
-- be used to control the layout of widgets relative to one another.
--
-- @tparam number pos the position of the widget, where 1 inserts at the
--   front of the list.
-- @tparam rtk.Widget widget the widget to insert
-- @tparam table|nil attrs the @{container.cellattrs|cell attributes} to apply to
--   the given widget
function rtk.Container:insert(pos, widget, attrs)
    self:_reparent_child(widget)
    table.insert(self.children, pos, {widget, self:_calc_cell_attrs(widget, attrs)})
    -- Invalidate the index cache
    self._child_index_by_id = nil
    self:queue_reflow(rtk.Widget.REFLOW_FULL)
end

--- Replaces the widget at the given position.
--
-- The existing widget at the given index is unparented from the container and the
-- new widget is added in its place.
--
-- @tparam number index the position of the widget, where 1 is the first widget.
-- @tparam rtk.Widget widget the widget to add to the container that ejects
--   the existing widget at `index`.
-- @tparam table|nil attrs the @{container.cellattrs|cell attributes} to apply to
--   the given widget
-- @treturn rtk.Widget the *old* widget that was removed and replaced by the given one,
--   or nil if the index was out of bounds
function rtk.Container:replace(index, widget, attrs)
    if index <= 0 or index > #self.children then
        return
    end
    local prev = self:_unparent_child(index)
    self:_reparent_child(widget)
    self.children[index] = {widget, self:_calc_cell_attrs(widget, attrs)}
    -- Invalidate the index cache
    self._child_index_by_id = nil
    self:queue_reflow(rtk.Widget.REFLOW_FULL)
    return prev
end

--- Removes a widget by position.
--
-- @tparam number index the widget position to remove, where 1 is the first widget.
-- @treturn rtk.Widget the child that was deleted, or nil if index was out of bounds
function rtk.Container:remove_index(index)
    if index <= 0 or index > #self.children then
        return
    end
    local child = self:_unparent_child(index)
    table.remove(self.children, index)
    -- Invalidate the index cache
    self._child_index_by_id = nil
    self:queue_reflow(rtk.Widget.REFLOW_FULL)
    return child
end

--- Removes a widget from the container.
--
-- @tparam rtk.Widget widget the widget to remove
function rtk.Container:remove(widget)
    local n = self:get_child_index(widget)
    if n ~= nil then
        self:remove_index(n)
        return n
    end
end

--- Empties the container.
function rtk.Container:remove_all()
    for i = 1, #self.children do
        local widget = self.children[i][1]
        if widget and widget.visible then
            widget:_unrealize()
        end
    end
    self.children = {}
    -- Invalidate the index cache
    self._child_index_by_id = nil
    self:queue_reflow(rtk.Widget.REFLOW_FULL)
end


function rtk.Container:_calc_cell_attrs(widget, attrs)
    attrs = attrs or widget.cell
    if not attrs then
        return {}
    end
    -- _calc_attr() could potentially modify the attrs table (for shorthand attributes),
    -- so we need to need to fetch a copy of the current keys and loop over those.
    local keys = table.keys(attrs)
    local calculated = {}
    for n = 1, #keys do
        local k = keys[n]
        -- Set calculated table as target, so shorthand attributes (e.g. padding) get
        -- expanded out to their underlying attributes.
        calculated[k] = self:_calc_attr(k, attrs[k], calculated, nil, 'cell', widget)
    end
    return calculated
end

function rtk.Container:_reorder(srcidx, targetidx)
    if srcidx ~= nil and srcidx ~= targetidx then
        local widgetattrs = table.remove(self.children, srcidx)
        table.insert(self.children, rtk.clamp(targetidx, 1, #self.children + 1), widgetattrs)
        self._child_index_by_id = nil
        self:queue_reflow(rtk.Widget.REFLOW_FULL)
        return true
    else
        return false
    end
end

--- Moves an existing child widget to a new index, shifting surrounding widgets.
--
-- @tparam rtk.Widget widget the widget to be repositioned.
-- @tparam number targetidx the new position for the widget, where 1 is the first cell in
--   the container, 2 is the second cell, and so on.  Out-of-bounds indexes are clamped.
--   If the target index is the same as the widget's current index then no action is
--   taken.
-- @treturn boolean true if the widget if the widget changed positions,
--   or false if the widget was already at targetidx or if the given widget is not in this
--   container
function rtk.Container:reorder(widget, targetidx)
    local srcidx = self:get_child_index(widget)
    return self:_reorder(srcidx, targetidx)
end

--- Moves an existing child widget ahead of another child.
--
-- @tparam rtk.Widget widget the widget to move in front of the target
-- @tparam rtk.Widget target the other child
-- @treturn boolean whether the widget changed positions
function rtk.Container:reorder_before(widget, target)
    local srcidx = self:get_child_index(widget)
    local targetidx = self:get_child_index(target)
    if not srcidx or not targetidx then
        return false
    end
    return self:_reorder(srcidx, targetidx > srcidx and targetidx-1 or targetidx)
end

--- Moves an existing child widget after another child.
--
-- @tparam rtk.Widget widget the widget to move after the target
-- @tparam rtk.Widget target the other child
-- @treturn boolean whether the widget changed positions
function rtk.Container:reorder_after(widget, target)
    local srcidx = self:get_child_index(widget)
    local targetidx = self:get_child_index(target)
    if not srcidx or not targetidx then
        return false
    end
    return self:_reorder(srcidx, srcidx > targetidx and targetidx+1 or targetidx)
end

--- Returns the widget at the given index.
--
-- @tparam number idx the widget position, where 1 is the first widget.
-- @treturn rtk.Widget|nil the widget at the given index, or nil if the index
--   is out of range.
function rtk.Container:get_child(idx)
    if idx < 0 then
        -- Negative indexes offset from end of children list
        idx = #self.children + idx + 1
    end
    local child = self.children[idx]
    if child then
        return child[1]
    end
end

--- Returns the position of the given widget.
--
-- @tparam rtk.Widget widget the widget whose position to fetch
-- @treturn number|nil the index of the given child widget where 1 is the
--   first position, or nil if the child could not be found.
function rtk.Container:get_child_index(widget)
    if not self._child_index_by_id then
        -- Need to generate the index cache on-demand.
        local cache = {}
        for i = 1, #self.children do
            local widgetattrs = self.children[i]
            if widgetattrs and widgetattrs[1].id then
                cache[widgetattrs[1].id] = i
            end
        end
        self._child_index_by_id = cache
    end
    return self._child_index_by_id[widget.id]
end

function rtk.Container:_handle_event(clparentx, clparenty, event, clipped, listen)
    local calc = self.calc
    local x = calc.x + clparentx
    local y = calc.y + clparenty
    -- Update client coordinates so that they're immediately available for user-attached
    -- event handlers.
    self.clientx, self.clienty = x, y
    listen = self:_should_handle_event(listen)

    if y + calc.h < 0 or y > self.window.calc.h or calc.ghost then
        -- Container is not visible
        return false
    end

    -- Set to true below when any of our children have registered mouseover
    local chmouseover
    -- Handle events from highest z-index to lowest, where children at the same z level
    -- are processed in the opposite order they were added.  This is the inverse of the
    -- order they're drawn, to ensure that elements at the same z level which are painted
    -- above others will receive events first.
    local zs = self._z_indexes
    for zidx = #zs, 1, -1 do
        local zchildren = self._reflowed_children[zs[zidx]]
        local nzchildren = zchildren and #zchildren or 0
        for cidx = nzchildren, 1, -1 do
            local widget, attrs = table.unpack(zchildren[cidx])
            -- We're allowed to call _handle_event() on children before they are drawn,
            -- but not before they are reflowed.  We also test that the widget is parented,
            -- and that it wasn't, for example, unparented as part of an event handler
            -- from another widget handling this same event.
            if widget and widget.realized and widget.parent then
                local wx, wy
                if widget.calc.position & rtk.Widget.POSITION_FIXED ~= 0 and self.viewport then
                    -- Handling viewport and non-viewport cases separately here is inelegant in
                    -- how it blurs the layers too much, but I don't see a cleaner way.
                    local vcalc = self.viewport.calc
                    wx, wy = x + vcalc.scroll_left, y + vcalc.scroll_top
                else
                    wx, wy = x, y
                end
                self:_handle_event_child(clparentx, clparenty, event, clipped, listen, wx, wy, widget, attrs)
                chmouseover = chmouseover or widget.mouseover
                -- It's tempting to break if the event was handled, but even if it was, we
                -- continue to invoke the child handlers to ensure that e.g. children no longer
                -- hovering can trigger onmouseleave() or lower z-index children under the mouse
                -- cursor have the chance to declare as hovering.
            end
        end
    end

    -- Give the container itself the opportunity to handle the event.  For example,
    -- if we have a background defined or we're focused, then we want to prevent
    -- mouseover events from falling through to lower z-index widgets that are
    -- obscured by the container.  Also if we're dragging with mouse button
    -- pressed, the container needs to have the opportunity to serve as a drop
    -- target.
    listen = rtk.Widget._handle_event(self, clparentx, clparenty, event, clipped, listen)
    -- Containers are considered in mouseover if any of their children are in mouseover
    self.mouseover = self.mouseover or chmouseover
    return listen
end

function rtk.Container:_handle_event_child(clparentx, clparenty, event, clipped, listen, wx, wy, child, attrs)
    return child:_handle_event(wx, wy, event, clipped, listen)
end

-- Invoked on each child after it has been reflowed and its geometry realized.
function rtk.Container:_add_reflowed_child(widgetattrs, z)
    local z_children = self._reflowed_children[z]
    if z_children then
        z_children[#z_children+1] = widgetattrs
    else
        self._reflowed_children[z] = {widgetattrs}
    end
end

function rtk.Container:_determine_zorders()
    local zs = {}
    for z in pairs(self._reflowed_children) do
        zs[#zs+1] = z
    end
    table.sort(zs)
    self._z_indexes = zs
end

-- Returns top, right, bottom, left padding given cell attributes
function rtk.Container:_get_cell_padding(widget, attrs)
    local calc = widget.calc
    local scale = rtk.scale.value
    return
        ((attrs.tpadding or 0) + (calc.tmargin or 0)) * scale,
        ((attrs.rpadding or 0) + (calc.rmargin or 0)) * scale,
        ((attrs.bpadding or 0) + (calc.bmargin or 0)) * scale,
        ((attrs.lpadding or 0) + (calc.lmargin or 0)) * scale
end

function rtk.Container:_set_cell_box(attrs, x, y, w, h)
    attrs._cellbox = {
        math.round(x),
        math.round(y),
        math.round(w),
        math.round(h)
    }
end

function rtk.Container:_reflow(boxx, boxy, boxw, boxh, fillw, fillh, clampw, clamph, uiscale, viewport, window, greedyw, greedyh)
    local calc = self.calc
    local x, y = self:_get_box_pos(boxx, boxy)
    local w, h, tp, rp, bp, lp, minw, maxw, minh, maxh = self:_get_content_size(
        boxw, boxh, fillw and greedyw, fillh and greedyh, clampw, clamph, nil, greedyw, greedyh
    )
    -- Our default size is the given box without our padding
    local inner_maxw = rtk.clamp(w or (boxw - lp - rp), minw, maxw)
    local inner_maxh = rtk.clamp(h or (boxh - tp - bp), minh, maxh)
    -- Our current inner size that grows as each child is laid out
    local innerw = w or 0
    local innerh = h or 0
    -- If we have a constrained width or height, ensure we tell children to clamp to it
    -- regardless of what our parent told us.
    clampw = clampw or w ~= nil or fillw
    clamph = clamph or h ~= nil or fillh

    self._reflowed_children = {}
    self._child_index_by_id = {}

    for n, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        local wcalc = widget.calc
        attrs._cellbox = nil
        self._child_index_by_id[widget.id] = n
        if widget.visible == true then
            local ctp, crp, cbp, clp = self:_get_cell_padding(widget, attrs)
            -- Calculate effective min/max cell values, which adjusts the scale of
            -- non-relative values when scalability is full, and converts relative sizes
            -- to absolute values relative to the box (inner_maxw/h in this case) when
            -- reflow is greedy.
            attrs._minw = self:_adjscale(attrs.minw, uiscale, greedyw and inner_maxw)
            attrs._maxw = self:_adjscale(attrs.maxw, uiscale, greedyh and inner_maxw)
            attrs._minh = self:_adjscale(attrs.minh, uiscale, greedyh and inner_maxh)
            attrs._maxh = self:_adjscale(attrs.maxh, uiscale, greedyh and inner_maxh)
            local wx, wy, ww, wh = widget:reflow(
                0, 0,
                -- Offered box size takes into account widget's location, we consider
                -- where they would be offset within our box and offer the space to the
                -- far edge of the box.
                rtk.clamp(inner_maxw - widget.x - clp - crp, attrs._minw, attrs._maxw),
                rtk.clamp(inner_maxh - widget.y - ctp - cbp, attrs._minh, attrs._maxh),
                -- We implicitly fill if there's a minimum size defined.
                attrs.fillw,
                attrs.fillh,
                clampw or attrs.maxw ~= nil,
                clamph or attrs.maxh ~= nil,
                uiscale,
                viewport,
                window,
                greedyw,
                greedyh
            )
            -- If minw/minh is specified, we will have offered at least this size of
            -- bounding box to the child, but it may have elected not to use it.  We
            -- size those dimensions back up to minw/minh for alignment purposes below
            -- but don't overwrite the child's size.
            ww = math.max(ww, attrs._minw or 0)
            wh = math.max(wh, attrs._minh or 0)
            -- Calculate effective alignment for this cell, which defaults to the container's
            -- alignment unless explicitly defined.
            attrs._halign = attrs.halign or calc.halign
            attrs._valign = attrs.valign or calc.valign
            -- Alignment below is based on the current intrinsic size based on widget
            -- reflowed before this point (innerw/innerh), but it's also possible for
            -- widgets to overflow the container, so if that's the case we align to
            -- the smaller of the current running size and the bounding box.
            if not attrs._halign or attrs._halign == rtk.Widget.LEFT or not greedyw then
                wx = lp + clp
            elseif attrs._halign == rtk.Widget.CENTER then
                wx = lp + clp + math.max(0, (math.min(innerw, inner_maxw) - ww - clp - crp) / 2)
            else
                -- Right-aligned ignores left cell padding
                wx = lp + math.max(0, math.min(innerw, inner_maxw) - ww - crp)
            end
            if not attrs._valign or attrs._valign == rtk.Widget.TOP or not greedyh then
                wy = tp + ctp
            elseif attrs._valign == rtk.Widget.CENTER then
                wy = tp + ctp + math.max(0, (math.min(innerh, inner_maxh) - wh - ctp - cbp) / 2)
            else
                -- Bottom-aligned ignores top cell padding
                wy = tp + math.max(0, math.min(innerh, inner_maxh) - wh - cbp)
            end
            wcalc.x = wcalc.x + wx
            widget.box[1] = wx
            wcalc.y = wcalc.y + wy
            widget.box[2] = wy
            self:_set_cell_box(attrs, wcalc.x, wcalc.y, ww + clp + crp, wh + ctp + cbp)
            widget:_realize_geometry()

            -- Expand the size of the container according to the child's size
            -- and x,y coordinates offset within the container (now that any
            -- repositioning has been completed caused by alignment above).
            --
            -- We only need to add crp/cbp because clp/ctp is already baked into
            -- calculated x/y.
            innerw = math.max(innerw, wcalc.x + ww - lp + crp)
            innerh = math.max(innerh, wcalc.y + wh - tp + cbp)
            self:_add_reflowed_child(widgetattrs, attrs.z or wcalc.z or 0)
        else
            widget.realized = false
        end
    end

    self:_determine_zorders()

    calc.x = x
    calc.y = y
    calc.w = math.ceil(rtk.clamp((w or innerw) + lp + rp, minw, maxw))
    calc.h = math.ceil(rtk.clamp((h or innerh) + tp + bp, minh, maxh))
end

function rtk.Container:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local x, y = calc.x + offx, calc.y + offy

    if y + calc.h < 0 or y > cliph or calc.ghost then
        -- Container would not be visible on current drawing target
        return false
    end

    -- Our offset into our parent which we pass to our children as parent coordinates.
    local wpx = parentx + calc.x
    local wpy = parenty + calc.y

    self:_handle_drawpre(offx, offy, alpha, event)
    self:_draw_bg(offx, offy, alpha, event)

    -- Draw children from lowest z-index to highest.  Children at the same z level are
    -- drawn in insertion order.
    local child_alpha = alpha * self.alpha
    for _, z in ipairs(self._z_indexes) do
        for _, widgetattrs in ipairs(self._reflowed_children[z]) do
            local widget, attrs = table.unpack(widgetattrs)
            if attrs.bg and attrs._cellbox then
                local cb = attrs._cellbox
                self:setcolor(attrs.bg, child_alpha)
                gfx.rect(x + cb[1], y + cb[2], cb[3], cb[4], 1)
            end
            if widget and widget.realized then
                local wx, wy = x, y
                if widget.calc.position & rtk.Widget.POSITION_FIXED ~= 0 then
                    -- When the child widget is fixed, we ignore our own offset and pass the
                    -- widget's parent coords as its offset.  By ignoring the offset given
                    -- to us, the widget sticks in place.
                    wx, wy = wpx, wpy
                end
                widget:_draw(wx, wy, child_alpha, event, clipw, cliph, cltargetx, cltargety, wpx, wpy)
                widget:_draw_debug_box(wx, wy, event)
            end
        end
    end
    self:_draw_borders(offx, offy, alpha)
    self:_handle_draw(offx, offy, alpha, event)
end

function rtk.Container:_unrealize()
    rtk.Widget._unrealize(self)
    for i = 1, #self.children do
        local widget = self.children[i][1]
        if widget and widget.realized then
            widget:_unrealize()
        end
    end
end