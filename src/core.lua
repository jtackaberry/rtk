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

local log = require('rtk.log')

--- Main rtk module.  All functions and submodules across rtk are anchored under
-- this namespace.
--
-- @module rtk
--
-- Fields not marked as **read-only** are user-settable values that control rtk's
-- global behavior and appearance.  Read-only fields are automatically updated
-- by rtk throughout program execution (as appropriate).
local rtk = {
    --
    -- User-settable values that control rtk's global behavior and appearance.
    --

    --- Set to true to enable touch scrolling, where scrolling `rtk.Viewport` is possible
    -- by click-dragging within them, which is suitable for touchscreen displays (default
    -- false).
    --
    -- When this is enabled, certain interactions that normally occur immediately upon
    -- mouse-down (such as opening the popup menu of an `rtk.OptionMenu`) will be deferred
    -- until `touch_activate_delay` elapses, or in some cases until mouse up, giving the
    -- user the opportunity to touch scroll.
    --
    -- Touch scrolling in rtk also supports kinetic scrolling.
    --
    -- @meta read/write
    -- @type boolean
    touchscroll = false,

    --- If true, scrolling viewports with the mouse wheel or programmatically will
    -- animate (default true). This affects the default for all viewports, but individual
    -- viewports can override this with the `rtk.Viewport.smoothscroll` attribute.
    --
    -- REAPER limits scripts to 25-30fps (Windows being around 30 while Linux and OS X are
    -- closer to 25), so it can only ever really get so "smooth" but it's a useful enough
    -- effect that it's enabled by default.
    --
    -- @meta read/write
    -- @type boolean
    smoothscroll = true,

    --- When `touchscroll` is enabled, this is the default amount of time in seconds
    -- that widgets will wait before responding to a "mouse down" event (which equates to
    -- a touch event for touchscreen displays) (default 0.1 seconds).  This can be overridden
    -- per widget: see `rtk.Widget.touch_activate_delay` for more.
    -- @meta read/write
    -- @type number
    touch_activate_delay = 0.1,

    --- Number of seconds the mouse is pressed over a widget before
    -- `rtk.Widget:onlongpress()` fires (default `0.5`)
    -- @meta read/write
    -- @type number
    long_press_delay = 0.5,
    --- Interval between successive clicks before `rtk.Widget:ondoubleclick()`
    -- fires (default `0.5`)
    -- @meta read/write
    -- @type number
    double_click_delay = 0.5,
    --- Number of seconds where the mouse remains stationary over a widget before its
    -- @{rtk.Widget.tooltip|tooltip} pops up (default `0.5`).
    -- @meta read/write
    -- @type number
    tooltip_delay = 0.5,
    --- When the luminance of a color (as returned by @{rtk.color.luma()})
    -- is above this value then the color is considered "light" for purposes of picking
    -- appropriately contrasting text and icon colors (default `0.6`)
    -- @meta read/write
    -- @type number
    light_luma_threshold = 0.6,
    --- Enables visual inspection of widget geometry by mousing over them (default `false`).
    --
    -- When enabled, mousing over a widget will paint boxes indicating its
    -- calculated geometry and padding boundaries, and will display a tooltip
    -- showing those values.  When multiple widgets are stacked atop each other,
    -- the widget with the highest z-index will win.
    --
    -- When `log.level` is set to `log.DEBUG` or lower, pressing F12 will toggle
    -- this value if the `rtk.Event.KEY` event is unhandled.
    -- @meta read/write
    -- @type boolean
    debug = false,


    --
    -- Values set and managed by rtk
    --

    --- true if the JS_ReaScriptAPI extension is installed, false otherwise
    -- @meta read-only
    -- @type boolean
    has_js_reascript_api = (reaper.JS_Window_GetFocus ~= nil),
    --- true if the SWS extension is installed
    -- @meta read-only
    -- @type boolean
    has_sws_extension = (reaper.BR_Win32_GetMonitorRectFromRect ~= nil),
    --- The full path to the directory containing the script that the REAPER
    -- action invoked.  The trailing path separator is always included.
    -- @meta read-only
    -- @type string
    script_path = nil, -- set in init()
    --- hwnd of Reaper's main window
    -- @meta read-only
    -- @type userdata
    reaper_hwnd = nil, -- set in init()
    --- Frame rate (measured on each update cycle of the main window)
    -- @meta read-only
    -- @type number
    fps = 30,
    --- The hwnd of the currently focused window, or nil if js_ReaScriptAPI is
    -- not installed
    -- @meta read-only
    -- @type userdata
    focused_hwnd = nil,
    --- The currently focused `rtk.Widget` (or nil if no widget is focused)
    -- @meta read-only
    -- @type boolean
    focused = nil,

    --- A table holding the current theme colors which is initialized via `rtk.set_theme()`.
    -- See `rtk.themes` for field details.
    -- @meta read-only
    -- @type table
    theme = nil,

    -- A stack of blit dest ids,
    _dest_stack = {},
    -- Paths registered via rtk.add_image_search_path(), where 'light' and 'dark'
    -- fields are lists holding light/dark icons, and positional elements are
    -- agnostic.
    _image_paths = {},
    -- A map of currently processing animations keyed on widget id and attr
    -- name.  Each entry is a table in the form: {widget, attribute name,
    -- easingfn, srcval, dstval, pct, pctstep, do_reflow, done}
    _animations = {},
    -- Number of elements in the _animations table because Lua is too lame to
    -- implement this directly.
    _animations_len = 0,
    -- Registered animation easing functions indexed by name
    _easing_functions = {},
    _frame_count = 0,
    _frame_time = nil,
    -- If defined, is a table of widgets (keyed by widget id) which are exclusively
    -- allowed to receive events.  Any widget not in the table will be effectively
    -- inert until rtk.reset_modal() is called (or the widget is registered with
    -- rtk.add_modal()).
    _modal = nil,
    -- This is either rtk.Event.MOUSEDOWN or MOUSEUP depending on whether touchscroll
    -- is true.  It describes the event that we use to perform some activation
    -- action, such as onclick() or determining whether modal widgets should be
    -- released.
    _touch_activate_event = nil,
    -- The debug.traceback() return value from the last error generated by a
    -- rtk.defer() function.
    _last_traceback = nil,
    -- The last error message from rtk.defer()
    _last_error = nil,
    -- If rtk.quit() was called, which prevents any further deferred calls.
    _quit = false,
    -- Ensure global refs are weak, so we don't leak orphaned widgets with a ref
    -- attribute.
    _refs = setmetatable({}, {__mode='v'}),
    -- If not nil, is a list of {func, args} that should be invoked on the next
    -- window update.  See rtk.callsoon().
    _run_soon = nil,
    _reactive_attr = {},
}

