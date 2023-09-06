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

--- Like `rtk.Text` but provides slightly different default styling suitable for
-- section headings.
--
-- Specifically, the @{rtk.themes.heading_font|heading_font} field from the current theme
-- is used as the heading widget's default font.
--
-- @example
--   vbox:add(rtk.Heading{'Appearance Settings', bmargin=15})
--   vbox:add(rtk.CheckBox{'Use borderless window when undocked'}
--
-- @class rtk.Heading
-- @inherits rtk.Text
-- @see rtk.Text
rtk.Heading = rtk.class('rtk.Heading', rtk.Text)
rtk.Heading.register{
    color = rtk.Attribute{
        default=function(self, attr)
            return rtk.theme.heading or rtk.theme.text
        end
    },
}

function rtk.Heading:initialize(attrs, ...)
    self._theme_font = self._theme_font or rtk.theme.heading_font or rtk.theme.default_font
    rtk.Text.initialize(self, attrs, self.class.attributes.defaults, ...)
end