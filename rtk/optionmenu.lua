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

--- Provides a button (with icon and/or label) with an OS-native popup menu to
-- select from a list of options.
--
-- @example
--   -- Create a new option menu (and add it to some existing box) that shows a
--   -- list of colors.  The idea is that the optionmenu button will take the
--   -- color based on the custom color field, unless that's absent in which
--   -- case it will fall back to id (which is *not* a custom field, that's part
--   -- of the menu spec defined by rtk.NativeMenu).
--   local colors = box:add(rtk.OptionMenu{
--       menu={
--           {'Blue', id='blue', color='cornflowerblue'},
--           {'Red', id='red'},
--           {'Green', id='green', color='seagreen'},
--           {'Purple', id='purple'},
--       },
--   })
--   -- Add a custom handler when the selected item changes and set the button to
--   -- the selected color.
--   colors.onchange = function(self, item)
--       self:attr('color', item.color or item.id)
--   end
--   -- Initialize to blue.  Note here we can use either the id field or the item's
--   -- index (in this case 1). And because we've added the onchange handler above,
--   -- that will fire now as a result of calling this, setting the button to this
--   -- color.
--   colors:select('blue')
--   -- Incidentally, this is equivalent, although a bit less visually streamlined
--   colors:attr('selected', 'blue')
--
-- Which looks like this when open:
--
-- ![](../img/optionmenu.png)
--
-- @class rtk.OptionMenu
-- @inherits rtk.Button
-- @see rtk.NativeMenu rtk.Button
rtk.OptionMenu = rtk.class('rtk.OptionMenu', rtk.Button)
rtk.OptionMenu.static._icon = nil

--- Class API.
--
-- Remember, optionmenus are buttons (styled with the `tagged` attribute set to true), so
-- all the attributes from `rtk.Button` apply here as well.  In particular, the
-- @{rtk.Button.icon|icon} attribute can be used to override the default triangle icon.
--
-- @section api

rtk.OptionMenu.register{
    [1] = rtk.Attribute{alias='menu'},

    --- A table that describes the menu layout per `rtk.NativeMenu` (default nil).  The table
    -- format is the same as that described for `rtk.NativeMenu:set()`.
    --
    -- In addition to all the fields defined by `rtk.NativeMenu:set()`, menu items can also
    -- receive an `altlabel` field, which, if defined, is the label used in the OptionMenu
    -- button when the item is selected (provided `icononly` is false).  This allows different
    -- display strings for the item in the popup menu and the button's label when selected.
    --
    -- @type table
    -- @meta read/write
    menu = nil,
    --- If true, only shows the icon in the button, and not the label of the selected item
    -- (default false). Useful when using as a button-based popup menu, for example as
    -- part of a toolbar.
    --
    -- @type boolean
    -- @meta read/write
    icononly = rtk.Attribute{
        default=false,
        reflow=rtk.Widget.REFLOW_FULL,
    },
    --- The id or index of the selected item (default nil).  You can set this attribute to change
    -- the option menu selection, which is equivalent to calling `select()`.
    --
    -- You may set this attribute to either the menu item id or its index, however when
    -- it's set implicitly after a user changes the selection by selecting an item from
    -- the menu, it will always favor the menuitem's id if it exists, and will fall back
    -- to the item's index if not.  For this reason, you may find it more convenient to
    -- use `selected_index`, `selected_id`, or even `selected_item` as these are unambiguous.
    --
    -- @type string|number
    -- @meta read/write
    selected = nil,

    --- The index of the selected menu item, or nil if nothing is selected (default nil).
    -- This attribute cannot be set; use the `selected` attribute to change the selection.
    -- @type number|nil
    -- @meta read-only
    selected_index = nil,
    --- The user-supplied id of the selected menu item, or nil if nothing is selected or if
    -- the item doesn't have an user-defined id (default nil). This attribute cannot be
    -- set; use the `selected` attribute to change the selection.
    -- @type string|nil
    -- @meta read-only
    selected_id = nil,
    --- The table of the selected menu item, as it was defined in the `menu`, or nil if
    -- nothing is selected (default nil). This attribute cannot be set; use the `selected`
    -- attribute to change the selection.
    -- @type table|nil
    -- @meta read-only
    selected_item = nil,

    -- Override attributes from parent class for our styling.
    icon = rtk.Attribute{
        default=function(self)
            return rtk.OptionMenu.static._icon
        end,
    },
    iconpos = rtk.Widget.RIGHT,
    tagged = true,
    lpadding = 10,
    rpadding = rtk.Attribute{
        -- Reminder: rpadding is a priority attribute (from rtk.Widget), so this will get
        -- evaluated after icononly, which is a non-priority attribute.
        default=function(self)
            -- If icononly, use the same as lpadding (above) to ensure the icon is centered in
            -- the button.
            return (self.icononly or self.circular) and self.lpadding or 7
        end
    },
    tagalpha = 0.15,
}

--- Create a new option menu widget with the given attributes.
-- @display rtk.OptionMenu
function rtk.OptionMenu:initialize(attrs, ...)
    if not rtk.OptionMenu._icon then
        -- Generate a new simple triangle icon for the button.
        local icon = rtk.Image(13, 17)
        icon:pushdest(icon.id)
        rtk.color.set(rtk.theme.text)
        gfx.triangle(2, 6,  10, 6,  6, 10)
        icon:popdest()
        rtk.OptionMenu.static._icon = icon
    end
    rtk.Button.initialize(self, attrs, self.class.attributes.defaults, ...)
    self._menu = rtk.NativeMenu()
    self:_handle_attr('menu', self.calc.menu)
    self:_handle_attr('icononly', self.calc.icononly)
