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

--- A utility class that opens an OS-native popup menu.
--
-- Here's an example that opens a context menu when the mouse is right-clicked anywhere
-- in the window.
--
-- @code
--   local menu = rtk.NativeMenu()
--   menu:set({
--       -- Here is an example of passing custom user data (the url field in this case) to
--       -- the handler below.
--       {'Visit Website', id='website', url='https://www.reaper.fm/'},
--       -- The items in the window submenu depend on the js_ReaScriptAPI, so disable
--       -- the entire submenu if that's not available.
--       {'Window', disabled=not rtk.has_js_reascript_api, submenu={
--           -- Use dynamic discovery of the checked value by passing a function.  The custom
--           -- 'win' flag is used by the menu handler later to determine if this is a simple
--           -- boolean window attribute.
--           {'Docked', id='docked', checked=function() return window.docked end, win=true},
--           {'Pinned', id='pinned', checked=function() return window.pinned end, win=true},
--           {'Borderless', id='borderless', checked=function() return window.borderless end, win=true},
--           {'Translucent', id='translucent', checked=function() return window.opacity < 1.0 end},
--       }},
--       rtk.NativeMenu.SEPARATOR,
--       {'Exit', id='exit'},
--   })
--   window.onclick = function(self, event)
--       if event.button == rtk.mouse.BUTTON_RIGHT then
--           menu:open_at_mouse():done(function(item)
--               if not item then
--                   -- User clicked off of menu, nothing selected.
--                   return
--               end
--               if item.id == 'website' then
--                   rtk.open_url(item.url)
--               elseif item.win then
--                   window:attr(item.id, not window[item.id])
--               elseif item.id == 'translucent' then
--                   window:attr('opacity', window.opacity == 1.0 and 0.5 or 1.0)
--               elseif item.id == 'exit' then
--                   rtk.quit()
--               end
--           end)
--       end
--   end
--
-- @class rtk.NativeMenu
rtk.NativeMenu = rtk.class('rtk.NativeMenu')
rtk.NativeMenu.static.SEPARATOR = 0

--- Class API
--
-- @section api

--- Constructor to create a new NativeMenu
--
-- @tparam table menu a menu table as defined by `set()`
-- @treturn rtk.NativeMenu the new instance
-- @display rtk.NativeMenu
function rtk.NativeMenu:initialize(menu)
    self._menustr = nil
    if menu then
        self:set(menu)
    end
end

--- Sets the menu according to the supplied table.
--
-- The table contains a sequence of items, where each individual menu item is itself
-- a table in the form:
--
--  @code
--   {label, id=(any), disabled=(boolean), checked=(boolean), hidden=(boolean), ...}
--
--  where:
--   - `label` (*string*): the label as seen in the popup menu (required).
--        Can be `rtk.NativeMenu.SEPARATOR` to display a separator. Unlike the other
--      fields, this does not need to be explicitly named and can be positional.
--      However, `label='Foo'` is allowed if preferred.
--   - `id` (*any*): an arbitrary (but `tostring()`able) user-defined value
--       which can be accessed via the value returned by the `open()` functions.
--       Optional, but if not specified, the item can be fetched with `item()` using
--       an `index` field that will be added to the item table.
--   - `checked` (*boolean or function*): if true, a checkmark will show next to the item.
--     Optional, and assumes false if not specified.
--   - `disabled` (*boolean or function*): if true, the menu item will be visible but grayed
--     out and cannot be selected. Optional, and assumes false if not specified.
--   - `hidden` (*boolean or function*): if true, the item will not be visible at all in
--     the popup menu. Can be used to easily toggle item visibility without having to
--     reset the menu with `set()`. Optional, and assumes false if not specified.
--   - `...`: you may pass any other named fields in the table as user data and they
--     will be included in the table returned by the open*() functions.
--
-- For fields above so marked, if a function is provided it is invoked at the time the
-- popup menu is opened, which allows for dynamic evaluation of those properties.
--
-- As a convenience, the menu item element can be a string, where it's simply used as the
-- label and all other fields above are assumed nil.
--
-- Submenus are also supported, where the item table takes the form:
--
--  @code
--    {label, submenu=(table), checked=(boolean), disabled=(boolean), hidden=(boolean)}
--
-- where:
--  - `label` (string): the label for the submenu item (required).
--  - `submenu` (table): a table of menu items as described above
--  - `checked` (boolean or function): as above
--  - `disabled` (boolean or function): as above
--  - `hidden` (boolean or function): as above
--
-- Submenus can be aribtrarily nested.
function rtk.NativeMenu:set(menu)
    self.menu = menu
    if menu then
        self:_parse()
    end
