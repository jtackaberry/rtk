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

--- A box container where children are arranged horizontally in columns.
--
-- @note API documentation
--   See the base class `rtk.Box` for documentation on the HBox interface.
--
-- @code
--   box = rtk.HBox{spacing=5, bpadding=10}
--   box:add(rtk.Text{"Name:"}, {valign='center'})
--   box:add(rtk.Entry())
-- @class rtk.HBox
-- @inherits rtk.Box
-- @see rtk.VBox
rtk.HBox = rtk.class('rtk.HBox', rtk.Box)

rtk.HBox.register{
    orientation = rtk.Box.HORIZONTAL
}

function rtk.HBox:initialize(attrs, ...)
    rtk.Box.initialize(self, attrs, self.class.attributes.defaults, ...)
end

-- TODO: there is too much in common here with VBox:_reflow_step2().  This needs
-- to be refactored better, by using more tables with indexes rather than unpacking
-- to separate variables.
function rtk.HBox:_reflow_step2(w, h, maxw, maxh, clampw, clamph, expand_unit_size, uiscale, viewport, window, greedyw, greedyh, tp, rp, bp, lp)
    local offset = 0
    local spacing = 0
    -- List of widgets and attrs whose height (or valign) depends on the height of siblings,
    -- which requires a second reflow pass.
    local second_pass = {}
    for n, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        local wcalc = widget.calc
        if widget == rtk.Box.FLEXSPACE then
            if greedyw then
                local previous = offset
                offset = offset + expand_unit_size * (attrs.expand or 1)
                spacing = 0
                -- Ensure box size reflects flexspace in case this is the last child in the box.
                maxw = math.max(maxw, offset)
                self:_set_cell_box(attrs, lp + previous, tp, offset - previous, maxh)
            end
        elseif widget.visible == true then
            local wx, wy, ww, wh
            local ctp, crp, cbp, clp = self:_get_cell_padding(widget, attrs)
            -- We need a second pass if any of the widget's vertical geometry depends on
            -- sibling heights.
            local need_second_pass = (
                -- Height explicitly depends on siblings
                attrs.stretch == rtk.Box.STRETCH_TO_SIBLINGS or
                -- Vertical alignment within the cell is centered or bottom whose position
                -- depends on sibling cells because we aren't fully stretching (in which
                -- case alignment would just depend on the bounding box which we already
                -- know).
                (attrs._valign and attrs._valign ~= rtk.Widget.TOP and
                 not (attrs.fillh and greedyh) and
                 attrs.stretch ~= rtk.Box.STRETCH_FULL)
            )
            local offx = offset + lp + clp + spacing
            local offy = tp + ctp
            local expand = attrs._calculated_expand
            if expand and greedyw and expand > 0 then
                -- This is an expanded child which was not reflowed in pass 1, so do it now.
                local child_maxw = rtk.clamprel(
                    (expand_unit_size * expand) - clp - crp - spacing,
                    attrs._minw,
                    attrs._maxh
                )
                local child_maxh = rtk.clamprel(
                    h - ctp - cbp,
                    attrs._minh,
                    attrs._maxh
                )
                wx, wy, ww, wh = widget:reflow(
                    0,
                    0,
                    child_maxw,
                    child_maxh,
                    attrs.fillw,
                    attrs.fillh,
                    clampw,
                    clamph,
                    uiscale,
                    viewport,
                    window,
                    greedyw,
                    greedyh
                )
                if attrs.stretch == rtk.Box.STRETCH_FULL and greedyh then
                    -- Just sets cell height. If stretch is siblings then we'll do a second pass.
                    wh = maxh
                end
                -- If height or vertical alignment is dependent on sibling height, queue
                -- for a second pass.
                if need_second_pass then
                    second_pass[#second_pass+1] = {
                        widget, attrs, offx, offy, child_maxw, wh, ctp, crp, cbp, clp, offset, spacing
                    }
                else
                    self:_align_child(widget, attrs, offx, offy, child_maxw, wh, crp, cbp)
                    self:_set_cell_box(attrs, lp + offset + spacing, tp, child_maxw + clp + crp, wh + ctp + cbp)
                end
                -- Indicate this expanded child as having consumed the full width offered (even if it
                -- didn't) so that below when we calculate the offset we ensure the next sibling is
                -- properly positioned.  And if it actually consumed more than offered, we'll have
                -- no choice but to overflow as well.
                ww = math.max(child_maxw, ww)
            else
                -- Non-expanded widget with native size, already reflowed in pass 1.  Just need
                -- to adjust position.
                ww = math.max(wcalc.w, attrs._minw or 0)
                wh = attrs.stretch == rtk.Box.STRETCH_FULL and greedyh and maxh or wcalc.h
                if need_second_pass then
                    second_pass[#second_pass+1] = {
                        widget, attrs, offx, offy, ww, wh, ctp, crp, cbp, clp, offset, spacing
                    }
                else
                    self:_align_child(widget, attrs, offx, offy, ww, wh, crp, cbp)
                    self:_set_cell_box(attrs, lp + offset + spacing, tp, ww + clp + crp, wh + ctp + cbp)
                end
            end
            if wcalc.position & rtk.Widget.POSITION_INFLOW ~= 0 then
                offset = offset + spacing + clp + ww + crp
            end
            maxw = math.max(maxw, offset)
            maxh = math.max(maxh, wh + ctp + cbp)
            spacing = (attrs.spacing or self.spacing) * rtk.scale.value
            if not need_second_pass then
                widget:_realize_geometry()
            end
        end
    end
    if #second_pass > 0 then
        for n, widgetinfo in ipairs(second_pass) do
            local widget, attrs, offx, offy, child_maxw, wh, ctp, crp, cbp, clp, offset, spacing = table.unpack(widgetinfo)
            if attrs.stretch == rtk.Box.STRETCH_TO_SIBLINGS then
                -- Widget size depended on siblings, so we need to reflow.
                widget:reflow(
                    -- Just use origin as we'll realign based on given offsets later.
                    0, 0,
                    child_maxw, maxh,
                    attrs.fillw,
                    attrs.fillh,
                    clampw,
                    clamph,
                    uiscale,
                    viewport,
                    window,
                    greedyw,
                    greedyh
                )
            end
            self:_align_child(widget, attrs, offx, offy, child_maxw, maxh, crp, cbp)
            self:_set_cell_box(attrs, lp + offset + spacing, tp, child_maxw + clp + crp, maxh + ctp + cbp)
            widget:_realize_geometry()
        end
    end
    return maxw, maxh
end

function rtk.HBox:_align_child(widget, attrs, offx, offy, cellw, cellh, crp, cbp)
    local x, y = offx, offy
    local wcalc = widget.calc
    -- Horizontal alignment applies when the available cell width is greater than
    -- the widgets width.  And fillw=true implies cell width (which excludes
    -- cell padding) and widget width (which includes widget padding) are equal,
    -- so this wouldn't apply in that case either.
    if cellw > wcalc.w then
        if attrs._halign == rtk.Widget.RIGHT then
            x = (offx - crp) + cellw - wcalc.w - crp
        elseif attrs._halign == rtk.Widget.CENTER then
            x = offx + (cellw - wcalc.w) / 2
        end
    end
    if attrs._valign == rtk.Widget.CENTER then
        y = (offy - cbp) + (cellh - wcalc.h) / 2
    elseif attrs._valign == rtk.Widget.BOTTOM then
        y = offy + cellh - wcalc.h - cbp
    end
    wcalc.x = wcalc.x + x
    widget.box[1] = x
    wcalc.y = wcalc.y + y
    widget.box[2] = y
end