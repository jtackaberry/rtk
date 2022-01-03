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

--- Holds the state of events such as mouse or keyboard action.  These don't
-- generally need to be explicitly created but are passed along in event
-- handlers (e.g. `rtk.Widget:onclick()`)
--
-- @class rtk.Event
rtk.Event = rtk.class('rtk.Event')

--- Event type constants.
--
-- The `type` field will be set to one of these values.
-- @section typeconst
-- @compact

--- A mouse button was pressed (`button` indicates which)
rtk.Event.static.MOUSEDOWN = 1
--- A mouse button was released (`button` indicates which)
rtk.Event.static.MOUSEUP = 2
--- The mouse cursor was moved.  Note that in certain situations this event
-- can fire even when the mouse hasn't moved, for example to trigger an
-- `rtk.Viewport` to scroll when dragging a widget beyond the viewport edge.
-- In such situations, `simulated` will be true.
rtk.Event.static.MOUSEMOVE = 3
--- The mouse wheel was moved (`wheel` and `hwheel` indicate direction and distance)
rtk.Event.static.MOUSEWHEEL = 4
--- A key was pressed on the keyboard (`keycode` and possibly `char` indicate which key)
rtk.Event.static.KEY = 5
--- One or more files were dragged and dropped over the widget (`files` indicates which).
-- To handle dropped files globally, add the @{rtk.Widget:ondropfile|ondropfile} callback
-- to the `rtk.Window` itself.
rtk.Event.static.DROPFILE = 6

rtk.Event.static.typenames = {
    [rtk.Event.MOUSEDOWN] = 'mousedown',
    [rtk.Event.MOUSEUP] = 'mouseup',
    [rtk.Event.MOUSEMOVE] = 'mousemove',
    [rtk.Event.MOUSEWHEEL] = 'mousewheel',
    [rtk.Event.KEY] = 'key',
    [rtk.Event.DROPFILE] = 'dropfile',
}

--- Class API
-- @section api
-- @compact fields

rtk.Event.register{
    --- Type of event which is set to one of the @{typeconst|type constants}
    -- @meta read-only
    -- @type typeconst
    type = nil,
    --- The `rtk.Widget` of the widget that handled the event, or nil if not handled
    -- @meta read-only
    -- @type rtk.Widget|nil
    handled = nil,
    --- The mouse button that was the cause of the event, whether pressed or released,
    -- according to the @{rtk.mouse|mouse button constants}.  For `MOUSEMOVE` events,
    -- this will be the last pressed button (or 0 if no button is currently pressed).
    -- @meta read-only
    -- @type number
    button = 0,
    --- A bitmap of all @{rtk.mouse|mouse buttons} currently pressed.  Note that
    -- for `MOUSEUP` events this may be 0, if there are no more buttons pressed.
    -- To determine which button was released, use the `button` field.
    -- @meta read-only
    -- @type number
    buttons = 0,
    --- The vertical scroll wheel distance for `MOUSEWHEEL` events, negative for wheel up
    -- and positive for wheel down.  A distance of `1` is roughly one  "click" of a
    -- scrollwheel, and greater values indicate kinetic scrolling.
    -- @meta read-only
    -- @type number
    wheel = 0,
    --- Like `wheel` but for horizontal scroll wheels.
    -- @meta read-only
    -- @type number
    hwheel = 0,
    --- The raw numeric keycode of the `KEY` event that can be compared against
    -- @{rtk.keycodes}
    -- @meta read-only
    -- @type number
    keycode = nil,
    --- A single-character string containing the printable character of the key, if
    -- available.  Is nil if not translatable into a printable character.
    -- @meta read-only
    -- @type string
    char = nil,
    --- True if the control key was held during the `KEY` event
    -- @meta read-only
    -- @type boolean
    ctrl = false,
    --- True if the shift key was held during the `KEY` event
    -- @meta read-only
    -- @type boolean
    shift = false,
    --- True if the alt key was held during the `KEY` event
    -- @meta read-only
    -- @type boolean
    alt = false,
    --- True if the meta key (Windows key, for example) was held during the `KEY` event
    -- @meta read-only
    -- @type boolean
    meta = false,
    --- A low-level bitmap of key event modifiers.  4=ctrl, 8=shift, 16=alt, 32=meta
    -- @meta read-only
    -- @type number
    modifiers = nil,
    --- Set for `DROPFILE` events and is a table of file paths that were
    -- dropped onto the window
    -- @meta read-only
    -- @type table
    files = nil,
    --- The x client coordinate of the mouse cursor relative to the left edge of the `rtk.Window`
    -- @meta read-only
    -- @type number
    x = nil,
    --- The y client coordinate of the mouse cursor relative to the top edge of the `rtk.Window`
    -- @meta read-only
    -- @type number
    y = nil,
    --- Timestamp when the event occurred according to `reaper.time_precise()`.  Because
    -- `reaper.time_precise()` is used, this is *not* wall time, and can only be used for purposes
    -- of calculating deltas with future calls to `reaper.time_precise()`.
    -- @meta read-only
    -- @type number
    time = 0,
    --- If true, this is a simulated `MOUSEMOVE` event used to trigger some time-based behavior
    -- (such as viewport edge-scrolling or `rtk.Widget:onlongpress()`)
    -- @meta read-only
    -- @type boolean
    simulated = nil,
    --- If not nil, is the `rtk.Widget` that is being examined for debugging
    -- when `rtk.debug` is true
    -- @meta read-only
    -- @type boolean
    debug = nil,
}