--- rtk.scale.
--
-- Controls the overall scale of the interface.
--
-- The fields in the `rtk.scale` table reflect the current scale values.  The `rtk.scale.user`
-- field is how you can adjust the overall scale of the `rtk.Window`.
--
-- @section rtk.scale
-- @scope rtk.scale
-- @fullnames
-- @compact

rtk.scale = setmetatable({
    --- User-defined scale factor (default `1.0`).  When this value is set, the window
    -- is automatically rescaled on the next update cycle.
    -- @type number
    -- @meta read-write
    user = nil,
    -- Internal value behind the 'user' proxy
    _user = 1.0,
    --- Scale factor determined by the system.  On retina displays, this value will be `2.0`.
    -- On Windows, with variable scale, this can be an arbitrary factor and updates in real
    -- time as the system global scale is modified.  This value is only known after
    -- `rtk.Window:open()` is called, and will be `nil` before then.
    -- @type number
    -- @meta read-only
    system = nil,
    --- REAPER's custom scale modifier that is set via the "Advanced UI/system tweaks" button on
    -- the General settings page.  This value is only read once when `rtk.Window` is instantiated,
    -- so the script will need to be restarted if this preference is changed.
    -- @type number
    -- @meta read-only
    reaper = 1.0,
    --- The final calculated scale factor to which all UI elements scale themselves.  This is
    -- calculated as `user` * `system` * `reaper`.
    --
    -- @note
    --  If you are implementing widgets or manually drawing, `rtk.scale.value` is the value all
    --  coordinates and dimensions should be multiplied by.
    --
    -- @type number
    -- @meta read-only
    value = 1.0,
}, {
    __index=function(t, key)
        return key == 'user' and t._user
    end,
    __newindex=function(t, key, value)
        if key == 'user' then
            if value ~= t._user then
                t._user = value
                t.value = value * (t.system or 1.0) * t.reaper
                if rtk.window then
                    rtk.window:queue_reflow()
                end
            end
        else
            rawset(t, key, value)
        end
    end
})

--- rtk.dnd.
--
-- Holds the state of the current drag-and-drop operation (if any).
--
-- @table rtk.dnd
-- @fullnames
rtk.dnd = {
    --- The currently dragging `rtk.Widget` (or nil if none), which is set when
    -- the user drags a widget and that widget's `rtk.Widget:ondragstart()`
    -- handler returns a value that approves the drag operation.
    -- @meta read-only
    -- @type rtk.Widget|nil
    dragging = nil,
    --- true if the currently `dragging` widget is eligible to be dropped and false
    -- otherwise.  When false, it means ondrop*() handlers will never be called.
    -- This is implicitly set based on the return value of the widget's
    -- `rtk.Widget:ondragstart()` handler.  This is useful for drag-only
    -- widgets such scrollbars that want to leverage the global drag-handling
    -- logic without any need for droppability.
    -- @meta read-only
    -- @type boolean
    droppable = nil,
    -- The current drop target of the currently dragging widget (or nil if
    -- not dragging or not currently over a valid top target)
    -- @meta read-only
    -- @type rtk.Widget|nil
    dropping = nil,
    --- The user argument as returned by `rtk.Widget:ondragstart()` for the currently
    -- `dragging` widget
    -- @meta read-only
    -- @type any
    arg = nil,
    --- A bitmap of mouse button constants (@{rtk.mouse.BUTTON_LEFT|BUTTON_LEFT},
    -- @{rtk.mouse.BUTTON_MIDDLE|BUTTON_MIDDLE}, or @{rtk.mouse.BUTTON_RIGHT|BUTTON_RIGHT})
    -- that were pressed when the drag operation began.  This mouse button(s) needs to
    -- be released in order for `rtk.Widget:ondragend()` to fire.
    -- @type rtk.mouse
    -- @meta read-only
    buttons = nil,
}

local _os = reaper.GetOS():lower():sub(1, 3)
--- rtk.os.
--
-- These fields are available immediately upon loading the `rtk` module.
--
-- @table rtk.os
-- @compact
-- @fullnames
rtk.os = {
    --- true if running on Mac OS X, false otherwise
    mac = (_os == 'osx'),
    --- true if running on Windows, false otherwise
    windows = (_os == 'win'),
    --- true if running on Linux, false otherwise
    linux = (_os == 'lin' or _os == 'oth'),
}

--- rtk.mouse.
--
-- Although this table will include the current mouse coordinates and buttons
-- pressed, you're strongly encouraged to use the fields from `rtk.Event` instead.
-- You can use these fields only when an event isn't available (although it almost
-- always is).
--
-- @table rtk.mouse
-- @compact
rtk.mouse = {
    --- Left mouse button (used in `down` and `rtk.Event.button`)
    BUTTON_LEFT = 1,
    --- Middle mouse button (used in `down` and `rtk.Event.button`)
    BUTTON_MIDDLE = 64,
    --- Right mouse button (used in `down` and `rtk.Event.button`)
    BUTTON_RIGHT = 2,
    BUTTON_MASK = (1 | 2 | 64),
    --- x coordinate of last mouse position, relative to gfx window.  See also `rtk.Event.x`,
    --  which is preferred if an event instance is available.
    x = 0,
    --- y coordinate of last mouse position, relative to gfx window. See also `rtk.Event.y`,
    -- which is preferred if an event instance is available.
    y = 0,
    --- Bitmap of `BUTTON_*` constants indicating mouse buttons currently pressed. See also `rtk.Event.buttons`.
    down = 0,
    state = {order={}}
}