end

function rtk.NativeMenu:_parse(submenu)
    self._item_by_idx = {}
    self._item_by_id = {}
    self._order = self:_parse_submenu(self.menu)
end

function rtk.NativeMenu:_parse_submenu(submenu, baseitem)
    local order = baseitem or {}
    for n, menuitem in ipairs(submenu) do
        if type(menuitem) ~= 'table' then
            menuitem = {label=menuitem}
        else
            menuitem = table.shallow_copy(menuitem)
            if not menuitem.label then
                -- If label is passed as the first element, reassign it to the label field.
                menuitem.label = table.remove(menuitem, 1)
            end
        end
        if menuitem.submenu then
            -- Pass this menuitem as the baseitem, so that other fields (especially
            -- user-defined fields) propagate.
            menuitem = self:_parse_submenu(menuitem.submenu, menuitem)
            menuitem.submenu = nil
        elseif menuitem.label ~= rtk.NativeMenu.SEPARATOR then
            local idx = #self._item_by_idx + 1
            menuitem.index = idx
            self._item_by_idx[idx] = menuitem
        end
        if menuitem.id then
            self._item_by_id[tostring(menuitem.id)] = menuitem
        end
        order[#order+1] = menuitem
    end
    return order
end

local function _get_item_attr(item, attr)
    local val = item[attr]
    if type(val) == 'function' then
        return val()
    else
        return val
    end
end

-- Returns the REAPERized menu string for the full menu, as well as a table
-- mapping index to item.
function rtk.NativeMenu:_build_menustr(submenu, items)
    -- Maps index to the item. This needs to be dynamically generated because the
    -- hidden field can also be dynamic and it affects the index offsets.
    items = items or {}
    local menustr = ''
    for n, item in ipairs(submenu) do
        if not _get_item_attr(item, 'hidden') then
            local flags = ''
            if _get_item_attr(item, 'disabled') then
                flags = flags .. '#'
            end
            if _get_item_attr(item, 'checked') then
                flags = flags .. '!'
            end
            if item.label == rtk.NativeMenu.SEPARATOR then
                menustr = menustr .. '|'
            elseif #item > 0 then
                menustr = menustr .. flags .. '>' .. item.label .. '|' .. self:_build_menustr(item, items) .. '<|'
            else
                items[#items + 1] = item
                menustr = menustr .. flags .. item.label .. '|'
            end
        end
    end
    return menustr, items
end

--- Retrieves an individual menu item table by either its user-defined id or its
-- auto-generated index.
--
-- @example
--   local menu = rtk.NativeMenu{'Foo', {'Bar', id='bar'}, 'Baz'}
--   -- We assigned an id to Bar so we can fetch it by its id
--   local bar = menu:item('bar')
--   -- Baz doesn't have its own id, but its the third item in the list so we can
--   -- retrieve it by index.
--   local baz = menu:item(3)
--
-- Note that the table returned (assuming the item is found) is a *shallow copy* of
-- the menu item's table you passed to `set()`.  It will contain all the same fields
-- you provided, but the top-level table itself is a different instance.
--
--  @tparam number|string idx_or_id either the numeric positional index of the menu
--    item (with indices starting at 1 as usual for Lua), or its user-defined id
--  @treturn table|nil the menu item table as passed to `set()` if found (rather, a
--    shallow copy of it), or nil otherwise
function rtk.NativeMenu:item(idx_or_id)
    if not idx_or_id or not self._item_by_idx then
        return nil
    end
    local item = self._item_by_id[tostring(idx_or_id)] or self._item_by_id[idx_or_id]
    if item then
        return item
    end
    -- Item not found by id, try treating it as the direct index.
    return self._item_by_idx[idx_or_id]
end

--- Iterator over all items.
--
-- For submenus, only the inner items are returned here, not the parent item that contains
-- the submenu.  If you need to access the parent item of a submenu, you'll need to ensure
-- it has an `id` field defined and explicitly retrieve it with `item()`.
--
-- @example
--   local menu = rtk.NativeMenu{'Foo', 'Bar', {'Baz', checked=true}}
--   -- Loop over items and invert the checked field for each item
--   for item in menu:items() do
--       item.checked = not item.checked
--   end
--   menu:open_at_mouse()
--
-- @treturn function iterator function
function rtk.NativeMenu:items()
    if not self._item_by_idx then
        return nil
    end
    local i = 0
    local n = #self._item_by_idx
    return function()
        i = i + 1
        if i <= n then
            return self._item_by_idx[i]
        end
    end
end


--- Opens the popup menu at the given window coordinates.
--
-- One noteworthy detail about this method is that it returns an `rtk.Future` and opens
-- the menu asynchronously.  This is because REAPER's underlying function to open menus is
-- blocking, and we want the update cycle to have completed before opening the menu to
-- ensure any related visual state (e.g. a button being pressed) has a chance to draw
-- before the application becomes blocked by the menu.
--
-- @example
--   local menu = rtk.NativeMenu{'Foo', 'Bar', 'Baz'}
--   menu:open(10, 10):done(function(item)
--       if item then
--           log.info('selected item: %s', table.tostring(item))
--       end
--   end)
--
-- @tparam number x the x coordinate for the menu relative to the window,
--   where 0 is far left, and negative values are allowed
-- @tparam number y the y coordinate for the menu relative to the window,
--   where 0 is the top, and negative values are allowed
-- @treturn rtk.Future a Future which is completed when the menu is closed,
--   and which receives either the menu item table of the selected item, or
--   nil if no item was selected
function rtk.NativeMenu:open(x, y)
    rtk.window:request_mouse_cursor(rtk.mouse.cursors.POINTER)
    assert(self.menu, 'menu must be set before open()')
    if not self._order then
        self:_parse()
    end
    local menustr, items = self:_build_menustr(self._order)
    local future = rtk.Future()
    rtk.defer(function()
        gfx.x = x
        gfx.y = y
        local choice = gfx.showmenu(menustr)
        local item
        if choice > 0 then
            item = items[tonumber(choice)]
        end
        -- Bit of a kludge, but as the popup menu is system-modal (such that the rtk event
        -- loop is suspended) there is an edge case where if the menu is triggered by a mouse
        -- click, if the menu is closed by clicking elsewhere, rtk.Window:update() thinks this
        -- was a drag operation. Here we prevent this condition by resetting the drag
        -- candidates.
        rtk._drag_candidates = nil
        -- Cause the window to inject a non-mousedown mousemove event into the widget
        -- hierarchy. We were blocked, and if the mouse moved over some other widget
        -- before the menu is closed by clicking the mouse, we want the new widget to
        -- reflect its hover state, which normally wouldn't happen because of the mouse
        -- button being pressed during the mousemove.
        rtk.window:queue_mouse_refresh()
        future:resolve(item)
    end)
    return future
end


--- Opens the menu at the current mouse position.
--
-- This calls `open()` based on current mouse position.
--
-- @treturn rtk.Future a Future which is completed when the menu is closed,
--   and which receives either the menu item table of the selected item, or
--   nil if no item was selected
function rtk.NativeMenu:open_at_mouse()
    return self:open(gfx.mouse_x, gfx.mouse_y)
end

--- Opens the menu relative to the given widget.
--
-- This calls `open()` based on current widget location and the supplied alignment
-- values (if any).
--
-- @example
--   local menu = rtk.NativeMenu{'Foo', 'Bar', 'Baz'}
--   local button = window:add(rtk.Button{"Open Menu"})
--   button.onclick = function()
--       -- Popup will obscure the button because of top alignment.
--       menu:open_at_widget(button, 'left', 'top')
--   end
--
-- @warning Widget must be drawn
--   The widget must have been @{rtk.Widget.drawn|drawn} or this method will fail
--   because the @{rtk.Widget.clientx|client coordinates} of the widget won't be
--   known.
--
-- @tparam rtk.Widget widget the widget to open the menu in relation to
-- @tparam string|nil halign `'left'` (default if nil) to align the left edge
--   of the menu with the left edge of the widget, or `'right'` to align the
--   left edge of the menu with the right edge of the widget.  (Aligning against
--   the right edge of the menu or centering isn't possible because the menu
--   dimensions are unknown due to it being a native menu.)
-- @tparam string|nil valign `'top`' to align the top edge of the menu with
--   the top edge of the widget, or `'bottom'` (default if nil) to align the
--   top edge of the menu with the bottom edge of the widget.
--
-- @treturn rtk.Future a Future which is completed when the menu is closed,
--   and which receives either the menu item table of the selected item, or
--   nil if no item was selected
--
-- The widget must have been drawn or this will fail because the client
-- coordinates wouldn't be known.
function rtk.NativeMenu:open_at_widget(widget, halign, valign)
    assert(widget.drawn, "rtk.NativeMenu.open_at_widget() called before widget was drawn")
    local x = widget.clientx
    local y = widget.clienty
    if halign == 'right' then
        x = x + widget.calc.w
    end
    if valign ~= 'top' then
        y = y + widget.calc.h
    end
    return self:open(x, y)
end