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

--- A dual- or tri-state checkbox with optional label.  Checkboxes are specially styled
-- buttons, so any attribute from `rtk.Button` applies here as well.
--
-- @code
--   local cb = rtk.CheckBox{'Synchronize cardinal grammeters'}
--   container:add(cb)
--   cb.onchange = function(self)
--      app.config.synchronize = self.value
--   end
--
-- @class rtk.CheckBox
-- @inherits rtk.Button
rtk.CheckBox = rtk.class('rtk.CheckBox', rtk.Button)
rtk.CheckBox.static._icon_unchecked = nil

--- CheckBox Type Constants.
--
-- These constants apply to the `type` attribute.
--
-- @section checkboxtypeconst
-- @compact


--- A conventional dual state checkbox (default)
-- @meta 'dualstate'
rtk.CheckBox.static.DUALSTATE = 0
--- A tri-state checkbox with includes checked, unchecked, plus an indeterminate state.
-- @meta 'tristate'
rtk.CheckBox.static.TRISTATE = 1

--- CheckBox State Constants.
--
-- These constants apply to the `value` attribute.
--
-- @section checkboxstateconst
-- @compact

--- The checkbox is unchecked (off).
-- @meta 'unchecked'
rtk.CheckBox.static.UNCHECKED = false
--- The checkbox is checked (on).
-- @meta 'checked'
rtk.CheckBox.static.CHECKED = true
--- The checkbox is neither checked nor unchecked but an indeterminate middle state.
-- @meta 'indeterminate'
rtk.CheckBox.static.INDETERMINATE = 2


-- One-time initialization of checkbox icon images for various states.
function rtk.CheckBox.static._make_icons()
    -- TODO: support different scales
    local w, h = 18, 18
    local wp, hp = 2, 2
    local colors
    if rtk.theme.dark then
        colors = {
            border = {1, 1, 1, 0.90},
            fill = {1, 1, 1, 1},
            check = {0, 0, 0, 1},
            checkaa = {0.4, 0.4, 0.4, 1},
            iborder = {1, 1, 1, 0.92},
        }
    else
        colors = {
            border = {0, 0, 0, 0.90},
            fill = {0, 0, 0, 1},
            check = {1, 1, 1, 1},
            checkaa = {0.6, 0.6, 0.6, 1},
            iborder = {0, 0, 0, 0.92},
        }
    end

    --
    -- Unchecked icon
    --
    local icon = rtk.Image(w, h)
    icon:pushdest()
    rtk.color.set(colors.border)
    rtk.gfx.roundrect(wp, hp, w - wp*2, h - hp*2, 2, 1)
    gfx.rect(wp+1, hp+1, w - wp*2 - 2, h - hp*2 - 2, 0)
    icon:popdest()
    rtk.CheckBox.static._icon_unchecked = icon

    --
    -- Checked icon
    --
    icon = rtk.Image(w, h)
    icon:pushdest()
    rtk.color.set(colors.fill)
    rtk.gfx.roundrect(wp, hp, w - wp*2, h - hp*2, 2, 1)
    -- Fill
    rtk.color.set(colors.fill)
    gfx.rect(wp+1, hp+1, w - wp*2 - 2, h - hp*2 - 2, 1)
    -- Checkmark
    -- Lighter pass
    rtk.color.set(colors.checkaa)
    gfx.x = wp + 3
    gfx.y = hp + 6
    gfx.lineto(wp+5, hp+9)
    gfx.lineto(wp+10, hp+3)
    -- Bolder pass
    rtk.color.set(colors.check)
    gfx.x = wp + 2
    gfx.y = hp + 6
    gfx.lineto(wp+5, hp+10)
    gfx.lineto(wp+11, hp+3)
    icon:popdest()
    rtk.CheckBox.static._icon_checked = icon

    --
    -- Indeterminate icon
    --
    icon = rtk.CheckBox.static._icon_unchecked:clone()
    icon:pushdest()
    -- Fill
    rtk.color.set(colors.iborder)
    gfx.rect(wp+3, hp+3, w - wp*2 - 6, h - hp*2 - 6)
    rtk.color.set(colors.fill)
    gfx.rect(wp+4, hp+4, w - wp*2 - 8, h - hp*2 - 8, 1)
    icon:popdest()
    rtk.CheckBox.static._icon_intermediate = icon

    -- Use accented version of unchecked icon as a hover icon
    rtk.CheckBox.static._icon_hover = rtk.CheckBox.static._icon_unchecked:clone():recolor(rtk.theme.accent)
end

