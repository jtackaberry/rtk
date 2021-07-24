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

--- A simple "no-op" widget that can be used affect spacing in containers, or as
-- a blank canvas for custom drawing via `ondrawpre()` and `ondraw()`, which can be
-- convenient for simple drawing as opposed to creating a custom subclass of `rtk.Widget`.
--
-- @example
--  -- Create a spacer that's half the width and height of its parent
--  local spacer = rtk.Spacer{w=0.5, h=0.5, bg='gainsboro'}
--  -- Add the spacer centered on the window (so now the spacer will be
--  -- half the width/height of the window)
--  window:add(spacer, {halign='center', valign='center'})
--  -- Create a custom draw handler that draws a circle centered in the
--  -- spacer's calculated box.
--  spacer.ondraw = function(self, offx, offy, alpha, event)
--      self:setcolor('dodgerblue', alpha)
--      -- Must draw relative to the supplied offx, offy.
--      gfx.circle(
--          offx + self.calc.x + self.calc.w/2,
--          offy + self.calc.y + self.calc.h/2,
--          math.min(self.calc.w, self.calc.h)/2.5,
--          1, -- fill
--          1  -- antialias
--      )
--  end
--
-- @class rtk.Spacer
-- @inherits rtk.Widget
rtk.Spacer = rtk.class('rtk.Spacer', rtk.Widget)

function rtk.Spacer:initialize(attrs, ...)
    rtk.Widget.initialize(self, attrs, rtk.Spacer.attributes.defaults, ...)
end

function rtk.Spacer:_draw(offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    rtk.Widget._draw(self, offx, offy, alpha, event, clipw, cliph, cltargetx, cltargety, parentx, parenty)
    local calc = self.calc
    local y = calc.y + offy
    if y + calc.h < 0 or y > cliph or self.calc.ghost then
        -- Widget would not be visible on current drawing target
        return false
    end
    self:_handle_drawpre(offx, offy, alpha, event)
    self:_draw_bg(offx, offy, alpha, event)
    self:_draw_borders(offx, offy, alpha)
    self:_handle_draw(offx, offy, alpha, event)
end