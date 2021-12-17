-- Copyright 2017-2021 Jason Tackaberry
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this qe except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and

local rtk = require('rtk.core')
local log = require('rtk.log')

--- An OS-native window that is to be the root ancestor of all other widgets.
--
-- `rtk.Window` implements the `rtk.Container` interface and behaves like a regular widget,
-- except with certain behaviors adapted for OS windows.  For example, setting geometry
-- attributes (`x`, `y`, `w`, `h`), which normally affects widget layout, here moves and
-- resizes the actual window.  Similarly, `bg` sets the window's overall background color.
--
-- A considerable amount of functionality (particularly the ability to modify the window
-- after it has opened) depends on the js_ReaScriptAPI extension. rtk itself doesn't
-- *require* the extension however, so just be aware when you use some functionality that
-- depends on it (which will be clearly explained in the APIs below).  You will need to be
-- cognizant of whether you want to impose the js_ReaScriptAPI requirement on users of
-- your script based on the dependent functionality you use.
--
-- Due to REAPER's design there can only be one `rtk.Window` per script.
--
-- @code
--  -- Creates a window that defaults to 400x200 and is undocked (because the
--  -- docked attribute defaults to false).
--  local window = rtk.Window{w=400, h=200}
--  -- This works exactly like any other rtk.Container: this will add the
--  -- text widget and center it within the window.
--  window:add(rtk.Text{'Hello world!'}, {halign='center', valign='center'})
--  -- Now open the window which itself is top-center on the screen.  This window
--  -- positioning functionality depends on js_ReaScriptAPI and is a no-op if
--  -- it's not available (i.e. the window will open wherever REAPER or the OS
--  -- chooses to place it).
--  window:open{halign='center', valign='top'}
--
-- ### Closing the Window
--
-- Out of the box, undocked (i.e. floating) windows will be closed when the user hits the
-- escape key while the window is focused.  Or, to be more precise, when there is an
-- *@{rtk.Event.handled|unhandled}* `rtk.Event.KEY` event with an @{rtk.keycodes.ESCAPE|ESCAPE}
-- @{rtk.Event.keycode|keycode} and `docked` is false.  You can override this by
-- explicitly handling this event via `onkeypresspost()`:
--
-- @code
--  local window = rtk.Window()
--  window.onkeypresspost = function(self, event)
--      if not event.handled and event.keycode == rtk.keycodes.ESCAPE and
--         not window.docked then
--          -- Prevent default behavior of escape key closing the window
--          -- by marking the event as handled.
--          event:set_handled(self)
--      end
--  end
--
-- The window will of course also close when the user clicks on the window's OS-native
-- close button (for non-`borderless` windows), or programmatically when you call
-- `rtk.Window:close()`.
--
-- @class rtk.Window
-- @inherits rtk.Container
rtk.Window = rtk.class('rtk.Window', rtk.Container)

--- Dock Constants.
--
-- Used with the `dock` attribute, where lowercase strings of these constants can be used
-- for convenience (e.g. `'bottom'` instead of `rtk.Window.DOCK_BOTTOM`).  These strings
-- are automatically converted to the appropriate numeric constants.
--
-- @section dock
-- @compact

-- Numeric values are an actual docker id, so in order to differentiate between docker
-- ids and these positional constents, we wrap them in a table.
--
-- This function nonsense below is because LDoc is complete clusterfuck and doesn't
-- actually let you assign those table values directly.

--- Find the first docker that is attached to the *bottom* of the main window.
-- @meta 'bottom'
rtk.Window.static.DOCK_BOTTOM = (function() return {0} end)()
--- Find the first docker that is attached to the *left* of the main window.
-- @meta 'left'
rtk.Window.static.DOCK_LEFT =  (function() return {1} end)()
--- Find the first docker that is attached to the *top* of the main window.
-- @meta 'top'
rtk.Window.static.DOCK_TOP =  (function() return {2} end)()
--- Find the first docker that is attached to the *right* of the main window.
-- @meta 'right'
rtk.Window.static.DOCK_RIGHT =  (function() return {3} end)()
--- Find the first docker that that is not attached to the main window.
-- @meta 'floating'
rtk.Window.static.DOCK_FLOATING =  (function() return {4} end)()

function rtk.Window.static._make_icons()
    -- TODO: support different scales
    -- Total dimensions of icon
    local w, h = 12, 12
    -- Size of dots and distance between them
    local sz = 2

    local icon = rtk.Image(w, h)
    icon:pushdest()
    rtk.color.set(rtk.theme.dark and {1, 1, 1, 1} or {0, 0, 0, 1})
    for row = 0, 2 do
        for col = 0, 2 do
            local n = row*3 + col
            if n == 2 or n >= 4 then
                gfx.rect(2*col*sz, 2*row*sz, sz, sz, 1)
            end
        end
    end
    icon:popdest()
    rtk.Window.static._icon_resize_grip = icon
end