--- Creates a new event.
--
-- @tparam table|nil attrs optional table of attributes to initialize the event with
-- @treturn rtk.Event the newly constructed event
-- @display rtk.Event
function rtk.Event:initialize(attrs)
    self:reset()
    if attrs then
        table.merge(self, attrs)
    end
end

function rtk.Event:__tostring()
    local custom
    if self.type >= 1 and self.type <= 3 then
        custom = string.format(' button=%s buttons=%s', self.button, self.buttons)
    elseif self.type == 4 then
        custom = string.format(' wheel=%s,%s', self.hwheel, self.wheel)
    elseif self.type == 5 then
        custom = string.format(' char=%s keycode=%s', self.char, self.keycode)
    elseif self.type == 6 then
        custom = ' ' .. table.tostring(self.files)
    end
    return string.format(
        'Event<%s xy=%s,%s handled=%s sim=%s%s>',
        rtk.Event.typenames[self.type] or 'unknown',
        self.x, self.y,
        self.handled,
        self.simulated,
        custom or ''
    )
end

--- Resets all fields in the event and sets to the given type
--
-- @tparam typeconst type the type of event
function rtk.Event:reset(type)
    table.merge(self, self.class.attributes.defaults)
    self.type = type
    -- Widget that handled this event
    -- Need to explicitly set these values to nil as nil values don't exist in tables
    self.handled = nil
    self.debug = nil
    -- These are all set by rtk.Window
    self.files = nil
    self.simulated = nil
    self.time = nil
    self.char = nil
    self.x = gfx.mouse_x
    self.y = gfx.mouse_y
    return self
end

--- Checks if the event is related to the mouse.
-- @treturn boolean true if the event is a mouse-related event, false otherwise.
function rtk.Event:is_mouse_event()
    return self.type <= rtk.Event.MOUSEWHEEL
end


--- Determine how long a mouse button has been pressed and held.
--
-- @tparam rtk.mouse|nil button mouse button constant, or nil to use the current
--   value of the event's `button`.
-- @treturn number|nil the amount of time in seconds the mouse button was held for,
--   or nil if the mouse button is not current pressed
function rtk.Event:get_button_duration(button)
    local buttonstate = rtk.mouse.state[button or self.button]
    if buttonstate then
        return self.time - buttonstate.time
    end
end

--- Marks the given widget as having the mouse over it for this event.
--
-- The main purpose of this method is tracking which widgets should be
-- @{rtk.Widget.debug|debugged} but may have other purposes in future.
function rtk.Event:set_widget_mouseover(widget)
    if rtk.debug and not self.debug then
        self.debug = widget
    end
    if widget.tooltip and not rtk._mouseover_widget and self.type == rtk.Event.MOUSEMOVE and not self.simulated then
        rtk._mouseover_widget = widget
    end
end

function rtk.Event:set_widget_pressed(widget)
    if not rtk._pressed_widgets then
        rtk._pressed_widgets = {order={}}
    end
    table.insert(rtk._pressed_widgets.order, widget)
    rtk._pressed_widgets[widget.id] = {self.x, self.y, self.time}

    if not rtk._drag_candidates then
        rtk._drag_candidates = {}
    end
    table.insert(rtk._drag_candidates, {widget, false})
end

function rtk.Event:is_widget_pressed(widget)
    return rtk._pressed_widgets and rtk._pressed_widgets[widget.id] and true or false
end

function rtk.Event:set_button_state(key, value)
    rtk.mouse.state[self.button][key] = value
end

function rtk.Event:get_button_state(key)
    local s = rtk.mouse.state[self.button]
    return s and s[key]
end

--- Set the various modifier attributes according to the mouse/keyboard
-- modifier state (per REAPER's `gfx.mouse_cap`).
--
-- This is called by `rtk.Window` when a new event is generated.
--
-- @tparam number cap the bitmap containing mouse/keyboard state
-- @tparam number button the specific mouse button that triggered the event
--  per @{rtk.mouse|mouse button constants}
function rtk.Event:set_modifiers(cap, button)
    self.modifiers = cap & (4 | 8 | 16 | 32)
    self.ctrl = cap & 4 ~= 0
    self.shift = cap & 8 ~= 0
    self.alt = cap & 16 ~= 0
    self.meta = cap & 32 ~= 0
    self.buttons = cap & (1 | 2 | 64)
    self.button = button
end

--- Marks the event as having been `handled`.
--
-- Once an event is handled, it won't be actioned by any other widget.  So event
-- handlers can prevent handlers for other widgets with lower z-indexes from
-- responding to an event by calling this method.
--
-- @tparam rtk.Widget|nil widget the widget that handled the event
function rtk.Event:set_handled(widget)
    self.handled = widget or true
end

--- Clone the event.
--
-- @tparam table overrides replaces the attributes in the cloned event
--   with the given table.
-- @treturn rtk.Widget a new event object
function rtk.Event:clone(overrides)
    local event = rtk.Event()
    for k, v in pairs(self) do
        event[k] = v
    end
    event.handled = nil
    table.merge(event, overrides or {})
    return event
end