--- Class API.
-- @section api
rtk.CheckBox.register{
    --- The type of checkbox, whether dual or tri state (default `DUALSTATE`).
    --
    -- @meta read/write
    -- @type checkboxtypeconst
    type = rtk.Attribute{
        default=rtk.CheckBox.DUALSTATE,
        calculate={
            dualstate=rtk.CheckBox.DUALSTATE,
            tristate=rtk.CheckBox.TRISTATE
        },
    },

    --- Optional text label for the checkbox (default nil).
    --
    -- This attribute may be passed as the first positional argument during initialization.
    -- (In other words, `rtk.CheckBox{'Foo'}` is equivalent to `rtk.CheckBox{label='Foo'}`.)
    --
    -- @type string|nil
    -- @meta read/write
    label = nil,

    --- The current (or desired if setting) value of the checkbox.
    --
    -- The strings `'checked'`, `'unchecked'`, and `'indeterminate'` also work here and
    -- when set with `attr()` they will be calculated as one of the
    -- @{checkboxstateconst|state constants}.
    --
    -- @note Truthiness is preserved
    --   The @{checkboxstateconst|checkbox state constants} use booleans for `UNCHECKED` and
    --   `CHECKED`, so truthy evaluations work as you'd intuitively expect:
    --      @code
    --        local cb = rtk.CheckBox()
    --        -- This is safe.
    --        if cb.value then
    --            log.info('checkbox is checked')
    --        end
    --        -- This is equivalent, and actually recommended from a readability standpoint.
    --        if cb.value == rtk.CheckBox.CHECKED then
    --            log.info('yep, still checked')
    --        end
    --
    -- @meta read/write
    -- @type checkboxstateconst
    value = rtk.Attribute{
        default=rtk.CheckBox.UNCHECKED,
        calculate={
            [rtk.Attribute.NIL]=rtk.CheckBox.UNCHECKED,
            checked=rtk.CheckBox.static.CHECKED,
            unchecked=rtk.CheckBox.static.UNCHECKED,
            indeterminate=rtk.CheckBox.static.INDETERMINATE,
        }
    },

    -- rtk.Button overrides
    icon = rtk.Attribute{
        default=function(self, attr)
            -- Icons are lazy-created at first instantiation so this needs to be
            -- a dynamic default.
            return self._value_map[rtk.CheckBox.UNCHECKED]
        end,
    },

    surface = false,
    valign = rtk.Widget.TOP,
    wrap = true,
    tpadding = 0,
    rpadding = 0,
    lpadding = 0,
    bpadding = 0,
}

function rtk.CheckBox:initialize(attrs, ...)
    if rtk.CheckBox.static._icon_unchecked == nil then
        rtk.CheckBox._make_icons()
    end
    self._value_map = {
        [rtk.CheckBox.UNCHECKED] = rtk.CheckBox._icon_unchecked,
        [rtk.CheckBox.CHECKED] = rtk.CheckBox._icon_checked,
        [rtk.CheckBox.INDETERMINATE] = rtk.CheckBox._icon_intermediate
    }
    rtk.Button.initialize(self, attrs, self.class.attributes.defaults, ...)
    self:_handle_attr('value', self.value)
end

function rtk.CheckBox:_handle_click(event)
    local ret = rtk.Button._handle_click(self, event)
    if ret == false then
        return ret
    end
    self:toggle()
    return ret
end

function rtk.CheckBox:_handle_attr(attr, value, oldval, trigger, reflow)
    local ret = rtk.Button._handle_attr(self, attr, value, oldval, trigger, reflow)
    if ret ~= false then
        if attr == 'value' then
            self.calc.icon = self._value_map[value] or self._value_map[rtk.CheckBox.UNCHECKED]
            if trigger then
                self:onchange()
            end
        end
    end
    return ret
end

function rtk.CheckBox:_draw_icon(x, y, hovering, alpha)
    rtk.Button._draw_icon(self, x, y, hovering, alpha)
    if hovering then
        rtk.CheckBox._icon_hover:draw(x, y, alpha, rtk.scale.value)
    end
end

--- Toggle to the next state of the checkbox.
--
-- For a `DUALSTATE` checkbox, this simply toggles between `CHECKED` and `UNCHECKED`.
-- For `TRISTATE` checkboxes, the `INDETERMINATE` state will follow `CHECKED` and then
-- cycle back to `UNCHECKED`.
--
-- The `value` attribute is updated after this function is called.
-- @treturn rtk.CheckBox returns self for method chaining
function rtk.CheckBox:toggle()
    local value = self.calc.value
    -- All this would be easier if the states were numeric, but we want to preserve
    -- truthiness of unchecked/checked so we're mixing booleans and numbers which
    -- makes all this a bit uglier.
    --
    -- Unknown values are interpreted as unchecked
    if self.calc.type == rtk.CheckBox.DUALSTATE then
        if value == rtk.CheckBox.CHECKED then
            value = rtk.CheckBox.UNCHECKED
        else
            value = rtk.CheckBox.CHECKED
        end
    else
        if value == rtk.CheckBox.CHECKED then
            value = rtk.CheckBox.INDETERMINATE
        elseif value == rtk.CheckBox.INDETERMINATE then
            value = rtk.CheckBox.UNCHECKED
        else
            value = rtk.CheckBox.CHECKED
        end
    end
    self:sync('value', value)
    return self
end

--- Event Handlers.
--
-- See also @{widget.handlers|handlers for rtk.Widget}.
--
-- @section checkbox.handlers


--- Called when the checkbox value changes.
--
-- The `value` attribute reflects the current state.
--
-- @treturn nil Return value has no significance. This is a notification event only.
function rtk.CheckBox:onchange() end