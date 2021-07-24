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

require('rtk.type')
require('rtk.utils')
require('rtk.future')
require('rtk.animate')
require('rtk.color')
require('rtk.font')
require('rtk.event')
require('rtk.image')
require('rtk.shadow')
require('rtk.nativemenu')

require('rtk.widget')
require('rtk.viewport')
require('rtk.popup')
require('rtk.container')
require('rtk.window')
require('rtk.box')
require('rtk.vbox')
require('rtk.hbox')
require('rtk.flowbox')
require('rtk.spacer')
require('rtk.button')
require('rtk.entry')
require('rtk.text')
require('rtk.heading')
require('rtk.imagebox')
require('rtk.optionmenu')
require('rtk.checkbox')
require('rtk.application')

-- Load other modules into the rtk namespace
rtk.log = require('rtk.log')

local function init()
    rtk.script_path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
    rtk.reaper_hwnd = reaper.GetMainHwnd()
    -- Tweaks based on current platform
    if rtk.os.mac then
        rtk.font.multiplier = 0.8
    elseif rtk.os.linux then
        rtk.font.multiplier = 0.7
    end
    -- Initialize default theme based on REAPER background color, or if
    -- the background can't be determined (REAPER version before 6.11 without
    -- SWS) then we just pick a dark grey as fallback.
    rtk.set_theme_by_bgcolor(rtk.color.get_reaper_theme_bg() or '#262626')
    -- Flag to indicate this theme was not set by explicit user call to rtk.set_theme()
    rtk.theme.default = true
end

init()

return rtk