--- Class API.
-- @section api
rtk.Window.register{
    -- XXX: on geometry: x/y attributes are synced to real window coordinates, but are
    -- always calculated as 0 because those calculcated attributes are used for
    -- positioning children within the window.  Similarly w/h is synced based on real
    -- window size, but the calculcated versions include a reduction for any padding.

    --- The x screen coordinate of the window when undocked (default 0).  When this attribute
    -- is @{rtk.Widget.attr|set} the window will be moved only if it's undocked, but when
    -- an undocked window is moved by the user, this attribute is also updated to reflect
    -- the current screen position.
    --
    -- Setting after `open()` is called requires the js_ReaScriptAPI extension.
    --
    -- Tip: you can call @{rtk.Widget.move|move}() to set both `x` and `y` at the same time.
    --
    -- @meta read/write
    -- @type number
    x = rtk.Attribute{
        -- Unlike normal x/y coords for widgets, window position doesn't affect layout
        type='number',
        reflow=rtk.Widget.REFLOW_NONE,
        window_sync=true,
    },
    --- Like `x` but for the y screen coordinate where y=0 represents the *top* of the
    -- screen (even on Mac) (default 0).  Normally with Mac y coordinates are relative
    -- to the bottom of the screen, but with rtk this detail is abstracted away and
    -- all y coordinates are relative to the top of the display regardless of platform.
    -- @meta read/write
    -- @type number
    y = rtk.Attribute{
        type='number',
        reflow=rtk.Widget.REFLOW_NONE,
        window_sync=true,
    },
    --- The current width of the window. If the window is undocked, then this attribute is
    -- also settable.  If set before `open()` then it defines the initial width of the
    -- window if undocked, but has no effect on the width of docked windows (as REAPER
    -- doesn't allow that).
    --
    -- Setting a value *after* `open()` is possible but only when (you guessed it) the
    -- window is undocked, and this requires the js_ReaScriptAPI extension.
    --
    -- `minw` is respected and the window will not be allowed a smaller widget.
    --
    -- Tip: you can call @{rtk.Widget.resize|resize}() to set both `w` and `h` at the same
    -- time.
    --
    -- @meta read/write
    -- @type number
    w = rtk.Attribute{
        default=800,
        type='number',
        window_sync=true,
        calculate=function(self, attr, value, target)
            return math.max(self.minw or 100, value or 0)
        end,
    },
    --- Like `w` but for the window height.
    --
    -- `minh` is respected and the window will not be allowed a smaller height.
    --
    -- @meta read/write
    -- @type number
    h = rtk.Attribute{
        window_sync=true,
        default=600,
        calculate=function(self, attr, value, target)
            return math.max(self.minh or 30, value or 0)
        end,
    },

    --- Sets the visibility of the detached window when undocked (default true).
    --
    -- This requires the js_ReaScriptAPI extension to be available in order to work,
    -- otherwise setting this is a no-op.  This attribute can be set directly, or you can
    -- use the `hide()`, `show()`, or `toggle()` convenience methods.
    -- @meta read/write
    -- @type boolean
    visible = rtk.Attribute{
        window_sync=true,
    },
    --- True if the window is docked and false otherwise (default false).  This is
    -- updated to reflect externally-caused changes to the dock state, but can also
    -- be set to dock or undock the window, and when set to true is is combined with
    -- `dock` to decide where to dock the window.
    -- @meta read/write
    -- @type boolean
    docked = rtk.Attribute{
        default=false,
        window_sync=true,
        -- A reflow will be triggered if the dimensions actually change, which is
        -- automatically detected after docking or undocking.
        reflow=rtk.Widget.REFLOW_NONE,
    },
    --- The id of the docker to which this window is (or, when @{rtk.Widget.attr|set}, will
    -- become) attached when `docked` is true (default `'right'`).  This is updated to
    -- reflect the current docker id when the user moves the window between dockers, but
    -- can also be set to cause the window to programmatically move between dockers.
    --
    -- The value is either a numeric docker id to target a specific docker, or one of the
    -- @{rtk.Window.DOCK_BOTTOM|dock position constants} which will search for a docker
    -- that's attached to the main window in the given position. If no docker can be found
    -- at that position, then then the first docker window will be used as a last resort.
    -- @meta read/write
    -- @type number
    dock = rtk.Attribute{
        default=rtk.Window.DOCK_RIGHT,
        calculate={
            bottom=rtk.Window.DOCK_BOTTOM,
            left=rtk.Window.DOCK_LEFT,
            top=rtk.Window.DOCK_TOP,
            right=rtk.Window.DOCK_RIGHT,
            floating=rtk.Window.DOCK_FLOATING
        },
        window_sync=true,
        reflow=rtk.Widget.REFLOW_NONE,
    },
    --- If true, undocked windows will be pinned (i.e. they are always on top) and
    -- if false the window ordering works as usual (default false).
    --
    -- This requires js_ReaScriptAPI extension to work and without it is always false.
    --
    -- @note UI for toggling the pin
    --  Note that due to a limitation with js_ReaScriptAPI, the pin button will not be
    --  visible on the window title bar.  It's up to you to provide some facility for
    --  the user to pin, such as a toolbar button that toggles this attribute.
    --
    --  (The js_ReaScriptAPI limitation is that it provides no means of *removing* the pin
    --  after it's attached, and therefore conflicts with the `borderless` attribute.
    --  You are free to call `reaper.JS_Window_AttachTopmostPin()` explicitly yourself,
    --  passing it the window's `hwnd`, just be aware that the pin will persist and
    --  render oddly if `borderless` is subsequently set to true, at least on Windows.)
    --
    -- @meta read/write
    -- @type boolean
    pinned = rtk.Attribute{
        default=false,
        window_sync=true,
        calculate=function(self, attr, value, target)
            return rtk.has_js_reascript_api and value
        end,
    },
    --- If true, undocked windows will not show the OS-native window frame (default false).
    -- When borderless, a resize grip will be shown on the bottom right corner of the
    -- window to allow the window to be resizable, and also if the user clicks and drags
    -- along the top edge of the window it can be moved.
    --
    -- This requires the js_ReaScriptAPI extension and without it is always false.
    --
    -- Tip: if you put widgets along the top edge of the window (e.g. a row of buttons
    -- acting as a toolbar) you can prevent click-dragging of these widgets from also
    -- moving the window by attaching to those widgets a custom
    -- @{rtk.Widget.ondragstart|ondragstart} handler that returns false.
    -- @meta read/write
    -- @type boolean
    borderless = rtk.Attribute{
        default=false,
        window_sync=true,
        calculate=rtk.Reference('pinned')
    },

    [1] = rtk.Attribute{alias='title'},
    --- The title of the window shown in the OS-native window frame (default "REAPER
    -- Application").
    --
    -- Setting after `open()` is called requires the js_ReaScriptAPI extension, otherwise
    -- the change is ignored.
    --
    -- This attribute may be passed as the first positional argument during initialization.
    --
    -- @meta read/write
    -- @type string
    title = rtk.Attribute{
        default='REAPER application',
        reflow=rtk.Widget.REFLOW_NONE,
        window_sync=true,
    },
    --- The opacity of the full window at the OS level, which affects how the window is
    -- composited by the OS (default 1.0).
    --
    -- This is distinct from `alpha`, which affects how all widgets within the window are
    -- blended on top of the @{rtk.Widget.bg|background color}, because `opacity` can make
    -- the entire window translucent, including the window frame (assuming `borderless` is
    -- false).
    --
    -- Requires the js_ReaScriptAPI extension, otherwise this attribute is entirely ignored.
    -- @meta read/write
    -- @type number
    opacity = rtk.Attribute{
        default=1.0,
        -- Force no reflow at all as this only affects drawing
        reflow=rtk.Widget.REFLOW_NONE,
        window_sync=true,
    },

    --- The handle of the `rtk.Window` which is set once `open()` is called.
    --
    -- This requires the js_ReaScriptAPI extension and is nil if it's not installed.
    -- @meta read-only
    -- @type userdata
    hwnd = nil,
    --- True if the mouse is positioned within the `rtk.Window` and false otherwise.
    --
    -- @warning Occlusion detection
    --   Detecting window occlusion (i.e. where another window is above the rtk.Window)
    --   requires the js_ReaScriptAPI extension.  When the extension is available, if
    --   the mouse cursor is positioned in the occluding window's region, `in_window`
    --   will be false.  However when the extension is *not* available, `in_window` will
    --   always be true when the cursor is within the window geometry, even if there are
    --   other windows placed above rtk.Window.
    --
    -- @meta read-only
    -- @type boolean
    in_window = false,
    --- True if the `rtk.Window` currently holds keyboard focus.
    --
    -- This requires the js_ReaScriptAPI extension and if it's not installed will always
    -- be true.
    -- @meta read-only
    -- @type boolean
    is_focused = not rtk.has_js_reascript_api and true or false,
    --- True if the window's main event loop is running. `close()` will set this to false.
    -- @meta read-only
    -- @type boolean
    running = false,


    -- Overrides
    cursor = rtk.mouse.cursors.POINTER,
    minw = 100,
    minh = 30,
    scalability = rtk.Widget.BOX,
}

--- Create a new window with the given attributes.
--
-- @display rtk.Window
function rtk.Window:initialize(attrs, ...)
    rtk.Container.initialize(self, attrs, self.class.attributes.defaults, ...)

    -- Singleton window
    rtk.window = self
    -- For window assignment when adding children
    self.window = self

    -- If the window is the first widget created and we have a background defined, and the
    -- user didn't already explicitly call rtk.set_theme(), then we reinitialize the theme
    -- based on this color.
    if self.id == 0 and self.calc.bg and rtk.theme.default then
        rtk.set_theme_by_bgcolor(self.calc.bg)
    end
    if rtk.Window.static._icon_resize_grip == nil then
        rtk.Window._make_icons()
    end

    if not rtk.has_js_reascript_api then
        -- Regardless of what was requested, without JS_ReascriptAPI we can't support
        -- these attributes.
        self.borderless = false
        self.pinned = false
    end

    --
    -- Internal only
    --
    -- Last observed dockstate from gfx.dock()
    self._dockstate = 0
    -- After drawing, the window contents is blitted to this backing store as an
    -- optimization for subsequent UI updates where no event has occured.
    self._backingstore = rtk.Image(self.w, self.h)
    -- Reusable event object
    self._event = rtk.Event()
    -- Whether a reflow is required on next update
    self._reflow_queued = false
    -- Set of specific widgets that need to be reflowed on next update.  If
    -- _reflow_queued is true but this value is nil then the entire scene is
    -- reflowed.
    self._reflow_widgets = nil
    -- If true, must blit on next update, even if no draw was needed.
    self._blits_queued = 0
    -- Whether a full redraw is needed on next update.
    self._draw_queued = false
    -- Whether queue_mouse_refresh() was called.
    self._mouse_refresh_queued = false
    -- If true, we update OS window attributes on the next update().  This is true when
    -- one of the attributes with window_sync=true are set.
    self._sync_window_attrs_on_update = false

    -- For borderless windows
    self._resize_grip = nil
    self._move_grip = nil
    -- Calculated in _get_hwnd() if jsReascriptAPI exists
    self._os_window_frame_width = 0
    self._os_window_frame_height = 0
    -- Stored geometry of the undocked window so that it can be restored when
    -- undocked.  Set by _handle_dock_change()
    self._undocked_geometry = nil
    -- Same, but for undocked non-maximized geometry (borderless windows only)
    self._unmaximized_geometry = nil

    -- Mouse movement tracking for tooltips
    self._last_mousemove_time = nil
    -- Keep track of when the mouse was last released to deter drag-and-drop
    -- immediately following a mouse click.  See _handle_window_event()
    self._last_mouseup_time = 0
    -- Number of currently scrolling viewports based on calls to _set_touch_scrolling() by
    -- rtk.Viewport, and used to tweak certain event behaviors.
    self._touch_scrolling = {count=0}
end

function rtk.Window:_handle_attr(attr, value, oldval, trigger)
    local ok = rtk.Widget._handle_attr(self, attr, value, oldval, trigger)
    if ok == false then
        return ok
    end
    if attr == 'bg' then
        local color = rtk.color.int(value or rtk.theme.bg)
        gfx.clear = color
        if rtk.has_js_reascript_api then
            if self._gdi_brush then
                reaper.JS_GDI_DeleteObject(self._gdi_brush)
                reaper.JS_GDI_DeleteObject(self._gdi_pen)
            else
                reaper.atexit(function()
                    reaper.JS_GDI_DeleteObject(self._gdi_brush)
                    reaper.JS_GDI_DeleteObject(self._gdi_pen)
                end)
            end
            color = rtk.color.flip_byte_order(color)
            self._gdi_brush = reaper.JS_GDI_CreateFillBrush(color)
            self._gdi_pen = reaper.JS_GDI_CreatePen(1, color)
        end
    end
    if self.class.attributes.get(attr).window_sync then
        self._sync_window_attrs_on_update = true
    end

    return true
end

function rtk.Window:_get_dockstate_from_attrs()
    local calc = self.calc
    local dock = calc.dock
    if type(dock) == 'table' then
        dock = self:_get_docker_at_pos(dock[1])
    end
    local dockstate = (dock or 0) << 8
    if calc.docked and calc.docked ~= 0 then
        dockstate = dockstate | 1
    end
    return dockstate
end

function rtk.Window:_get_docker_at_pos(pos)
    for i = 1, 20 do
        if reaper.DockGetPosition(i) == pos then
            return i
        end
    end
end

-- Fills a region with the background color using low level GDI operations
-- to mitigate unsightly flickering during window open and resizing.
--
-- This comes in two flavors: when we are resizing, in which case the
-- startw/starth parameters indicate the previous window geometry, and
-- on initial window open, where startw/starth are not known (nil).  In
-- the former case, we only draw two rectangles covering the delta of the
-- expanded window portion before we are able to properly reflow and blit.
-- This prevents flickering of the entire window.
function rtk.Window:_clear_gdi(startw, starth)
    -- Apart from needing js_ReaScriptAPI, this really only seems to do any
    -- good on Windows.  OS X has no artifacting, and this doesn't help
    -- at all on Linux.
    if not rtk.os.windows or not rtk.has_js_reascript_api or not self.hwnd then
        return
    end
    local calc = self.calc
    local dc = reaper.JS_GDI_GetWindowDC(self.hwnd)
    reaper.JS_GDI_SelectObject(dc, self._gdi_brush)
    reaper.JS_GDI_SelectObject(dc, self._gdi_pen)
    local r, w, h = reaper.JS_Window_GetClientSize(self.hwnd)
    if not startw then
        reaper.JS_GDI_FillRect(dc, 0, 0, w*2, h*2)
    elseif w > startw or h > starth then
        if not calc.docked and not calc.borderless then
            startw = startw + self._os_window_frame_width
            starth = starth + self._os_window_frame_height
        end
        -- We have an existing rectangle defined by startw/starth we don't want to paint
        -- over, so just draw the two strips on the far right and bottom edges.
        reaper.JS_GDI_FillRect(dc, math.round(startw), 0, w*2, h*2)
        reaper.JS_GDI_FillRect(dc, 0, math.round(starth), w*2, h*2)
    end
    reaper.JS_GDI_ReleaseDC(self.hwnd, dc)
end

--- Focuses the window so it receives subsequent keyboard events.
--
-- This requires the js_ReaScriptAPI extension to be available in order to work.
-- Note that likewise `onfocus()` and `onblur()` event handlers at the `rtk.Window`
-- level require js_ReaScriptAPI as well.
--
-- @treturn bool returns true the the js_ReaScriptAPI extension was available,
--  and false otherwise.
function rtk.Window:focus()
    if self.hwnd and rtk.has_js_reascript_api then
        reaper.JS_Window_SetFocus(self.hwnd)
        self:queue_draw()
        return true
    else
        return false
    end
end

function rtk.Window:_run()
    self:_update()
    if self.running then
        rtk.defer(self._run, self)
    end
end

-- Fetches the resolution of the display where the top left corner of the window appears.
function rtk.Window:_get_display_resolution()
    -- Here we use user-provided attributes instead of calculated values in case a move was
    -- requested.
    local x2 = self.x + (self.w or 0)
    local y2 = self.y + (self.h or 0)
    if rtk.has_sws_extension then
        local l, t, r, b = reaper.BR_Win32_GetMonitorRectFromRect(0, self.x, self.y, x2, y2)
        return l, t, r - l, math.abs(b - t)
    elseif rtk.has_js_reascript_api then
        local l, t, r, b = reaper.JS_Window_GetViewportFromRect(self.x, self.y, x2, y2, 0)
        return l, t, r - l, math.abs(b - t)
    else
        return nil, nil
    end
end

function rtk.Window:_get_geometry_from_attrs(overrides)
    local x, y = self.x, self.y
    local w, h = self.w, self.h
    if overrides then
        -- This returns nil if the resolution can't be determined.
        local _, _, sw, sh = self:_get_display_resolution()
        if sw and sh then
            if overrides.halign == rtk.Widget.CENTER then
                x = (overrides.x or x) + (sw - w) / 2
            elseif overrides.halign == rtk.Widget.RIGHT then
                x = (overrides.x or x) + sw - w
            end
            if overrides.valign == rtk.Widget.CENTER then
                y = (overrides.y or y) + (sh - h) / 2
            elseif overrides.valign == rtk.Widget.BOTTOM then
                y = (overrides.y or y) + sh - h
            end
        end
    end
    return math.round(x), math.round(y), math.round(w), math.round(h)
end

-- Returns a screen y coordinate appropriate for the current OS.  On
-- Linux and Windows, this just returns back the given y.
--
-- On Mac, this translates the coordinate such that y=0 represents the
-- bottom of the screen.
--
-- The offset can be provided if we need to subtract an additional value, e.g. to
-- determine the top of a window as opposed to the bottom.

-- No point in bothering to check rtk.os.mac on each invocation.  And if we don't
-- have any extension available that can help us determine display resolution,
-- we're stuck.
if not rtk.os.mac or not (rtk.has_sws_extension or rtk.has_js_reascript_api) then
    function rtk.Window:_get_os_native_y(y, offset)
        return y
    end
else
    function rtk.Window:_get_os_native_y(y, offset)
        if not rtk.os.mac then
            return y
        end
        if not self._screenh then
            _, _, _, self._screenh = self:_get_display_resolution()
        end
        return self._screenh - y - (offset or 0)
    end
end

function rtk.Window:_sync_window_attrs(overrides)
    local calc = self.calc
    local resized
    local dockstate = self:_get_dockstate_from_attrs()
    if dockstate ~= self._dockstate then
        gfx.dock(dockstate)
        local r, w, h = reaper.JS_Window_GetClientSize(self.hwnd)
        -- If we undocked, _handle_dock_change() will restore the saved undocked geometry.
        -- below, _get_geometry_from_attrs() will ensure we resize to the desired
        -- size.
        self:_handle_dock_change(dockstate)
        if calc.docked then
            -- But if we just docked, then let's immediately store the new docked geometry in
            -- the w/h attributes so that our next reflow has the proper size.
            self.w, self.h = w, h
            calc.w, calc.h = w, h
            gfx.w, gfx.h = w, h
            -- Force resized now as the comparisons later won't be able to tell that
            -- we did, having just replaced the w/h attrs.
            resized = 1
        end
        -- _handle_dock_change() calls us back, but on the re-call self._dockstate will
        -- properly reflect current dockstate so this conditional path won't be
        -- taken again.
        return
    end

    if not rtk.has_js_reascript_api or not self.hwnd then
        -- This function depends entirely on the jsReaScriptAPI.
        return
    end

    if self._resize_grip then
        self._resize_grip:hide()
    end

    if not self.docked then
        if not calc.visible then
            reaper.JS_Window_Show(self.hwnd, 'HIDE')
            return
        end
        local style = 'SYSMENU,DLGSTYLE,BORDER,THICKFRAME,CAPTION'
        if self.borderless then
            style = 'POPUP'
            self:_setup_borderless()
            if not self.realized then
                -- On the initial window open we need to resize to original dimensions to
                -- account for the lack of window border.  This only seems to be necessary
                -- on first open, as toggling the window border preserves window geometry.
                --
                -- Unfortunately this causes a background flicker on Windows that I can't
                -- seem to hack around.  Mac and Linux are ok though.
                reaper.JS_Window_Resize(self.hwnd, self.w, self.h)
            end
            self._resize_grip:show()
        end
        local function restyle()
            reaper.JS_Window_SetStyle(self.hwnd, style)
            -- Although we don't call JS_Window_AttachTopmostPin() ourselves (due to the
            -- issue mentioned earlier), we want to leave it open to the user to explicitly
            -- call it.  But it turns out this only works when the window style has the
            -- WS_POPUP flag, except that this is not exposed as a style string.  ('POPUP'
            -- also implies disabling CAPTION|CHILD which isn't what we want.)  So here we
            -- explicitly add WS_POPUP to the style bitmap.
            local n = reaper.JS_Window_GetLong(self.hwnd, 'STYLE')
            reaper.JS_Window_SetLong(self.hwnd, 'STYLE', n | 0x80000000)
            reaper.JS_Window_SetZOrder(self.hwnd, calc.pinned and 'TOPMOST' or 'NOTOPMOST')
        end
        -- Calling SetStyle() will implicitly show the window if it's currently hidden.  If
        -- the window is already visible, we immediately apply the style to reduce the time
        -- a window border is visible (assuming we're borderless).  But if the window is
        -- hidden, then we defer showing it until after we have done a reflow.
        if reaper.JS_Window_IsVisible(self.hwnd) then
            restyle()
        else
            -- We return if calc.visible is false above, so if we're here, it means the
            -- window is currently hidden but we've been asked to show it.  Hence we
            -- defer that until after the upcoming reflow.
            rtk.defer(restyle)
        end

        -- Resize/move window and set opacity.
        local x, y, w, h = self:_get_geometry_from_attrs(overrides)
        if not resized then
            if w == gfx.w and h == gfx.h then
                -- No change to dimensions
                resized = 0
            elseif w <= gfx.w and h <= gfx.h then
                -- One or both got smaller
                resized = -1
            elseif w > gfx.w or h > gfx.h then
                -- Either got bigger
                resized = 1
            end
        end
        local r, lastx, top, _, _ = reaper.JS_Window_GetRect(self.hwnd)
        local lasty = self:_get_os_native_y(top)
        local moved = r and (self.x ~= lastx or self.y ~= lasty)
        if moved or resized ~= 0 then
            local sw, sh = w, h
            -- JS_Window_SetPosition() requires outer dimensions, not inner content size, so
            -- unless we're borderless we need to account for the window frame.
            if not calc.borderless then
                sw = w + self._os_window_frame_width
                sh = h + self._os_window_frame_height
            end
            local sx = x
            local sy = self:_get_os_native_y(y, h + self._os_window_frame_height)
            reaper.JS_Window_SetPosition(self.hwnd, sx, sy, sw, sh)
        end
        -- update() only fires onresize when the window resized from external
        -- causes (like the user manually resizing), whereas here we are resizing
        -- due to attribute changes.
        if resized ~= 0 then
            self:onresize(gfx.w, gfx.h)
            -- Override values from gfx.update() so we don't double-reflow in update()
            gfx.w = w
            gfx.h = h
            -- But since we're skipping that unnecessary second reflow, we do need to force
            -- a blit to make sure the window is properly drawn after having been resized.
            self:queue_blit()
        end
        -- As with onresize(), we manually fire onmove().
        if moved then
            -- We moved based on self.x/y but we replace the values to ensure they are
            -- rounded to the nearest pixel.
            --
            -- Note that calculated x/y are not set as they are always 0 for windows.
            self.x, self.y = x, y
            self:onmove(lastx, lasty)
        end
        reaper.JS_Window_SetOpacity(self.hwnd, 'ALPHA', calc.opacity)
        reaper.JS_Window_SetTitle(self.hwnd, calc.title)
    else
        -- We're docked so we need to revert opacity lest we affect the main Reaper
        -- window.  Unfortunately it's not enough to just pass 1.0 to SetOpacity()
        -- as this results in annoying flickering when the docker panel is resized.
        -- Here we drop the WS_EX_LAYERED window style to properly revert the opacity.
        local flags = reaper.JS_Window_GetLong(self.hwnd, 'EXSTYLE')
        flags = flags & ~0x00080000 -- WS_EX_LAYERED
        reaper.JS_Window_SetLong(self.hwnd, 'EXSTYLE', flags)
    end
    return resized or 0
end

--- Opens the window and begins the main event loop.  Once called, the application
-- will continue running until `close()` is called.
--
-- The `attrs` parameter allows one to control window placement beyond the
-- standard `x` and `y` attributes.  You can think of this as analogous to
-- cell attributes when @{rtk.Container.add|adding widgets to containers} except
-- this applies to the `rtk.Window` at the OS level.
--
-- Currently @{rtk.Widget.halign|halign} and @{rtk.Widget.valign|valign} attributes are
-- supported.  This, as with all special `rtk.Window` functionality, depends on the
-- js_ReaScriptAPI extension being available.  If it's not installed, then the
-- placement attributes will be ignored.
--
-- @code
--   local window = rtk.Window()
--   window:open{halign='center', valign='center'}
--
-- @tparam table|nil attrs an optional table of placement attributes
function rtk.Window:open(attrs)
    if self.running then
        return
    end
    rtk._quit = false
    rtk.window = self

    local inifile = reaper.get_ini_file()
    local ini, err = rtk.file.read(inifile)
    if not err then
        rtk.scale.reaper = ini:match('uiscale=([^\n]*)') or 1.0
    end

    local calc = self.calc
    self.running = true
    gfx.ext_retina = 1
    -- Initialize the gfx.clear to the right background color.
    self:_handle_attr('bg', calc.bg or rtk.theme.bg)
    attrs = self:_calc_cell_attrs(attrs)
    local x, y, w, h = self:_get_geometry_from_attrs(attrs)
    -- Set current attributes based on initial geometry.  Also mark these as the
    -- initial calculated values for size.  (Calculated position is always 0,0.)
    self.x, self.y, self.w, self.h = x, y, w, h
    calc.w, calc.h = w, h
    local dockstate = self:_get_dockstate_from_attrs()

    -- Correct y coordinate for Mac
    if rtk.os.mac then
        local _, _, _, screenh = self:_get_display_resolution()
        y = screenh - y - h
    end
    gfx.init(calc.title, w, h, dockstate, x, y)

    -- Initialize dock state.
    dockstate, _, _ = gfx.dock(-1, true, true)
    -- After _handle_dock_change(), self.hwnd will be set, and window attrs will be synced.
    self:_handle_dock_change(dockstate)
    -- Update immediately to clear canvas to background color to avoid (or reduce, anyway)
    -- ugly flicker.  Unfortunately, gfx.clear isn't sufficient.
    if rtk.has_js_reascript_api then
        self:_clear_gdi()
    else
        -- Fallback if js_ReaScriptAPI isn't available to immediately paint the
        -- background. I'm not actually sure if this helps or if it's placebo.
        rtk.color.set(rtk.theme.bg)
        gfx.rect(0, 0, w, h, 1)
    end
    self:_sync_window_attrs()
    self._draw_queued = true
    self:_run()
end

function rtk.Window:_close()
    self.running = false
    gfx.quit()
end

--- Closes the window and will end the application unless there are active user-managed
-- @{rtk.defer|deferred calls} in flight to prevent REAPER from terminating us.
--
-- It is possible to call `open()` again after the window is closed (assuming we haven't
-- yet terminated obviously).
function rtk.Window:close()
    self.running = false
    gfx.quit()
    self:onclose()
end

-- This depends on js_ReascriptAPI and won't be called unless it's available.
function rtk.Window:_setup_borderless()
    if self._move_grip then
        -- Already setup
        return
    end
    local calc = self.calc
    -- Use a blank spacer at the top of the window with a low z-index as the
    -- move grip.  ondragstart() will not be invoked if a higher z-level
    -- widget handles the event.
    local move = rtk.Spacer{z=-10000, w=1.0, h=30, touch_activate_delay=0}
    move.ondragstart = function(this, event)
        if not calc.docked and calc.borderless then
            local _, wx, wy, _, _ = reaper.JS_Window_GetClientRect(self.hwnd)
            this._drag_start_ex, this._drag_start_ey = event.x, event.y
            this._drag_start_wx, this._drag_start_wy = wx, wy
            this._drag_start_ww, this._drag_start_wh = calc.w, calc.h
            return true
        else
            -- Prevent ondragmousemove from firing.
            return false
        end
    end
    move.ondragmousemove = function(this, event)
        local _, wx, wy, _, _ = reaper.JS_Window_GetClientRect(self.hwnd)
        local x = wx + (event.x - this._drag_start_ex)
        local y
        if rtk.os.mac then
            y = (wy - this._drag_start_wh) - (event.y - this._drag_start_ey)
        else
            y = wy + (event.y - this._drag_start_ey)
        end
        if self._unmaximized_geometry then
            -- We're moving a maximized window.  Restore to previous size.
            local _, _, w, h = table.unpack(self._unmaximized_geometry)
            local sx, _, sw, sh = self:_get_display_resolution()
            -- Find the same relative position based on new window size
            local dx = math.ceil((w/this._drag_start_ww) * event.x)
            x = rtk.clamp(sx + dx, sx, sx + sw - w)
            self._unmaximized_geometry = nil
            -- Reset initial drag state based on the restored geometry.
            this._drag_start_ex = dx
            this._drag_start_ww, this._drag_start_wh = w, h
            this._drag_start_wx = x
            reaper.JS_Window_SetPosition(self.hwnd, x, y, w, h)
        else
            reaper.JS_Window_Move(self.hwnd, x, y)
        end
    end
    move.ondoubleclick = function(this, event)
        local x, y, w, h = self:_get_display_resolution()
        if self._unmaximized_geometry then
            if x == self.x and y == self.y and w == self.w and h == self.h then
                x, y, w, h = table.unpack(self._unmaximized_geometry)
            end
            self._unmaximized_geometry = nil
        else
            self._unmaximized_geometry = {self.x, self.y, self.w, self.h}
        end
        self:move(x, y)
        self:resize(w, h)
        return true
    end

    -- Resize grip
    local resize = rtk.ImageBox{
        image=rtk.Window._icon_resize_grip,
        z=10000,
        cursor=rtk.mouse.cursors.SIZE_NW_SE,
        alpha=0.4,
        autofocus=true,
        touch_activate_delay=0,
        tooltip='Resize window',
    }
    resize.onmouseenter = function(this)
        if calc.borderless then
            this:animate{attr='alpha', dst=1, duration=0.1}
            return true
        end
    end
    resize.onmouseleave = function(this, event)
        if calc.borderless then
            this:animate{attr='alpha', dst=0.4, duration=0.25}
        end
    end
    resize.ondragstart = move.ondragstart
    resize.ondragmousemove = function(this, event)
        local x = event.x - this._drag_start_ex
        local y = event.y - this._drag_start_ey
        -- Clamp dimensions so the window can't be resized down to nothing.
        local w = math.max(self.minw, this._drag_start_ww + x)
        local h = math.max(self.minh, this._drag_start_wh + y)
        reaper.JS_Window_Resize(self.hwnd, w, h)
        -- Immediately paint the background on the expanded area (if any) to avoid
        -- flicker.
        self:_clear_gdi(calc.w, calc.h)
        if rtk.os.mac then
            reaper.JS_Window_Move(self.hwnd, this._drag_start_wx, this._drag_start_wy - h)
        end
    end

    self:add(move)
    self:add(resize, {valign='bottom', halign='right'})
    self._move_grip = move
    self._resize_grip = resize
end

function rtk.Window:_get_hwnd()
    if not rtk.has_js_reascript_api then
        return
    end
    -- Find the gfx hwnd based on window title.  First use JS_Window_Find()
    -- which is pretty fast, and if it doesn't appear to be this gfx instance
    -- (based on screen coordinates) then we do the much more expensive call to
    -- JS_Window_ArrayFind().  If that only returns one result, then we go
    -- with our original hwnd, and if not, then we find the one that matches
    -- the screen position of this gfx.
    local x, y = gfx.clienttoscreen(0, 0)
    local function verify_hwnd_coords(hwnd)
        local _, hx, hy, _, _ = reaper.JS_Window_GetClientRect(hwnd)
        return hx == x and hy == y
    end
    local title = self.calc.title
    local hwnd = reaper.JS_Window_Find(title, true)
    if not verify_hwnd_coords(hwnd) then
        hwnd = nil
        -- The returned hwnd doesn't match our screen coordinates so do
        -- a deeper search.
        log.time_start()
        local a = reaper.new_array({}, 10)
        local nmatches = reaper.JS_Window_ArrayFind(title, true, a)
        if nmatches > 1 then
            local hwnds = a.table()
            for n, hwndptr in ipairs(hwnds) do
                local candidate = reaper.JS_Window_HandleFromAddress(hwndptr)
                if verify_hwnd_coords(candidate) then
                    hwnd = candidate
                    break
                end
            end
        end
        log.time_end('rtk.Window:_get_hwnd(): needed to take slow path: title=%s', title)
    end
    if hwnd then
        -- Determine the additional w/h incurred by the OS-supplied window frame so that
        -- we're able to use JS_Window_SetPosition() elsewhere, as it expects dimensions
        -- that include the window frame.
        local _, w, h = reaper.JS_Window_GetClientSize(hwnd)
        local _, l, t, r, b = reaper.JS_Window_GetRect(hwnd)
        self._os_window_frame_width = (r - l) - w
        self._os_window_frame_height = math.abs(b - t) - h
    end
    return hwnd
end

function rtk.Window:_handle_dock_change(dockstate)
    local calc = self.calc
    local was_docked = (self._dockstate & 0x01) ~= 0
    calc.docked = dockstate & 0x01 ~= 0
    calc.dock = (dockstate >> 8) & 0xff
    -- Also sync to user-facing attributes
    self.dock, self.docked = calc.dock, calc.docked
    self._dockstate = dockstate

    self.hwnd = self:_get_hwnd()
    self:queue_reflow(rtk.Widget.REFLOW_FULL)
    if was_docked ~= calc.docked then
        self:_clear_gdi()
        if calc.docked then
            -- We docked, so save current geometry for next undock.
            self._undocked_geometry = {self.x, self.y, self.w, self.h}
        elseif self._undocked_geometry then
            -- We undocked, so restore the last saved geoemetry.
            self.x, self.y, self.w, self.h = table.unpack(self._undocked_geometry)
        end
    end
    self:_sync_window_attrs()
    self:queue_blit()
    self:ondock()
end


function rtk.Window:queue_reflow(mode, widget)
    -- Partial reflow only possible for widget if it had previously gone through
    -- a full reflow, which is why we test widget.box.
    if mode ~= rtk.Widget.REFLOW_FULL and widget and widget.box then
        if self._reflow_widgets then
            self._reflow_widgets[widget] = true
        elseif not self._reflow_queued then
            self._reflow_widgets = {[widget]=true}
        end
    else
        self._reflow_widgets = nil
    end
    self._reflow_queued = true
end

function rtk.Window:queue_draw()
    self._draw_queued = true
end

--- Queues a full blit of the window from its backing store based on previously drawn
-- state upon next update.
--
-- This normally should never need to be called -- rtk internally understands when it
-- needs to blit -- but if you're doing some low level window trickery voodoo underneath
-- rtk (e.g. by using the js_ReaScriptAPI directly), you *may* find it necessary to
-- invoke this.
function rtk.Window:queue_blit()
    self._blits_queued = self._blits_queued + 2
end

--- Queues a simulated mousemove event on next update to cause widgets to refresh the
-- mouse hover state.
--
-- This normally never needs to be called, but this method is needed to handle a very
-- precise edge case:
--   1. The application is blocked (e.g. because an `rtk.NativeMenu` is open)
--   2. The user moves the mouse to hover over another widget
--   3. The application becomes unblocked while the mouse button is pressed (e.g.
--      because the user closed the popup menu by clicking the mouse button)
-- In this case, once the window's update loop becomes unblocked, the above condition
-- actually looks like a drag event, and the new widget's hover state doesn't get
-- updated.
--
-- Calling this function will force the injection of a simulated `rtk.Event.MOUSEMOVE`
-- event without any buttons pressed which causes the new widget under the mouse to update
-- its hover appearance.
--
-- If you find you need to call this method when the application isn't blocked, this
-- should be considered a bug and reported.
function rtk.Window:queue_mouse_refresh()
    self._mouse_refresh_queued = true
end

function rtk.Window:_reflow(boxx, boxy, boxw, boxh, fillw, filly, clampw, clamph, viewport, window)
    rtk.Container._reflow(self, boxx, boxy, boxw, boxh, fillw, filly, clampw, clamph, viewport, window)
    -- The semantics of the x, y properties are different for Windows, where they refer to
    -- the OS window coordinates rather than internal widget coordinates.  So override the
    -- calculated x/y to offset to 0.
    self.calc.x = 0
    self.calc.y = 0
end

-- If full is false, only specific widgets are reflowed, which assumes their geometry
-- has not changed.
function rtk.Window:reflow(mode)
    local calc = self.calc
    local widgets = self._reflow_widgets
    local full = false
    self._reflow_queued = false
    self._reflow_widgets = nil
    local t0 = reaper.time_precise()
    if mode ~= rtk.Widget.REFLOW_FULL and widgets and self.realized and #widgets < 20 then
        for widget, _ in pairs(widgets) do
            widget:reflow()
            widget:_realize_geometry()
        end
    else
        rtk.Container.reflow(self,
            -- box
            0, 0, calc.w, calc.h,
            -- fill
            nil, nil,
            -- clamp
            true, true,
            -- viewport and window
            nil, self
        )
        self:_realize_geometry()
        full = true
        -- log.debug('rtk: full reflow (%s x %s) in %.3f ms', calc.w, calc.h, (reaper.time_precise() - t0) * 1000)
    end
    local reflow_time = reaper.time_precise() - t0
    if reflow_time > 0.02 then
        log.warning("rtk: slow reflow: %s", reflow_time)
    end
    self:onreflow(widgets)
    -- Reflow implies redraw
    self._draw_queued = true
    return full
end

function rtk.Window:_get_mouse_button_event(bit, type)
    if not type then
        -- Determine whether the mouse button (at the given bit position) is either
        -- pressed or released.  We update the rtk.mouse.down bitmap to selectively
        -- toggle that single bit rather than just copying the entire mouse_cap bitmap
        -- in order to ensure that multiple simultaneous mouse up/down events will
        -- be emitted individually (in separate invocations of _update()).
        if rtk.mouse.down & bit == 0 and gfx.mouse_cap & bit ~= 0 then
            rtk.mouse.down = rtk.mouse.down | bit
            type = rtk.Event.MOUSEDOWN
        elseif rtk.mouse.down & bit ~= 0 and gfx.mouse_cap & bit == 0 then
            rtk.mouse.down = rtk.mouse.down & ~bit
            type = rtk.Event.MOUSEUP
        end
    end
    if type then
        local event = self._event:reset(type)
        event.x, event.y = gfx.mouse_x, gfx.mouse_y
        event:set_modifiers(gfx.mouse_cap, bit)
        return event
    end
end

function rtk.Window:_get_mousemove_event(simulated)
    -- Event x/y attributes also reset according to current gfx context.
    local event = self._event:reset(rtk.Event.MOUSEMOVE)
    event.simulated = simulated
    event:set_modifiers(gfx.mouse_cap, rtk.mouse.state.latest or 0)
    return event
end

local function _get_wheel_distance(v)
    if rtk.os.mac then
        -- On Mac, kinetic scrolling seems a bit overzealous, so let's flatten that a
        -- bit.  XXX: at least in VM testing, need to verify if this is also the case
        -- with a native system.
        local direction = v < 0 and 1 or -1
        return direction * math.sqrt(math.abs(v) / 6)
    else
        return -v / 120
    end
end


function rtk.Window:_update()
    local calc = self.calc
    local now = reaper.time_precise()
    -- Default to false, and it will be set to true later if certain criteria are met.
    local need_draw = false

    if gfx.ext_retina ~= rtk.scale.system then
        rtk.scale.system = gfx.ext_retina
        rtk.scale.value = rtk.scale.user * rtk.scale.system * rtk.scale.reaper
        self:queue_reflow()
    end
    -- Check for files being dropped over the window.  Note this must be called *before*
    -- gfx.update() which appears to clear the dropfile list.
    local files = nil
    local _, fname = gfx.getdropfile(0)
    if fname then
        files = {fname}
        local idx = 1
        while true do
            _, fname = gfx.getdropfile(idx)
            if not fname then
                break
            end
            files[#files+1] = fname
            idx = idx + 1
        end
        gfx.getdropfile(-1)
    end

    -- Now sync gfx variables, which also clears the dropfile list.
    gfx.update()

    -- Check current window focus.  Ensure focused_hwnd is updated *before* calling
    -- onupdate() handler.
    local focus_changed = false
    if rtk.has_js_reascript_api then
        rtk.focused_hwnd = reaper.JS_Window_GetFocus()
        local is_focused = self.hwnd == rtk.focused_hwnd
        if is_focused ~= self.is_focused then
            self.is_focused = is_focused
            need_draw = true
            focus_changed = true
        end
    end

    -- Now call the user-attached handler (if any).  Returning false aborts the current
    -- update cycle (which has limited use, but this is a standard contract with event
    -- handlers, where a false return value bypasses default behavior).
    if self:onupdate() == false then
        return
    end
    need_draw = rtk._do_animations(now) or need_draw
    -- Check to see if resized now before _sync_window_attrs() below potentially meddles
    -- with gfx.w/h or self.w/h.
    local resized = gfx.w ~= calc.w or gfx.h ~= calc.h
    if self._sync_window_attrs_on_update and self.hwnd and rtk.has_js_reascript_api then
        -- Sync current attributes to window state.  We'll amend the resized flag
        -- if _sync_window_attrs() actually resizes the window (in which case it will
        -- also update gfx.w/gfx.h to the new dimensions), so that we properly fire
        -- onresize() and reflow according to the new size now without having to wait for
        -- the next update.  If we did resize, gfx.w/h will have been updated to the new
        -- target size, which we set to our calculated size a bit later on.
        resized = (self:_sync_window_attrs() ~= 0) or resized
        self._sync_window_attrs_on_update = false
    end

    -- Sync dock state.  Do this now before reflowing in case the dock state was toggled
    -- such that our size is now different.  We want to reflow immediately with the new
    -- size to prevent a reflow-flicker.
    local dockstate, x, y = gfx.dock(-1, true, true)
    local dock_changed = dockstate ~= self._dockstate
    if dock_changed then
        self:_handle_dock_change(dockstate)
    end
    y = self:_get_os_native_y(y, gfx.h + self._os_window_frame_height)
    if x ~= self.x or y ~= self.y then
        -- Note that calc.x/y are not set as they are always 0 for rtk.Windows (in order
        -- for container layout to work).  Instead we just sync the user-facing attributes.
        local lastx, lasty = self.x, self.y
        self.x, self.y = x, y
        self:onmove(lastx, lasty)
    end
    if resized and self.visible then
        -- Update both calculated and user-facing attributes for the newly discovered size.
        local last_w, last_h = calc.w, calc.h
        self.w, self.h = gfx.w, gfx.h
        calc.w, calc.h = gfx.w, gfx.h
        -- Helps to reduce flicker just a tiny bit when the window size expands.
        self:_clear_gdi(calc.w, calc.h)
        self:onresize(last_w, last_h)
        -- Force a full reflow as our size has changed.
        self:reflow(rtk.Widget.REFLOW_FULL)
        need_draw = true
    elseif self._reflow_queued then
        -- Standard previously queued reflow.  It will be either full or partial depending
        -- on what was queued.
        self:reflow()
        need_draw = true
    end

    -- Now go hunting for events.  Initialize to nil now, and it'll be set to an
    -- rtk.Event if something happened.
    local event = nil
    local last_cursor = calc.cursor
    -- Clear mouse cursor before drawing widgets to determine if any widget wants a custom cursor
    calc.cursor = rtk.mouse.cursors.UNDEFINED

    -- Check for a mousewheel event.
    if gfx.mouse_wheel ~= 0 or gfx.mouse_hwheel ~= 0 then
        event = self._event:reset(rtk.Event.MOUSEWHEEL)
        event:set_modifiers(gfx.mouse_cap, 0)
        event.wheel = _get_wheel_distance(gfx.mouse_wheel)
        event.hwheel = _get_wheel_distance(gfx.mouse_hwheel)
        self:onmousewheel(event)
        -- Per REAPER docs: "the caller should clear the state to 0 after reading it"
        gfx.mouse_wheel = 0
        gfx.mouse_hwheel = 0
        self:_handle_window_event(event, now)
    end
    -- Generate key event
    local char = gfx.getchar()
    if char > 0 then
        event = self._event:reset(rtk.Event.KEY)
        event:set_modifiers(gfx.mouse_cap, 0)
        event.char = nil
        event.keycode = char
        if char <= 26 and event.ctrl then
            event.char = string.char(char + 96)
        elseif char >= 32 and char ~= 127 then
            if char <= 255 then
                event.char = string.char(char)
            elseif char <= 282 then
                event.char = string.char(char - 160)
            elseif char <= 346 then
                event.char = string.char(char - 224)
            end
        end
        self:onkeypresspre(event)
        self:_handle_window_event(event, now)
    elseif char < 0 then
        self:close()
    end

    -- Generate file drop event
    if files then
        event = self:_get_mousemove_event(false)
        event.type = rtk.Event.DROPFILE
        event.files = files
        self:_handle_window_event(event, now)
    end

    rtk._touch_activate_event = rtk.touchscroll and rtk.Event.MOUSEUP or rtk.Event.MOUSEDOWN

    -- Any handlers invoked above may have queued a draw, so notice that now.
    need_draw = need_draw or self._draw_queued

    -- Whether any mouse button has been pressed or released this cycle
    local mouse_button_changed = (rtk.mouse.down ~= gfx.mouse_cap & rtk.mouse.BUTTON_MASK)
    -- Bitmap of buttons that are pressed
    local buttons_down = (gfx.mouse_cap & rtk.mouse.BUTTON_MASK ~= 0)
    -- True if the mouse position changed from the last cycle
    local mouse_moved = (rtk.mouse.x ~= gfx.mouse_x or rtk.mouse.y ~= gfx.mouse_y)

    local last_in_window = self.in_window
    self.in_window = gfx.mouse_x >= 0 and gfx.mouse_y >= 0 and gfx.mouse_x <= gfx.w and gfx.mouse_y <= gfx.h
    local in_window_changed = self.in_window ~= last_in_window

    if self._last_mousemove_time and rtk._mouseover_widget and
       rtk._mouseover_widget ~= self._tooltip_widget and
       now - self._last_mousemove_time > rtk.tooltip_delay then
        -- Show tooltip.
        self._tooltip_widget = rtk._mouseover_widget
        need_draw = true
    end
    if mouse_button_changed and rtk.touchscroll and self._jsx then
        self._restore_mouse_pos = {self._jsx, self._jsy}
    end
    if mouse_moved then
        if self.in_window then
            self._jsx = nil
        elseif not buttons_down then
            -- Only save position if no buttons are down.  Handles case where the mouse
            -- is clicking on scrollbar and dragging outside the window. Once it releases,
            -- we should not be restoring position.
            self._jsx, self._jsy = reaper.GetMousePosition()
        end
        if self._mouse_refresh_queued then
            -- queue_mouse_refresh() was called and we need to inject a mousemove event
            -- without any buttons pressed to cause the widget under the mouse to refresh
            -- its hover state.  We wait until mouse_moved is true because if the app
            -- was blocked, mouse moved, and becomes unblocked, we need an extra update
            -- cycle before gfx.update() reflects the new mouse position.  This means we
            -- won't fire if (or until) the mouse moves, but if the mouse never moved then
            -- there's no hover state to update anyway.
            self._mouse_refresh_queued = false
            local tmp = self:_get_mousemove_event(true)
            tmp.buttons = 0
            tmp.button = 0
            self:_handle_window_event(tmp, now)
            need_draw = true
        end
    end

    if not event or mouse_moved then
        -- Passed to _handle_window_event() when we don't want to propagate
        -- the event to children.
        local suppress = false
        -- Generate mousemove event if the mouse actually moved, or simulate one in the
        -- following circumstances:
        --   1. A draw has been queued (e.g. for an animation, or a blinking caret where
        --      we need to preserve the mouse cursor which is done via mousemove event)
        --   2. Mouse just left the rtk window
        --   3. A widget is being dragged but the mouse isn't moving (to handle the case when
        --      dragging at the edge of a viewport
        --   4. Long press
        if self.in_window and rtk.has_js_reascript_api then
            -- The mouse is within the window boundary but we need to find out if the
            -- window is occluded by another window and whether the mouse cursor is over
            -- the occluded portion.
            local x, y = reaper.GetMousePosition()
            local hwnd = reaper.JS_Window_FromPoint(x, y)
            if hwnd ~= self.hwnd then
                self.in_window = false
                -- Above self.in_window was set purely based on mouse position.  We've
                -- just learned that in fact the window is occluded and have reset
                -- self.in_window, but here we also reevaluate in_window_changed based on
                -- the previous value of self.in_window, in order to prevent continuous
                -- simulated mousemoves while the mouse is over the occluded window.
                in_window_changed = last_in_window ~= false
            end
        end
        -- Ensure we emit the event if draw is forced, or if we're moving within the window, or
        -- if we _were_ in the window but now suddenly aren't (to ensure mouseout cases are drawn)
        if need_draw or (mouse_moved and self.in_window) or in_window_changed or
           -- Also generate mousemove events if we're currently dragging but the mouse isn't
           -- otherwise moving.  This allows dragging against the edge of a viewport to steadily
           -- scroll.
           (rtk.dnd.dragging and buttons_down) then
            event = self:_get_mousemove_event(not mouse_moved)
            if buttons_down and rtk.touchscroll and not rtk.dnd.dragging then
                -- With touch scrolling, button down may be delayed.  Hold off issuing
                -- mousemove events with button down until we have had a chance to fire
                -- mousedown first.
                suppress = not event:get_button_state('mousedown-handled')
            end
        elseif rtk.mouse.down ~= 0 and not mouse_button_changed then
            -- Continuously generated mousedown events for the last-pressed button for onlongpress()
            -- and for time-deferred onmousedown() (for touch-scrolling).  We only need to keep
            -- firing these simulated events for as long as rtk.long_press_delay or
            -- rtk.touch_activate_delay (whichever is longer) as elapsed.  We include the time for
            -- a couple extra update cycles as well to ensure those thresholds get tripped.
            local buttonstate = rtk.mouse.state[rtk.mouse.state.latest]
            local wait = math.max(rtk.long_press_delay, rtk.touch_activate_delay)
            if now - buttonstate.time <= wait + (2/rtk.fps) then
                event = self:_get_mouse_button_event(rtk.mouse.state.latest, rtk.Event.MOUSEDOWN)
                event.simulated = true
            end
        end
        if event and (not event.simulated or self._touch_scrolling.count == 0 or buttons_down) then
            need_draw = need_draw or self._tooltip_widget ~= nil
            self:_handle_window_event(event, now, suppress)
        end
    end

    rtk.mouse.x = gfx.mouse_x
    rtk.mouse.y = gfx.mouse_y

    -- Now check to see if any mouse buttons were pressed or released.  rtk.mouse.down
    -- is set in _get_mouse_button_event(), so we check now for changes to it.
    --
    -- We processed mousemove first because in the touchscreen case, mouse movement
    -- and button press happen simultaneously, and we need widgets to recognize
    -- and set mouseover state first before clicks can be properly handled.
    if mouse_button_changed then
        -- Generate events for mouse button down/up.  This logic isn't completely robust:
        -- if two mouse buttons are simultaneously pressed, we will not fire discrete
        -- MOUSEMOVE events for each button.  Rather, event.buttons will contain the
        -- mask and we pick an event.button based on an order in priority from left,
        -- right, and middle.
        --
        -- _get_mouse_button_event() also updates rtk.mouse.down
        event = self:_get_mouse_button_event(rtk.mouse.BUTTON_LEFT)
        if not event then
            event = self:_get_mouse_button_event(rtk.mouse.BUTTON_RIGHT)
            if not event then
                event = self:_get_mouse_button_event(rtk.mouse.BUTTON_MIDDLE)
            end
        end
        if event then
            -- Here we maintain the mouse button state per button.
            if event.type == rtk.Event.MOUSEDOWN then
                local buttonstate = rtk.mouse.state[event.button]
                if not buttonstate then
                    buttonstate = {}
                    rtk.mouse.state[event.button] = buttonstate
                end
                -- Record current time the button was pressed
                buttonstate.time = now
                -- Also keep track of the order the buttons were pressed, so when we
                -- generate a simulated mousedown later we can use an appropriate value
                -- for event.button.
                rtk.mouse.state.order[#rtk.mouse.state.order+1] = event.button
                rtk.mouse.state.latest = event.button
            elseif event.type == rtk.Event.MOUSEUP then
                -- Some mouse button was released, where now we want to update the value
                -- of rtk.mouse.state.latest (for simulated mousedown events later on).
                -- This is somewhat ugly, but at least rtk.mouse.state.order won't get any
                -- larger than the number of supported mouse buttons.
                for i = 1, #rtk.mouse.state.order do
                    if rtk.mouse.state.order[i] == event.button then
                        table.remove(rtk.mouse.state.order, i)
                        break
                    end
                end
                if #rtk.mouse.state.order > 0 then
                    rtk.mouse.state.latest = rtk.mouse.state.order[#rtk.mouse.state.order]
                else
                    rtk.mouse.state.latest = 0
                end
                if rtk.touchscroll and event.buttons == 0 and self._restore_mouse_pos then
                    local x, y = table.unpack(self._restore_mouse_pos)
                    rtk.callafter(0.2, reaper.JS_Mouse_SetPosition, x, y)
                    self._restore_mouse_pos = nil
                end
            end
            self:_handle_window_event(event, now)
        else
            log.warning('rtk: no event for mousecap=%s which indicates an internal rtk bug', gfx.mouse_cap)
        end
    end

    local blitted = false
    if event and self.visible then
        if self._reflow_queued and not self._sync_window_attrs_on_update then
            -- One of the event handlers has requested a reflow.  It'd happen on the
            -- next update() but we do it now before drawing just to avoid potential
            -- flickering. The exception is if we're pending an a sync of window
            -- attributes which could affect the window geometry which we'd need to
            -- learn on next full update.
            if self:reflow() then
                -- We have performed a full reflow, which means some of the widgets
                -- may have changed positions.  Here we inject a mousemove event to
                -- cause any widgets which now, after potentially having been
                -- repositioned, have been moved under the mouse cursor, so they
                -- can properly draw their current hover state.
                --
                -- Also reset the cursor now that we're going to push a new simulated
                -- event through the widget tree, in case a mouseup or onclick handler
                -- will change the cursor of the widget the mouse is over.
                calc.cursor = rtk.mouse.cursors.UNDEFINED
                self:_handle_window_event(self:_get_mousemove_event(true), now)
            end
        end
        -- Also check self._draw_queued in case the above simulated mousemove generated a
        -- queued draw
        if need_draw or self._draw_queued then
            -- A no-op if the size hasn't changed.
            self._backingstore:resize(calc.w, calc.h, false)
            self._backingstore:pushdest()
            self:clear()
            -- Clear _draw_queued flag before drawing so that if some event handler
            -- triggered from _draw() queues a redraw it won't get lost.
            self._draw_queued = false
            self:_draw(0, 0, 1.0, event, calc.w, calc.h, 0, 0, 0, 0)
            if event.debug then
                event.debug:_draw_debug_info(event)
            end
            if self._tooltip_widget and not rtk.dnd.dragging then
                self._tooltip_widget:_draw_tooltip(rtk.mouse.x, rtk.mouse.y, calc.w, calc.h)
            end
            self._backingstore:popdest()
            self:_blit()
            blitted = true
        end

        -- Emit focus/blur events for the window itself, and handle blurring and refocusing
        -- widgets as the window itself loses/regains focus.
        --
        -- This requires js_ReascriptAPI to work.
        if focus_changed then
            if self.is_focused then
                if self._focused_saved then
                    self._focused_saved:focus(event)
                    self._focused_saved = nil
                end
                self:onfocus(event)
            else
                if rtk.focused then
                    self._focused_saved = rtk.focused
                    rtk.focused:blur(event, nil)
                end
                self:onblur(event)
            end
        end
        -- If we have an unhandled mouse button press or the window lost focus and have
        -- modal widgets, we invite those widgets to release their modal state.  The
        -- assumption is that clicking inside a modal widget will result in the event
        -- being handled, so an unhandled touch activation event (MOUSEUP for touchscroll,
        -- MOUSEDOWN otherwise) implies the user clicked outside it.
        if not event.handled and rtk.is_modal() and
           ((focus_changed and not self.is_focused) or event.type == rtk._touch_activate_event) then
            for _, widget in pairs(rtk._modal) do
                widget:_release_modal(event)
            end
        end
        if not event.handled and rtk.focused and event.type == rtk._touch_activate_event then
            -- Unhandled click, blur focused widget.
            rtk.focused:blur(event, nil)
        end
        if event.type == rtk.Event.KEY then
            self:onkeypresspost(event)
            if event.handled then
                return
            end
            if event.keycode == rtk.keycodes.F12 and log.level <= log.DEBUG then
                rtk.debug = not rtk.debug
                self:queue_draw()
            elseif event.keycode == rtk.keycodes.ESCAPE and not self.docked then
                self:close()
            end
        end
        -- If the current cursor is undefined, it means no widgets requested a custom cursor,
        -- so revert to default pointer.
        if calc.cursor == rtk.mouse.cursors.UNDEFINED then
            calc.cursor = self.cursor
        end
        -- There are a couple edge cases in trying to be clever and only setting the cursor when
        -- necessary, so for now we disable the cleverness and blindly set the cursor on each
        -- update if the cursor is in the window.
        -- if calc.cursor ~= last_cursor or last_in_window ~= self.in_window or focus_changed then
        if self.in_window then
            if type(calc.cursor) == 'userdata' then
                -- Set cursor using JSAPI
                reaper.JS_Mouse_SetCursor(calc.cursor)
                reaper.JS_WindowMessage_Intercept(self.hwnd, "WM_SETCURSOR", false)
            else
                gfx.setcursor(calc.cursor, 0)
            end
        elseif in_window_changed and rtk.has_js_reascript_api then
            -- Cursor moved out of window, allow standard OS move/resize mouse cursors to
            -- take affect as mouse moves in proximity to the outside border.
            reaper.JS_WindowMessage_Release(self.hwnd, "WM_SETCURSOR")
        end
    end
    if mouse_moved then
        self._last_mousemove_time = now
    end
    -- In practice we don't need to blit on every update -- REAPER itself clearly
    -- maintains its own backing store for scripts to deal e.g. occlusion changes -- but
    -- there are cases where multiple an explicit draws seem to be needed, for example
    -- when undocking.  In these cases queue_blit() will be called, and we can blit from
    -- the window's backing store if we didn't already draw above.
    if self._blits_queued > 0 then
        if not blitted then
            self:_blit()
        end
        self._blits_queued = self._blits_queued - 1
    end

    local duration = reaper.time_precise() - now
    if duration > 0.04 then
        log.debug("rtk: very slow update: %s  event=%s", duration, event)
    end
end

-- Draws the current contents of the backing store onto the current drawing target.
function rtk.Window:_blit()
    self._backingstore:blit{mode=rtk.Image.FAST_BLIT}
end

function rtk.Window:_handle_window_event(event, now, suppress)
    if not self.visible then
        return
    end
    if not event.simulated then
        -- For non-generated mousemove events, reset the global mouseover widget
        -- to ensure the correct hovering widget registers.
        rtk._mouseover_widget = nil
        self._tooltip_widget = nil
        self._last_mousemove_time = nil
    end
    event.time = now
    -- If suppress is true, it means we don't want to propagate the event to children, but
    -- do want to execute the logic below, e.g. for drag and drop.
    if not suppress then
        rtk.Container._handle_event(self, 0, 0, event, false, rtk._modal == nil)
    end

    -- log.info('handle window: %s %s', self.title, event)
    assert(event.type ~= rtk.Event.MOUSEDOWN or event.button ~= 0)
    if event.type == rtk.Event.MOUSEUP then
        rtk.mouse.state[event.button] = nil
        if event.buttons == 0 then
            -- Clear on mouseup if no more buttons are held.  We want to do this *after*
            -- _handle_event() above to ensure mouseup handlers can test rtk._pressed_widgets
            -- to see if a widget receiving mouseup had previously received mousedown.
            rtk._pressed_widgets = nil
        end
        self._last_mouseup_time = event.time
        rtk._drag_candidates = nil
        if rtk.dnd.dropping then
            rtk.dnd.dropping:_handle_dropblur(event, rtk.dnd.dragging, rtk.dnd.arg)
            rtk.dnd.dropping = nil
        end
        if rtk.dnd.dragging and event.buttons & rtk.dnd.buttons == 0 then
            -- All mouse buttons that initiated the drag have been released, so process
            -- the dragend event.
            rtk.dnd.dragging:_handle_dragend(event, rtk.dnd.arg)
            rtk.dnd.dragging = nil
            rtk.dnd.arg = nil
            -- Inject a mousemove event just in case there is any post-drag-drop state
            -- that should be visually reflected. For example, rtk.Viewport could be
            -- showing its scrollbar (if a child widget has show_scrollbar_on_drag set to
            -- true), and we want to give it the opportunity to hide the scrollbar after
            -- releasing the drag.
            local tmp = event:clone{type=rtk.Event.MOUSEMOVE, simulated=true}
            rtk.Container._handle_event(self, 0, 0, tmp, false, rtk._modal == nil)
        end
    elseif rtk._drag_candidates and event.type == rtk.Event.MOUSEMOVE and
           not event.simulated and event.buttons ~= 0 and not rtk.dnd.arg then
        -- Mouse moved while mouse button pressed, test now to see any of the drag
        -- candidates we registered from the preceding MOUSEDOWN event want to
        -- start a drag.
        --
        -- Clear event handled flag to give ondragstart() handler the opportunity
        -- to reset it as handled to prevent further propogation.
        event.handled = nil
        -- Reset droppable status.
        rtk.dnd.droppable = true
        local missed = false
        -- Distance threshold required to trigger a drag operation in pixels.  This
        -- defaults based on the global scale.
        local dthresh = math.ceil(rtk.scale.value ^ 1.7)
        if rtk.touchscroll and event.time - self._last_mouseup_time < 0.2 then
            -- If the mouse was recently clicked, mitigate inadvertent touch-drags on this
            -- second click by amping up the distance threshold, lest we frustrate the
            -- user's ability to double click.
            dthresh = rtk.scale.value * 10
        end
        for n, state in ipairs(rtk._drag_candidates) do
            local widget, offered = table.unpack(state)
            if not offered then
                local ex, ey, when = table.unpack(rtk._pressed_widgets[widget.id])
                -- Ensure the mouse actually moved before offering the dragstart.
                local dx = math.abs(ex - event.x)
                local dy = math.abs(ey - event.y)
                local tthresh = widget:_get_touch_activate_delay(event)
                if event.time - when >= tthresh and (dx > dthresh or dy > dthresh) then
                    local arg, droppable = widget:_handle_dragstart(event, ex, ey, when)
                    if arg then
                        -- Widget has accepted the dragstart. For touchscrolling, emit the
                        -- deferred mousedown now using the original coordinates from the
                        -- mousedown.
                        widget:_deferred_mousedown(event, ex, ey)
                        rtk.dnd.dragging = widget
                        rtk.dnd.arg = arg
                        rtk.dnd.droppable = droppable ~= false and true or false
                        rtk.dnd.buttons = event.buttons
                        widget:_handle_dragmousemove(event, arg)
                        break
                    elseif event.handled then
                        break
                    end
                    -- Update state to indicate we offered a dragstart to this widget.
                    state[2] = true
                else
                    missed = true
                end
            end
        end
        if not missed or event.handled then
            rtk._drag_candidates = nil
        end
    end
end
--- Called within an event handler to ask the window to set the mouse cursor.
--
-- The word "ask" is used because this works on a first-come-first-served basis:
-- whoever is first to call this function on each update cycle wins the race.
-- At least unless the force parameter is true, but this should only ever be
-- needed in very rare cases (such as touch-scrolling).
--
-- If you want a particular cursor when mousing over a widget, use the
-- @{rtk.Widget.cursor|cursor} attribute rather than calling this function.  Setting
-- `cursor` on an `rtk.Window` will result in it being the default cursor (when no widget
-- has requested a different cursor).
--
-- One use case for calling this function is switching cursors during a widget
-- drag operation:
--
-- @code
--   local img = container:add(rtk.ImageBox{icon='18-drag-handle'})
--   img.ondragstart = function(self, event)
--       -- Accept drags for this widget.
--       return true
--   end
--   img.ondragmousemove = function(self, event, dragarg)
--       -- Set the mouse cursor while dragging.
--       self.window:request_mouse_cursor(rtk.mouse.cursors.REAPER_DRAGDROP_COPY)
--   end
--
-- The above example requires either REAPER 6.24 or later (due to
-- [this bug](https://forum.cockos.com/showthread.php?p=2407043)) or the presence of the
-- js_ReaScriptAPI extension (which enables us to work around the bug).
--
-- @tparam cursorconst cursor one of the @{rtk.mouse.cursors|mouse cursor constants}
-- @tparam bool force if true, force-replaces the cursor even if it was already set
-- @treturn bool true if the cursor was set, false if a cursor was already
--   during this update cycle.
function rtk.Window:request_mouse_cursor(cursor, force)
    if cursor and (self.calc.cursor == rtk.mouse.cursors.UNDEFINED or force) then
        self.calc.cursor = cursor
        return true
    else
        return false
    end
end

--- Clears the window's backing store to the window's background color
-- (or the @{rtk.themes.bg|theme default}).
--
-- This is a low-level function that normally never needs to be called, but
-- could be used in certain cases within an @{rtk.Widget.ondraw|ondraw} handler.
function rtk.Window:clear()
    self._backingstore:clear(self.calc.bg or rtk.theme.bg)
end

function rtk.Window:_set_touch_scrolling(viewport, state)
    local ts = self._touch_scrolling
    local exists = ts[viewport.id] ~= nil
    if state and not exists then
        ts[viewport.id] = viewport
        ts.count = ts.count + 1
    elseif not state and exists then
        ts[viewport.id] = nil
        ts.count = ts.count - 1
    end
end

function rtk.Window:_is_touch_scrolling(viewport)
    if viewport then
        return self._touch_scrolling[viewport.id] ~= nil
    else
        return self._touch_scrolling.count > 0
    end
end

--- Event Handlers.
--
-- See also @{widget.handlers|handlers for rtk.Widget}.
--
-- @section window.handlers


--- Called on each update cycle before any reflow (if applicable), animation processing,
-- event handling, or drawing takes place.  Consequently, any actions performed by
-- the handler that affect the interface will be reflected immediately.
--
-- @treturn bool|nil if false, the normal update processing will be skipped.
function rtk.Window:onupdate() end

--- Called after one or more widgets have been reflowed (i.e. laid out) within
-- the window.
--
-- Unlike the @{rtk.Widget.onreflow|base class method}, onreflow handlers attached
-- to `rtk.Window`s receive an optional list of widgets.  If a full reflow has
-- occurred (i.e. every @{rtk.Widget.visible|visible} widget was reflowed), then
-- `widgets` is nil, but if specific widgets were explicitly reflowed this cycle
-- then `widgets` is an array containing the widgets.
--
-- @tparam table|nil widgets an array of widgets that were the subset of widgets
--   being reflowed this cycle, or if full reflow occurred then nil
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Window:onreflow(widgets) end


--- Called when the window changes position.
--
-- The `x` and `y` attributes reflect the current position, while the `lastx` and `lasty`
-- parameters hold the previous x and y values before the move occurred.
--
-- @tparam number lastx the last x value of the window before the move
-- @tparam number lasty the last y value of the window before the move
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Window:onmove(lastx, lasty) end


--- Called when the window changes size.
--
-- The `w` and `h` attributes reflect the current size, while the `lastw` and `lasth`
-- parameters hold the previous w and h values before the resize occurred.
--
-- @tparam number lastw the last width of the window before the resize
-- @tparam number lasth the last height of the window before the resize
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Window:onresize(lastw, lasth) end

--- Called when the window is docked or undocked, which includes when the window
-- is first @{rtk.Window.open|opened}.
--
-- When this handler is called, the `dock` and `docked` attributes reflect the
-- current state.
--
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Window:ondock() end

--- Called after the window is (gracefully) closed by clicking the OS-native close
-- button or when `close()` is called.
--
-- When the window would *un*gracefully close (e.g. because an exception occurred
-- causing program abort), the `rtk.onerror` handler will be called instead.
--
-- You may wish to bind `rtk.quit()` to this handler to ensure if the user closes the
-- window that the script terminates.
--
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Window:onclose() end

--- Called when a key event occurs but before it is dispatched to any widgets.
--
-- The caller has the opportunity to mutate the event or set it as handled to
-- prevent any widgets from responding to it.
--
-- @tparam rtk.Event event a `rtk.Event.KEY` event
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Window:onkeypresspre(event) end

--- Called when a key event occurs after all widgets have been given a chance
-- to handle the event.
--
-- @tparam rtk.Event event a `rtk.Event.KEY` event
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.Window:onkeypresspost(event) end