end

-- Return the size of the longest menu item
function rtk.OptionMenu:_reflow_get_max_label_size(boxw, boxh)
    local segments, lw, lh = rtk.Button._reflow_get_max_label_size(self, boxw, boxh)
    -- Determine the widest label in the menu
    local w, h = 0, 0
    -- _reflow_get_max_label_size() above will have set the font for us already.
    for item in self._menu:items() do
        local item_w, item_h = gfx.measurestr(item.altlabel or item.label)
        w = math.max(w, item_w)
        h = math.max(h, item_h)
    end
    -- Expand label width based on the longest item in the list, while still
    -- clamping it to the box size.
    return segments, rtk.clamp(w, lw, boxw), rtk.clamp(h, lh, boxh)
end

--- Selects the current item based on id or index. This is exactly equivalent to setting
-- the `selected` attribute directly, and is only offered as a slightly more readable
-- shorthand.
--
-- @tparam number|string|nil value the user-defined id of the menu item to be selected, or its
--   index.  It can also be nil to programmatically remove the selection.
-- @tparam boolean trigger same as `rtk.Widget:attr()`.
-- @treturn rtk.OptionMenu returns self for method chaining
function rtk.OptionMenu:select(value, trigger)
    return self:attr('selected', value, trigger)
end

function rtk.OptionMenu:_handle_attr(attr, value, oldval, trigger, reflow, sync)
    local ok = rtk.Button._handle_attr(self, attr, value, oldval, trigger, reflow, sync)
    if ok == false then
        return ok
    end
    if attr == 'menu' then
        self._menu:set(value)
        if not self.calc.icononly and not self.selected then
            -- Nothing selected but label should be visible, so set it to the empty string
            -- to ensure _reflow_get_max_label_size() gets called to set the appropriate width.
            self:sync('label', '')
        elseif self.selected then
            -- Something was selected, so now that we've just set a new menu, reevaluate the
            -- selected item.
            self:_handle_attr('selected', self.selected, self.selected, true)
        end
    elseif attr == 'selected' then
        local item = self._menu:item(value)
        self.selected_item = item
        if item then
            if not self.calc.icononly  then
                self:sync('label', item.altlabel or item.label)
            end
            self.selected_index = item.index
            self.selected_id = item.id
            rtk.Button.onattr(self, attr, value, oldval, trigger)
        else
            -- Invalid item, or selection explicitly niled.
            self.selected_index = nil
            self.selected_id = nil
            if not self.calc.icononly then
                self:sync('label', '')
            end
        end
        local last = self._menu:item(oldval)
        -- If the value has changed, fire both onselect and onchange.
        if value ~= oldval and trigger ~= false then
            self:onchange(item, last)
            self:onselect(item, last)
        elseif trigger then
            -- But if trigger is forced, we only fire onselect.  The semantics of onchange
            -- is that forced trigger is ignored.
            self:onselect(item, last)
        end
    end
    return true
end

--- Opens the popup menu programmatically.
--
-- Normally the menu would be opened by the user clicking the button, but it can also
-- be opened programmatically using this method.
--
-- `onchange()` will be fired if the selected item changes.
function rtk.OptionMenu:open()
    assert(self.menu, 'menu attribute was not set on OptionMenu')
    self._menu:open_at_widget(self):done(function(item)
        if item then
            -- We don't use select() as that calls attr() and here we are changing the
            -- attribute from within. Passing true for trigger argument will always fire
            -- onselect() but onchange() only fires if the value actually changed.
            self:sync('selected', item.id or item.index, nil, true)
        end
    end)
end

function rtk.OptionMenu:_handle_mousedown(event)
    local ok = rtk.Button._handle_mousedown(self, event)
    if ok == false then
        return ok
    end
    self:open()
    return true
end


--- Event Handlers.
--
-- See also @{widget.handlers|handlers for rtk.Widget}.
--
-- @section optionmenu.handlers


--- Called when the selection changes.
--
-- This differs from `onselect()` in that this is *only* called when the current selection
-- has changed from the previous value, and the `trigger` argument to `select()` is
-- ignored.
--
-- @tparam table|nil item the table of the menu item as passed to the `menu` attribute,
--   or nil if selection was removed or invalid.  This can only happen if an invalid
--   (or nil) value was programmatically assigned to the `selected` attribute, and cannot
--   happen through user interaction.
-- @tparam table|nil lastitem the item table for the previously selected item that has
--   just been replaced.
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.OptionMenu:onchange(item, lastitem) end


--- Called when `select()` is called, or when the user makes a selection from the
-- popup menu.
--
-- @note
--   This differs from `onchange()` in that this handler is called even when the user's
--   selection is the same as the last selected value.  This is useful when using an
--   rtk.OptionMenu as a popup menu to activate commands in which the last selected
--   item may be invoked multiple times.
--
-- @tparam table|nil item the table of the menu item as passed to the `menu` attribute,
--   or nil if selection was removed or invalid.  This can only happen if an invalid
--   (or nil) value was programmatically assigned to the `selected` attribute, and cannot
--   happen through user interaction.
-- @tparam table|nil lastitem the item table for the previously selected item, which
--   may be the same as the new item if the current item was re-selected.
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.OptionMenu:onselect(item, lastitem) end