local _load_cursor
if rtk.has_js_reascript_api then
    -- Note we use the js_ReaScriptAPI even for OS cursors as this is more robust.
    -- gfx.setcursor() is a bit janky and since the extension is available we can
    -- avoid it.
    function _load_cursor(cursor)
        return reaper.JS_Mouse_LoadCursor(cursor)
    end
else
    function _load_cursor(cursor)
        return cursor
    end
end

--- rtk.mouse.cursors.
--
-- Constants that can be assigned to `rtk.Widget.cursor` or passed to
-- `rtk.Window:request_mouse_cursor()`.
--
-- Cursors marked as Windows only will fall back to the standard `POINTER` on Mac and Linux.
--
-- @example
--   -- Creates a button that shows the "invalid" mouse cursor when the mouse hovers over it.
--   local button = rtk.Button{label='Click at your peril', cursor=rtk.mouse.cursors.INVALID}
--   button.onclick = function(self, event)
--       button:attr('label', "I see you're a gambler")
--       button:attr('cursor', rtk.mouse.cursors.REAPER_TREBLE_CLEF)
--   end
--   container:add(button)
--
-- @note
--  Versions of REAPER prior to 6.24rc3 [had a bug](https://forum.cockos.com/showthread.php?t=249619)
--  where the cursor would not change until the mouse moves, and wouldn't change at all when the
--  mouse button was pressed.  If js_ReaScriptAPI is available, rtk will avoid this bug even on
--  older versions of REAPER.
--
-- @table rtk.mouse.cursors
-- @alias cursorconst
-- @compact
rtk.mouse.cursors = {
    --- Cursor is not defined, in which case the window will default to `POINTER`
    UNDEFINED = 0,
    --- Standard pointer
    -- @meta ![POINTER]()
    POINTER = _load_cursor(32512),
    --- I-beam used for text fields
    -- @meta ![BEAM]()
    BEAM = _load_cursor(32513),
    --- Indicates the window is currently no responsive (Windows only)
    -- @meta ![LOADING]()
    LOADING = _load_cursor(32514),
    --- Used for precision pointing (Windows only)
    -- @meta ![CROSSHAIR]()
    CROSSHAIR = _load_cursor(32515),
    --- An up arrow
    -- @meta ![UP_ARROW]()
    UP_ARROW = _load_cursor(32516),
    -- XXX: these next two are backward on Linux
    --- Resize cursor from north-west to south-east (width/height resize)
    -- @meta ![SIZE_NW_SE]()
    SIZE_NW_SE = _load_cursor(rtk.os.linux and 32643 or 32642),
    --- Resize cursor from south-west to north-east (width/height resize)
    -- @meta ![SIZE_SW_NE]()
    SIZE_SW_NE = _load_cursor(rtk.os.linux and 32642 or 32643),
    --- Resize cursor from east to west (width-only resize)
    -- @meta ![SIZE_EW]()
    SIZE_EW = _load_cursor(32644),
    --- Resize cursor from north to south (height-only resize)
    -- @meta ![SIZE_NS]()
    SIZE_NS = _load_cursor(32645),
    --- Move a window in any direction
    -- @meta ![MOVE]()
    MOVE = _load_cursor(32646),
    --- Indicates the mouse position is an invalid target
    -- @meta ![INVALID]()
    INVALID = _load_cursor(32648),
    --- A hand pointer for hyperlink selection
    -- @meta ![HAND]()
    HAND = _load_cursor(32649),
    --- Standard pointer with a loading icon (Windows only)
    -- @meta ![POINTER_LOADING]()
    POINTER_LOADING = _load_cursor(32650),
    --- Standard pointer with a question mark (Windows only)
    -- @meta ![POINTER_HELP]()
    POINTER_HELP = _load_cursor(32651),

    --- Adjust fade-in curve at start of media item
    -- @meta ![REAPER_FADEIN_CURVE]()
    REAPER_FADEIN_CURVE = _load_cursor(105),
    --- Adjust fade-out curve at start of media item
    -- @meta ![REAPER_FADEOUT_CURVE]()
    REAPER_FADEOUT_CURVE = _load_cursor(184),
    --- Adjust fade-out and fade-in curves between two items
    -- @meta ![REAPER_CROSSFADE]()
    REAPER_CROSSFADE = _load_cursor(463),
    --- Drag-and-drop-copy item
    -- @meta ![REAPER_DRAGDROP_COPY]()
    REAPER_DRAGDROP_COPY = _load_cursor(182),
    --- Mouse pointer indicating dragging an item to the right
    -- @meta ![REAPER_DRAGDROP_RIGHT]()
    REAPER_DRAGDROP_RIGHT = _load_cursor(1011),

    --- Standard mouse pointer with stereo audio plug beneath
    -- @meta ![REAPER_POINTER_ROUTING]()
    REAPER_POINTER_ROUTING = _load_cursor(186),
    --- Standard mouse pointer with quad-arrow move icon
    -- @meta ![REAPER_POINTER_MOVE]()
    REAPER_POINTER_MOVE = _load_cursor(187),
    --- Standard mouse pointer with a dotted square indicating marquee select
    -- @meta ![REAPER_POINTER_MARQUEE_SELECT]()
    REAPER_POINTER_MARQUEE_SELECT = _load_cursor(488),
    --- Standard mouse pointer with an X on the bottom right indicating a delete action
    -- @meta ![REAPER_POINTER_DELETE]()
    REAPER_POINTER_DELETE = _load_cursor(464),
    --- Standard mouse pointer with left/right arrows on the bottom right
    -- @meta ![REAPER_POINTER_LEFTRIGHT]()
    REAPER_POINTER_LEFTRIGHT = _load_cursor(465),
    --- Standard mouse pointer with the letter A along the bottom right
    -- @meta ![REAPER_POINTER_ARMED_ACTION]()
    REAPER_POINTER_ARMED_ACTION = _load_cursor(434),

    --- Diamond marker with arrows to the left and right
    -- @meta ![REAPER_MARKER_HORIZ]()
    REAPER_MARKER_HORIZ = _load_cursor(188),
    --- Diamond marker with arrows above and below
    -- @meta ![REAPER_MARKER_VERT]()
    REAPER_MARKER_VERT = _load_cursor(189),
    --- Up/down arrows with a tuning fork (?) to the right
    -- @meta ![REAPER_ADD_TAKE_MARKER]()
    REAPER_ADD_TAKE_MARKER = _load_cursor(190),
    --- Treble clef with D major key signature
    -- @meta ![REAPER_TREBLE_CLEF]()
    REAPER_TREBLE_CLEF = _load_cursor(191),
    --- Left/right arrow with a left edge indicator
    -- @meta ![REAPER_BORDER_LEFT]()
    REAPER_BORDER_LEFT = _load_cursor(417),
    --- Left/right arrow with a right edge indicator
    -- @meta ![REAPER_BORDER_RIGHT]()
    REAPER_BORDER_RIGHT = _load_cursor(418),
    --- Up/down arrow with a top edge indicator
    -- @meta ![REAPER_BORDER_TOP]()
    REAPER_BORDER_TOP = _load_cursor(419),
    --- Up/down arrow with a bottom edge indicator
    -- @meta ![REAPER_BORDER_BOTTOM]()
    REAPER_BORDER_BOTTOM = _load_cursor(421),
    --- Left/right arrow indicating the middle point between two items
    -- @meta ![REAPER_BORDER_LEFTRIGHT]()
    REAPER_BORDER_LEFTRIGHT = _load_cursor(450),
    --- Left/right arrow centered on a vertical line
    -- @meta ![REAPER_VERTICAL_LEFTRIGHT]()
    REAPER_VERTICAL_LEFTRIGHT = _load_cursor(462),
    --- Left/right arrow on right edge of a grid
    -- @meta ![REAPER_GRID_RIGHT]()
    REAPER_GRID_RIGHT = _load_cursor(460),
    --- Left/right arrow on left edge of a grid
    -- @meta ![REAPER_GRID_LEFT]()
    REAPER_GRID_LEFT = _load_cursor(461),
    --- A gripped hand used for drag-moving
    -- @meta ![REAPER_HAND_SCROLL]()
    REAPER_HAND_SCROLL = _load_cursor(429),
    --- A right fist pointed right indicating pulling something to the left
    -- @meta ![REAPER_FIST_LEFT]()
    REAPER_FIST_LEFT = _load_cursor(430),
    --- A left fist pointed left indicating pulling something to the right
    -- @meta ![REAPER_FIST_RIGHT]()
    REAPER_FIST_RIGHT = _load_cursor(431),
    --- Two fists overlapping and pulling in opposite directions
    -- @meta ![REAPER_FIST_GOATSE]()
    REAPER_FIST_BOTH = _load_cursor(453),
    --- Pencil pointing up and to the left
    -- @meta ![REAPER_PENCIL]()
    REAPER_PENCIL = _load_cursor(185),
    --- A pencil pointing down and to the left with a drawn squiggle below
    -- @meta ![REAPER_PENCIL_DRAW]()
    REAPER_PENCIL_DRAW = _load_cursor(433),
    --- An eraser pointing down and to the left
    -- @meta ![REAPER_ERASER]()
    REAPER_ERASER = _load_cursor(472),
    --- A paint brush pointing down and to the left
    -- @meta ![REAPER_BRUSH]()
    REAPER_BRUSH = _load_cursor(473),
    --- A few stacked piano roll notes with an arrow pointing right
    -- @meta ![REAPER_ARP]()
    REAPER_ARP = _load_cursor(502),
    --- A few adjacent piano roll notes with an arrow pointing up
    -- @meta ![REAPER_CHORD]()
    REAPER_CHORD = _load_cursor(503),
    --- Right hand with index finger pointing up with an outlined plus sign
    -- @meta ![REAPER_TOUCHSEL]()
    REAPER_TOUCHSEL = _load_cursor(515),
    --- Two overlapping mouse pointers offset by a couple pixels in both directions
    -- @meta ![REAPER_SWEEP]()
    REAPER_SWEEP = _load_cursor(517),
    --- Upper left curved edge with arrows on either side pointing in opposite directions
    -- @meta ![REAPER_FADEIN_CURVE_ALT]()
    REAPER_FADEIN_CURVE_ALT = _load_cursor(525),
    --- Upper right curved edge with arrows on either side pointing in opposite directions
    -- @meta ![REAPER_FADEOUT_CURVE_ALT]()
    REAPER_FADEOUT_CURVE_ALT = _load_cursor(526),
    --- Two overlapping curves with a left/right arrow below
    -- @meta ![REAPER_XFADE_WIDTH]()
    REAPER_XFADE_WIDTH = _load_cursor(528),
    --- Two overlapping curves with separate left and right arrows on either side
    -- @meta ![REAPER_XFADE_CURVE]()
    REAPER_XFADE_CURVE = _load_cursor(529),
    --- Up and down arrows with a small crosshair in the middle
    -- @meta ![REAPER_EXTMIX_SECTION_RESIZE]()
    REAPER_EXTMIX_SECTION_RESIZE = _load_cursor(530),
    --- Up and down arrows with bottom border in the middle and a plus sign on the top right
    -- @meta ![REAPER_EXTMIX_MULTI_RESIZE]()
    REAPER_EXTMIX_MULTI_RESIZE = _load_cursor(531),
    --- `REAPER_EXTMIX_SECTION_RESIZE` but with a plus sign on the top right
    -- @meta ![REAPER_EXTMIX_MULTISECTION_RESIZE]()
    REAPER_EXTMIX_MULTISECTION_RESIZE = _load_cursor(532),
    --- `REAPER_EXTMIX_MULTI_RESIZE` without the plus sign
    -- @meta ![REAPER_EXTMIX_RESIZE]()
    REAPER_EXTMIX_RESIZE = _load_cursor(533),
    --- `REAPER_EXTMIX_SECTION_RESIZE` with a dotted-bordered diamond on the top right
    -- @meta ![REAPER_EXTMIX_ALLSECTION_RESIZE]()
    REAPER_EXTMIX_ALLSECTION_RESIZE = _load_cursor(534),
    --- `REAPER_XFADE_CURVE` with a dotted-bordered diamond on the top right
    -- @meta ![REAPER_EXTMIX_ALL_RESIZE]()
    REAPER_EXTMIX_ALL_RESIZE = _load_cursor(535),
    --- A magnifying glass
    -- @meta ![REAPER_ZOOM]()
    REAPER_ZOOM = _load_cursor(1009),
    --- Narrow, more steeply angled mouse pointer pointing to the left
    -- @meta ![REAPER_INSERT_ROW]()
    REAPER_INSERT_ROW = _load_cursor(1010),

    --- Razor blade (Reaper 6.24+)
    -- @meta ![REAPER_RAZOR]()
    REAPER_RAZOR = _load_cursor(599),
    --- Razor blade with quad-arrow move icon (Reaper 6.24+)
    -- @meta ![REAPER_RAZOR_MOVE]()
    REAPER_RAZOR_MOVE = _load_cursor(600),
    --- Razor blade with an outlined plus sign (Reaper 6.24+)
    -- @meta ![REAPER_RAZOR_ADD]()
    REAPER_RAZOR_ADD = _load_cursor(601),
    --- Up/down arrow with vertically oriented brace brackets (Reaper 6.29+)
    -- @meta ![REAPER_RAZOR_ENVELOPE_VERTICAL]()
    REAPER_RAZOR_ENVELOPE_VERTICAL = _load_cursor(202),
    --- Up/down arrow with ramp to right side (Reaper 6.29+)
    -- @meta ![REAPER_RAZOR_ENVELOPE_RIGHT_TILT]()
    REAPER_RAZOR_ENVELOPE_RIGHT_TILT = _load_cursor(203),
    --- Up/down arrow with ramp to left side (Reaper 6.29+)
    -- @meta ![REAPER_RAZOR_ENVELOPE_LEFT_TILT]()
    REAPER_RAZOR_ENVELOPE_LEFT_TILT = _load_cursor(204),
}


-- Font flags for gfx.setfont()
local FONT_FLAG_BOLD = string.byte('b')
local FONT_FLAG_ITALICS = string.byte('i') << 8
local FONT_FLAG_UNDERLINE = string.byte('u') << 16

--- rtk.font.
--
-- Font constants and settings to be used across the UI.
--
-- @table rtk.font
-- @compact
rtk.font = {
    --- Font flag for bold text
    BOLD = FONT_FLAG_BOLD,
    --- Font flag for italicized text
    ITALICS = FONT_FLAG_ITALICS,
    --- Font flag for underlined text
    UNDERLINE = FONT_FLAG_UNDERLINE,
    --- Global font size multiplier, automatically adjusted by platform
    multiplier = 1.0
}


--- rtk.keycodes.
--
-- Numeric keycode constants used with `rtk.Event.keycode`.
--
-- @table rtk.keycodes
-- @compact
rtk.keycodes = {
    --- Up arrow key
    UP = 30064,
    --- Down arrow key
    DOWN = 1685026670,
    --- Left arrow key
    LEFT = 1818584692,
    --- Right arrow key
    RIGHT = 1919379572,
    --- Enter key (alias for `ENTER`)
    RETURN = 13,
    --- Enter key (alias for `RETURN`)
    ENTER = 13,
    --- Space bar
    SPACE = 32,
    --- Backspace key
    BACKSPACE = 8,
    --- Escape key
    ESCAPE = 27,
    --- Tab key
    TAB = 9,
    --- Home key
    HOME = 1752132965,
    --- End key
    END = 6647396,
    --- Insert key
    INSERT = 6909555,
    --- Delete key
    DELETE = 6579564,
    --- F1 function key
    F1 = 26161,
    --- F2 function key
    F2 = 26162,
    --- F3 function key
    F3 = 26163,
    --- F4 function key
    F4 = 26164,
    --- F5 function key
    F5 = 26165,
    --- F6 function key
    F6 = 26166,
    --- F7 function key
    F7 = 26167,
    --- F8 function key
    F8 = 26168,
    --- F9 function key
    F9 = 26169,
    --- F10 function key
    F10 = 6697264,
    --- F11 function key
    F11 = 6697265,
    --- F12 function key
    F12 = 6697266,
}

--- rtk.themes.
--
-- A table of color/font themes used for rtk UIs, keyed on theme name.  There are two themes
-- out of the box:
--   * **dark**: a high contrast theme with a dark gray background
--   * **light**: a high contrast theme with a light gray background
--
-- You can add your own custom themes to this table and reference it by name in
-- `rtk.set_theme()`.
--
-- All colors must be specified in one of the @{colortype|supported color formats}. These
-- colors define defaults for various widgets, but colors can always be overridden on
-- specific widget instances.  All font values are in the form `{font face name, font
-- size}` or nil to use `default_font`.
--
-- Custom values need to be set before widgets are instantiated: changing afterward
-- doesn't dynamically update existing widgets.
--
-- Each theme table registered under `rtk.themes` contains the following fields:
-- @table rtk.themes
-- @compact
rtk.themes = {
    dark = {
        name = 'dark',
        --- true if the theme is dark (true here implies `light` is false)
        -- @type boolean
        dark = true,
        --- true if the theme is light (true here implies `dark` is false).
        -- @type boolean
        light = false,
        --- overall background color for the window over top all widgets are drawn
        -- and is the default color used by `rtk.Window` when `rtk.Window.bg` isn't explicitly
        -- specified
        -- @type colortype
        bg = '#252525',
        --- global default font (default is `{'Calibri', 18}`)
        -- @type table
        default_font = {'Calibri', 18},
        --- font used for tooltips (default is `{'Segoe UI (TrueType)', 16}`)
        -- @type table
        tooltip_font = {'Segoe UI (TrueType)', 16},
        --- background color of the tooltip (default is white)
        -- @type colortype
        tooltip_bg = '#ffffff',
        --- color of the tooltip text and border (default is black)
        -- @type colortype
        tooltip_text = '#000000',

        --- accent color used for things like mouseover highlights and selections
        -- @type colortype
        accent = '#47abff',
        --- used in areas where a more subdued accent color is needed
        -- @type colortype
        accent_subtle = '#306088',
        --- text color for text in widgets such as `rtk.Text` and `rtk.Entry`
        -- @type colortype
        text = '#ffffff',
        --- a more subdued text color useful for less obtrusive text, which can be
        -- used for example with a status bar
        -- @type colortype
        text_faded = '#bbbbbb',
        --- the default color for `rtk.Button` surfaces
        -- @type colortype
        button = '#555555',
        --- the default color for `rtk.Heading` text, which uses `text` if nil (default nil)
        -- @type colortype
        heading = nil,
        --- color of text in `rtk.Button` labels
        -- @type colortype
        button_label = '#ffffff',
        --- default font used for `rtk.Button` objects (defaults to `default_font`)
        -- @type table
        button_font = nil,
        --- a multiplier that is applied to each of `button_normal_gradient`,
        -- `button_hover_gradient` and `button_clicked_gradient` (defaults to `1`).  Set
        -- this to 0 to use a single solid color for all buttons globally.
        -- @type number
        button_gradient_mul = 1,
        --- Opacity of the black overlay for @{rtk.Button.tagged|tagged buttons} (default 0.32).
        -- @type number
        button_tag_alpha = 0.32,
        --- the degree of gradient in normal button surfaces (i.e. not hovering or clicked)
        -- from -1 to 1, where negative values get darker toward the bottom of the
        -- surface, and positive values get lighter. Use 0 to disable the gradient and use
        -- a single surface color.
        -- @type number
        button_normal_gradient = -0.37,
        --- multiplier appied to each color channel for the border of a button in its normal state
        -- @type number
        button_normal_border_mul = 0.7,
        --- like `button_gradient` but applies to buttons when the mouse hovers over it
        -- @type number
        button_hover_gradient = 0.17,
        --- a multiplier to the value channel (in HSV colorspace) of the button color
        -- when the mouse hovers over it
        -- @type number
        button_hover_brightness = 0.9,
        --- multiplier applied to each color channel of the button's surface when the mouse hovers over it
        -- @type number
        button_hover_mul = 1,
        --- like `button_border_mul` but applies to buttons when the mouse hovers over it
        -- @type number
        button_hover_border_mul = 1.1,
        --- like `button_gradient` but applies to buttons that are being clicked
        -- @type number
        button_clicked_gradient = 0.47,
        --- like `button_hover_brightness` but applies to buttons that are being clicked
        -- @type number
        button_clicked_brightness = 0.9,
        --- like `button_hover_mul` but applies to buttons that are being clicked
        -- @type number
        button_clicked_mul = 0.85,
        --- like `button_border_mul` but applies to buttons that are being clicked
        -- @type number
        button_clicked_border_mul = 1,

        --- Default font used for `rtk.Text` objects (defaults to `default_font`)
        -- @type table
        text_font = nil,
        --- Default font used for `rtk.Heading` objects (defaults to `{'Calibri', 26}`)
        -- @type table
        heading_font = {'Calibri', 26},

        --- Default font used for `rtk.Entry` objects (defaults to `default_font`)
        -- @type table
        entry_font = nil,
        --- the background color for `rtk.Entry` widgets
        -- @type colortype
        entry_bg = '#5f5f5f7f',
        --- the faded color for the optional placeholder of empty `rtk.Entry` widgets
        -- @type colortype
        entry_placeholder = '#ffffff7f',
        --- color of `rtk.Entry` borders when the mouse is hovering
        -- @type colortype
        entry_border_hover = '#3a508e',
        --- color of `rtk.Entry` borders when the widget is focused
        -- @type colortype
        entry_border_focused = '#4960b8',
        --- ackground color of selected text in an `rtk.Entry`
        -- @type colortype
        entry_selection_bg = '#0066bb',

        --- background color of `rtk.Popup` widgets (if nil defaults to `bg`).
        -- @type colortype|nil
        popup_bg = nil,
        --- a multiplier to the value channel (in HSV colorspace) of the window background
        -- (`bg`) to be used as the `rtk.Popup` background when `popup_bg` is not
        -- specified.
        -- @type number
        popup_bg_brightness = 1.5,
        --- the color of the shadow for `rtk.Popup` (alpha channel is respected)
        -- @type colortype
        popup_shadow = '#11111166',
        --- the border color of `rtk.Popup`s
        -- @type colortype
        popup_border = '#385074',
    },
    light = {
        name = 'light',
        light = true,
        dark = false,
        accent = '#47abff',
        accent_subtle = '#a1d3fc',
        bg = '#dddddd',
        default_font = {'Calibri', 18},
        tooltip_font = {'Segoe UI (TrueType)', 16},
        tooltip_bg = '#ffffff',
        tooltip_text = '#000000',
        button = '#dedede',
        button_label = '#000000',
        button_gradient_mul = 1,
        button_tag_alpha = 0.15,
        button_normal_gradient = -0.28,
        button_normal_border_mul = 0.85,
        button_hover_gradient = 0.12,
        button_hover_brightness = 1,
        button_hover_mul = 1,
        button_hover_border_mul = 0.9,
        button_clicked_gradient = 0.3,
        button_clicked_brightness = 1.0,
        button_clicked_mul = 0.9,
        button_clicked_border_mul = 0.7,
        text = '#000000',
        text_faded = '#555555',
        heading_font = {'Calibri', 26},
        entry_border_hover = '#3a508e',
        entry_border_focused = '#4960b8',
        entry_bg = '#00000020',
        entry_placeholder = '#0000007f',
        entry_selection_bg = '#9fcef4',
        popup_bg = nil,
        popup_bg_brightness = 1.5,
        popup_shadow = '#11111122',
        popup_border = '#385074',
    }
}

local function _postprocess_theme()
    local iconstyle = rtk.color.get_icon_style(rtk.theme.bg)
    rtk.theme.iconstyle = iconstyle
    -- Resolve all theme hex string color values to RGBA tables.
    for k, v in pairs(rtk.theme) do
        if type(v) == 'string' and v:byte(1) == 35 then
            local x = {rtk.color.rgba(v)}
            rtk.theme[k] = {rtk.color.rgba(v)}
        end
    end
end

--- Registers an image search path where images and icons can be found by
-- `rtk.Image.make_icon()` or `rtk.Image:load()`.
--
-- This should be called early in program execution, at least before any rtk objects are
-- created that would depend on this path.
--
-- Paths added with a non-nil iconstyle (either `light` or `dark`) are called *icon paths*
-- and will be searched by `rtk.Image.make_icon()`.  Here, `light` means light colored
-- icons that are suitable for low luminance themes, while `dark` are dark colored icons
-- appropriate for high luminance themes.
--
-- Paths registered *without* an icon style will be searched by `rtk.Image:load()`.
--
-- It is possible to register icon paths for only one icon style, in which case the
-- existing icon will be re-tinted if necessary.  See `rtk.Image.make_icon()` for more
-- details.
--
-- If a non-absolute path is specified, then it will be relative to `rtk.script_path`.
--
-- @tparam string path the fully qualified path within which to search for images
-- @tparam string|nil iconstyle if specified, it's either `light` or `dark` to indicate
--   which luminance the icons within the path are, and in which case path is searched
--   by `rtk.Image.make_icon()`.  If nil, the path is searched by `rtk.Image:load()`
function rtk.add_image_search_path(path, iconstyle)
    if not path:match('^%a:') and not path:match('^[\\/]') then
        path = rtk.script_path .. path
    end
    if iconstyle then
        assert(iconstyle == 'dark' or iconstyle == 'light', 'iconstyle must be either light or dark')
        local paths = rtk._image_paths[iconstyle] or {}
        paths[#paths+1] = path
        rtk._image_paths[iconstyle] = paths
    else
        rtk._image_paths[#rtk._image_paths+1] = path
    end
end

--- Initializes the UI theme.
--
-- If this function isn't called, then either the light or the dark theme will
-- automatically be selected based on the window's background color (which default to a
-- color based on REAPER's current theme).
--
-- @warning Not dynamic
--   The theme cannot currently be changed dynamically after widgets have been
--   instantiated. A restart of the script is necessary for theme changes to take effect.
--
-- @tparam string name The name of a theme added to `rtk.themes`.
--   `light` and `dark` exist by default.
-- @tparam table|nil overrides a table of fields that overrides those from the
--   requested theme
function rtk.set_theme(name, overrides)
    -- init() ensures rtk.theme is not nil
    name = name or rtk.theme.name
    assert(rtk.themes[name], 'rtk: theme "' .. name .. '" does not exist in rtk.themes')
    -- Clone source theme
    rtk.theme = {}
    table.merge(rtk.theme, rtk.themes[name])
    if overrides then
        table.merge(rtk.theme, overrides)
    end
    _postprocess_theme()
end

--- Initializes the UI theme appropriate for the given background color.
--
-- Similar to `rtk.set_theme` but decides whether the `dark` or `light` theme should
-- be used given the background color, in combination with `rtk.light_luma_threshold`.
-- It also overrides the theme's built-in background color to the given color.
--
-- @tparam string|table color the background color (format per `rtk.color.set()`)
-- @tparam table|nil overrides if specified, passed to `rtk.set_theme()`
function rtk.set_theme_by_bgcolor(color, overrides)
    local name = rtk.color.luma(color) > rtk.light_luma_threshold and 'light' or 'dark'
    overrides = overrides or {}
    overrides.bg = color
    rtk.set_theme(name, overrides)
end

--- Applies custom overrides to the in-the-box theme settings.
--
-- This function takes a table which can optionally contain `light` or
-- `dark` fields which in turn contain a table of overrides specific to
-- that theme.  Any other fields in the table be applied to both themes.
--
-- Some widgets in rtk are luma-adaptive, meaning they automatically adjust
-- certain colors based on the user-defined background.  As a result, it
-- may be desirable to customize both themes, even though your primary
-- theme is one or the other.
--
-- @example
--   rtk.set_theme_overrides({
--       -- Use solid-color button surfaces regardless of the theme.
--       button_gradient_mul = 0,
--       -- Apply lower contrast default text colors, which differ by theme
--       dark = {
--           text = '#bbbbbb'
--       },
--       light = {
--           text = '#666666'
--       }
--   })
-- @tparam table overrides a table of overrides that apply to all or specific themes
function rtk.set_theme_overrides(overrides)
    for _, name in ipairs({'dark', 'light'}) do
        if overrides[name] then
            rtk.themes[name] = table.merge(rtk.themes[name], overrides[name])
            if rtk.theme[name] then
                rtk.theme = table.merge(rtk.theme, overrides[name])
            end
            overrides[name] = nil
        end
    end
    -- Apply top-level overrides to both light and dark theme, plus the current
    -- theme.
    rtk.themes.dark = table.merge(rtk.themes.dark, overrides)
    rtk.themes.light = table.merge(rtk.themes.light, overrides)
    rtk.theme = table.merge(rtk.theme, overrides)
    _postprocess_theme()
end

--- Creates a custom rtk color theme.
--
-- After the theme has been created, you can set it via `rtk.set_theme()`.
--
-- @tparam string name the name of the custom theme, where `light` and `dark` are
--   reserved built-in themes and cannot be used
-- @tparam string|nil base the base theme from which to inherit default values (if set)
-- @tparam table overrides the table of theme overrides according to the
--   @{rtk.themes|theme fields}
function rtk.new_theme(name, base, overrides)
    assert(not base or rtk.themes[base], string.format('base theme %s not found', base))
    assert(not rtk.themes[name], string.format('theme %s already exists', name))
    local theme = base and table.shallow_copy(rtk.themes[base]) or {}
    rtk.themes[name] = table.merge(theme, overrides or {})
end


--- Registers one or more widgets to be treated as modal.
--
-- When at least one widget is registered as modal, the modal widgets will
-- exclusively receive events to the exclusion of all others.  Non-modal widgets
-- will be rendered inert until `rtk.reset_modal()` is called.  If a container is
-- registered as modal then all its child descendants will also receive events.
--
-- This is used by `rtk.Popup`, for example.
--
-- @tparam rtk.Widget ... one or more widgets to mark as modal
function rtk.add_modal(...)
    if rtk._modal == nil then
        rtk._modal = {}
    end
    local widgets = {...}
    for _, widget in ipairs(widgets) do
        rtk._modal[widget.id] = widget
    end
end

--- Check if the given widget (or any widget at all) has been registered
-- as modal via `rtk.add_modal()`.
--
-- If the given widget is a child of a modal container, then this function
-- will return.
--
-- @tparam rtk.Widget|nil widget a widget to check if modal, or nil to check
--   if *any* widget is modal.
-- @treturn bool true if the widget is considered modal, false otherwise
function rtk.is_modal(widget)
    if widget == nil then
        return rtk._modal ~= nil
    elseif rtk._modal then
        -- Check widget and all parents
        local w = widget
        while w do
            if rtk._modal[w.id] ~= nil then
                return true
            end
            w = w.parent
        end
    end
    return false
end

--- Removes all modal widget registrations, returning event routing to normal.
function rtk.reset_modal()
    rtk._modal = nil
end


--- Push a destination image id onto the stack for off-screen drawing.
--
-- The target for graphics operations will be the supplied image id
-- until a new image is pushed or `rtk.popdest()` is called.
--
-- This is a low level function and generally doesn't need to be called
-- directly by library users.  And even then, if using an `rtk.Image`,
-- `rtk.Image:pushdest()` is recommended instead.
--
-- @tparam int dest the buffer id to target for drawing
--
-- @code
--  local img = rtk.Image()
--  rtk.pushdest(img.id)
--
function rtk.pushdest(dest)
    rtk._dest_stack[#rtk._dest_stack + 1] = gfx.dest
    gfx.dest = dest
end

--- Pops the last image destination off the stack.
--
-- When the stack is empty, the `rtk.Window` will be the target for drawing.
function rtk.popdest(expect)
    gfx.dest = table.remove(rtk._dest_stack, #rtk._dest_stack)
end

-- A reaper.defer substitute that allows passing arguments and implements better
-- error handling.
local function _handle_error(err)
    rtk._last_error = err
    rtk._last_traceback = debug.traceback()
end

--- Callback invoked when any function called via `rtk.defer()` or `rtk.call()`
-- raises an error.
--
-- The default behavior logs the error (with stack trace) to the console and
-- aborts program execution, but it can be replaced by user-custom error
-- handling.
--
-- @tparam string err the error message
-- @tparam string traceback a multiline stack trace capturing where
--   the error occurred
function rtk.onerror(err, traceback)
    log.error("rtk: %s\n%s", err, traceback)
    log.flush()
    error(err)
end

--- Immediately call a function with the given arguments with error handling.
--
-- Errors generated by the invoked function will cause `rtk.onerror()` to
-- be called.
--
-- It is a good idea to invoke your script's entrypoint via `rtk.call()` as early as
-- possible to ensure you get useful error messages during any initial script setup.
--
-- @example
--   local rtk = require('rtk')
--   function main()
--       local window = rtk.Window()
--       window:add(rtk.Text{'Hello World'})
--       window:open()
--   end
--   rtk.call(main)
--
-- @tparam function func the function to invoke
-- @tparam any ... one or more arguments to pass to `func`
-- @treturn any the value(s) returned by `func`
function rtk.call(func, ...)
    if rtk._quit then
        -- Don't even execute if rtk.quit() was called, in case the callback
        -- sets up a deferred call.
        return
    end
    local ok, result = xpcall(func, _handle_error, ...)
    if not ok then
        rtk.onerror(rtk._last_error, rtk._last_traceback)
        return
    end
    return result
end

--- Registers a function (with arguments) to be called back by REAPER.
--
-- This wraps `reaper.defer()` with the ability to pass arguments to the function (a minor
-- convenience to avoid an anonymous function in common cases) and, more importantly,
-- error handling by means of using `rtk.call()`.
--
-- @tparam function func the function to invoke
-- @tparam any ... one or more arguments to pass to `func`
function rtk.defer(func, ...)
    local args = table.pack(...)
    reaper.defer(function()
        rtk.call(func, table.unpack(args, 1, args.n))
    end)
end

--- Calls a function (with arguments) after the specified duration.
--
-- @tparam number duration number of seconds to delay execution (can be fractional)
-- @tparam function func the function to invoke
-- @tparam any ... one or more arguments to pass to `func`
function rtk.callafter(duration, func, ...)
    local args = table.pack(...)
    local start = reaper.time_precise()
    local function sched()
        if reaper.time_precise() - start >= duration then
            rtk.call(func, table.unpack(args, 1, args.n))
        elseif not rtk._quit then
            reaper.defer(sched)
        end
    end
    sched()
end

--- Terminates the script, closing any open `rtk.Window`.
--
-- Unlike `rtk.Window:close()` which can keep the a script running provided there
-- are pending deferred calls (e.g. scheduled with `rtk.callafter()`), this function
-- abandons any deferred calls and exits immediately.
function rtk.quit()
    if rtk.window and rtk.window.running then
        rtk.window:close()
    end
    rtk._quit = true
end

return rtk
