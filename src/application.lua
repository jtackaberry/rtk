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

--- A basic application layout with toolbar, center content area, and status bar,
-- with support for navigation between screens.
--
-- Here is an example application ([Reaticulate](https://reaticulate.com)),
-- showing the regions provided by `rtk.Application`:
--
-- ![](../img/application.png)
--
-- @example
--  local window = rtk.Window()
--  local app = window:add(rtk.Application())
--  app:add_screen{
--      name='main',
--      init=function(app, screen)
--          screen.widget = rtk.Text{'Main app content would go here'}
--          screen.widget.onmouseenter = function()
--              app:attr('status', 'This is a pointless status message')
--              -- Indicate this is handled so onmouseleave() gets fired
--              return true
--          end
--          screen.widget.onmouseleave = function()
--              app:attr('status', nil)
--          end
--      end,
--  }
--  app:add_screen{
--      name='settings',
--      init=function(app, screen)
--          screen.widget = rtk.Text{'Settings page content goes here'}
--          -- If you have multiple buttons, you could use a rtk.HBox
--          -- as the toolbar instead.
--          screen.toolbar = rtk.Button{'←   Back', flat=true}
--          screen.toolbar.onclick = function()
--              -- Navigate back to previous screen.
--              app:pop_screen()
--          end
--      end,
--  }
--  -- Create the application-wide toolbar buttons that will be added to the
--  -- right side of the toolbar.
--  --
--  -- This assumes the icon path was previously registered with
--  -- rtk.add_image_search_path() and that 18-settings.png exists there.
--  local settings = app.toolbar:add(rtk.Button{icon='18-settings', flat=true})
--  settings.onclick = function()
--      -- The button just opens the settings page
--      app:push_screen('settings')
--  end
--  window:open()
--
-- @class rtk.Application
-- @inherits rtk.VBox
rtk.Application = rtk.class('rtk.Application', rtk.VBox)
rtk.Application.register{
    --- The text of the status bar, or nil to clear.
    --
    -- @meta read/write
    -- @type string
    status = rtk.Attribute{
        -- This simply proxies to the statusbar widget, so there is no need for any
        -- reflow.  That will happen by setting the statusbar widget text attr.
        reflow=rtk.Widget.REFLOW_NONE
    },

    --- The box that represents the status bar of the Application widget.
    --
    -- If you don't want a statusbar, then simply hide it:
    --   @code
    --      local app = rtk.Application()
    --      app.statusbar:hide()
    --
    -- @meta read-only
    -- @type rtk.HBox
    statusbar = nil,

    --- The box that represents the toolbar of the Application widget.
    --
    -- You can add your own widgets to this box container (usually `rtk.Button`),
    -- and they will be aligned to the top-right of the Application.
    -- Individual screens can add their own widgets to the left-portion
    -- of the toolbar -- see `add_screen()` for details.
    --
    -- @meta read-only
    -- @type rtk.HBox
    toolbar = nil,

    --- The table of screens as registered with `add_screen()`, keyed on the
    -- screen name.  A special `stack` field exists within this table that
    -- indicates the order of the current open screens as managed by
    -- `push_screen()`, `pop_screen()`, and `replace_screen()`.
    --
    -- @code
    --   local app = rtk.Application()
    --   app:add_screen(some_screen_table, 'settings')
    --   app.screens.settings.update()
    --
    -- @meta read-only
    -- @type table
    screens = nil,
}


--- Create a new application with the given attributes.
--
-- @display rtk.Application
function rtk.Application:initialize(attrs, ...)
    self.screens = {
        stack = {},
    }
    self.toolbar = rtk.HBox{
        bg=rtk.theme.bg,
        spacing=0,
        z=110,
    }
    self.toolbar:add(rtk.HBox.FLEXSPACE)
    self.statusbar = rtk.HBox{
        bg=rtk.theme.bg,
        lpadding=10,
        tpadding=5,
        bpadding=5,
        rpadding=10,
        z=110,
    }
    self.statusbar.text = self.statusbar:add(rtk.Text{color=rtk.theme.text_faded, text=""}, {expand=1})
    rtk.VBox.initialize(self, attrs, self.class.attributes.defaults, ...)

    self:add(self.toolbar, {minw=150, bpadding=2})
    -- Placeholder that screens will replace.
    self:add(rtk.VBox.FLEXSPACE)
    self._content_position = #self.children
    self:add(self.statusbar, {fillw=true})

    self:_handle_attr('status', self.calc.status)
end

function rtk.Application:_handle_attr(attr, value, oldval, trigger, reflow)
    local ok = rtk.VBox._handle_attr(self, attr, value, oldval, trigger, reflow)
    if ok == false then
        return ok
    end
    if attr == 'status' then
        -- We aren't affecting widget geometry by setting the label, so just force a partial
        -- reflow.
        self.statusbar.text:attr('text', value or ' ', nil, rtk.Widget.REFLOW_PARTIAL)
    end
    return ok
end

--- Adds a screen to the application, which can later be shown.
--
-- The given `screen` is a Lua table comprised of the following fields:
--   * **init**: a function that will be invoked immediately, which receives two
--     parameters: the `rtk.Application` instance, and the screen table.  Any non-nil
--     value returned by this function will be stored in the `widget` field.  (Alternatively,
--     you are free to set `screen.widget` directly.)
--   * **update** *(optional)*: a function that is invoked when the screen becomes
--     visible (by either `push_screen()` or `replace_screen()` and which receives
--     the same arguments as screen.init().
--   * **widget**: the `rtk.Widget` subclass that is to be the middle content area of
--     the screen.  The widget is added to the Application box @{rtk.Box.expand|expanded},
--     with both @{rtk.Box.fillw|fillw} and @{rtk.Box.fillh|fillh} set to true.  This
--     widget is typically a container widget such as `rtk.VBox` or `rtk.Viewport`.
--   * **toolbar**: the `rtk.Widget` subclass that is to be added to the left side of
--     the application toolbar when the screen is visible, acting as the screen-local
--     toolbar. This is usually an `rtk.HBox` populated with one or more `rtk.Button`
--     widgets.
--   * **name** *(optional)*: the name of the screen (if nil, then the `name` parameter
--      of this method must be passed, and this field will be set to that value)
--
-- @example
--   local app = rtk.Application()
--   app:add_screen{
--       name='settings',
--       init=function(app, screen)
--           -- Create a screen-specific toolbar and add a back button to it,
--           -- which just pops the last screen from the screen stack.
--           screen.toolbar = rtk.HBox()
--           local back = screen.toolbar:add(rtk.Button{'←   Back', flat=true})
--           back.onclick = function()
--               app:pop_screen()
--           end
--           -- Some dummy content
--           local box = rtk.VBox()
--           for i = 1, 100 do
--               box:add(rtk.Text{string.format('Line %d', i)})
--           end
--           return rtk.Viewport{box}
--       end
--   }
--
-- If this is the first screen added, then it will automatically be made visible.
-- Subsequent screens will not be visible unless `push_screen()` or `replace_screen()`
-- are called.
--
-- @tparam table screen the screen to register with the application as described above
-- @tparam string|nil name the name of the screen (which may be nil
function rtk.Application:add_screen(screen, name)
    assert(type(screen) == 'table' and screen.init, 'screen must be a table containing an init() function')
    name = name or screen.name
    assert(name, 'screen is missing name')
    assert(not self.screens[name], string.format('screen "%s" was already added', name))

    local widget = screen.init(self, screen)
    if widget then
        assert(rtk.isa(widget, rtk.Widget), 'the return value from screen.init() must be type rtk.Widget (or nil)')
        screen.widget = widget
    else
        assert(rtk.isa(screen.widget, rtk.Widget), 'screen must contain a "widget" field of type rtk.Widget')
    end
    screen.name = name
    self.screens[name] = screen
    if not screen.toolbar then
        -- Screen did not provide a toolbar, so create a placeholder
        screen.toolbar = rtk.Spacer{h=0}
    end
    -- Set min width for screen toolbar to ensure at least back button is visible
    self.toolbar:insert(1, screen.toolbar, {minw=50})
    screen.toolbar:hide()
    screen.widget:hide()

    if #self.screens.stack == 0 then
        self:replace_screen(screen)
    end
end

function rtk.Application:_show_screen(screen)
    screen = type(screen) == 'table' and screen or self.screens[screen]
    for _, s in ipairs(self.screens.stack) do
        s.widget:hide()
        if s.toolbar then
            s.toolbar:hide()
        end
    end
    assert(screen, 'screen not found, was add_screen() called?')
    if screen then
        if screen.update then
            screen.update(self, screen)
        end
        -- Reset scroll position if the screen widget is a viewport.
        if screen.widget.scrollto then
            screen.widget:scrollto(0, 0)
        end
        screen.widget:show()
        self:replace(self._content_position, screen.widget, {
            expand=1,
            fillw=true,
            fillh=true,
            minw=screen.minw
        })
        screen.toolbar:show()
    end
    self:attr('status', nil)
end


--- Makes the given screen visible, and pushes it to the screen stack.
--
-- After this is called, you can navigate back to the previous screen
-- by calling `pop_screen()`.
--
-- @tparam table|string screen the screen table or name of the screen
function rtk.Application:push_screen(screen)
    screen = type(screen) == 'table' and screen or self.screens[screen]
    assert(screen, 'screen not found, was add_screen() called?')
    if screen and #self.screens.stack > 0 and self:current_screen() ~= screen then
        self:_show_screen(screen)
        self.screens.stack[#self.screens.stack+1] = screen
    end
end

--- Pops the current screen off the screen stack, making the previous
-- screen visible.
--
-- @treturn bool true if the current screen was popped, or false if
--   the current screen is the first screen in the stack and so
--   can't be popped.
function rtk.Application:pop_screen()
    if #self.screens.stack > 1 then
        self:_show_screen(self.screens.stack[#self.screens.stack-1])
        table.remove(self.screens.stack)
        return true
    else
        return false
    end
end

--- Replaces one screen in the screen stack with another.
--
-- @tparam table|string screen the screen table or name of the screen that is to
--   replace the existing one
-- @tparam number|nil idx the index of the screen to replace, where 1 is the screen
--   at the bottom of the stack. If nil, then the current screen is replaced.
function rtk.Application:replace_screen(screen, idx)
    screen = type(screen) == 'table' and screen or self.screens[screen]
    assert(screen, 'screen not found, was add_screen() called?')
    local last = #self.screens.stack
    idx = idx or last
    if idx == 0 then
        idx = 1
    end
    if idx >= last then
        self:_show_screen(screen)
    elseif screen.update then
        screen.update(self, screen)
    end
    -- Must set *after* _show_screen()
    self.screens.stack[idx] = screen
end

--- Returns the table for the current screen.
--
-- This is simply a convenience function for accessing the last element of
-- @{screens|screens.stack}, which includes bounds handling.
--
-- @treturn table|nil the table of the current screen, or nil if
--   `add_screen()` has not yet been called
function rtk.Application:current_screen()
    local n = #self.screens.stack
    if n > 0 then
        return self.screens.stack[#self.screens.stack]
    end
end