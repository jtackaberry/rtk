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

--- A box container where children are arranged vertically in rows.
--
-- @note API documentation
--   See the base class `rtk.Box` for documentation on the VBox interface.
--
-- @class rtk.VBox
-- @inherits rtk.Box
-- @see rtk.HBox
rtk.VBox = rtk.class('rtk.VBox', rtk.Box)


rtk.VBox.register{
    orientation = rtk.Box.VERTICAL
}

function rtk.VBox:initialize(attrs, ...)
    rtk.Box.initialize(self, attrs, self.class.attributes.defaults, ...)
end

-- Second pass over all children
-- TODO: wayyyy too much duplication here with rtk.HBox._reflow_step2().
function rtk.VBox:_reflow_step2(w, h, maxw, maxh, clampw, clamph, expand_units, remaining_size, total_spacing, uiscale, viewport, window, greedyw, greedyh, tp, rp, bp, lp)
    local expand_unit_size = expand_units > 0 and ((remaining_size - total_spacing) / expand_units) or 0
    local offset = 0
    local spacing = 0
    -- List of widgets and attrs whose height (or valign) depends on the height of siblings,
    -- which requires a second reflow pass.
    local second_pass = {}
    for n, widgetattrs in ipairs(self.children) do
        local widget, attrs = table.unpack(widgetattrs)
        local wcalc = widget.calc
        if widget == rtk.Box.FLEXSPACE then
            if greedyh then
                local previous = offset
                offset = offset + expand_unit_size * (attrs.expand or 1)
                spacing = 0
                -- Ensure box size reflects flexspace in case this is the last child in the box.
                maxh = math.max(maxh, offset)
                self:_set_cell_box(attrs, lp, tp + previous, maxw, offset - previous)
            end
        elseif widget.visible == true then
            local wx, wy, ww, wh
            local ctp, crp, cbp, clp = self:_get_cell_padding(widget, attrs)
            -- We need a second pass if any of the widget's horizontal geometry depends on
            -- sibling widths.
            local need_second_pass = (
                -- Width explicitly depends on siblings
                attrs.stretch == rtk.Box.STRETCH_TO_SIBLINGS or
                -- Horizontal alignment within the cell is centered or right-aligned whose
                -- position depends on sibling cells because we aren't fully stretching
                -- (in which case alignment would just depend on the bounding box which we
                -- already know).
                (attrs._halign and attrs._halign ~= rtk.Widget.LEFT and
                 not (attrs.fillw and greedyw) and
                 attrs.stretch ~= rtk.Box.STRETCH_FULL)
            )
            local offx = lp + clp
            local offy = offset + tp + ctp + spacing
            local expand = attrs._calculated_expand
            local cellh
            if expand and greedyh and expand > 0 then
                local expanded_size = (expand_unit_size * expand)
                expand_units = expand_units - expand
                if attrs._minh and attrs._minh > expanded_size then
                    -- Min height is greater than what expand units would have allowed.
                    -- Respect minh, but degrade gracefully by recalculating the expand
                    -- unit size so that the remaining widgets will fit within the
                    -- remaining size.
                    local remaining_spacing = total_spacing - attrs._running_spacing_total
                    expand_unit_size = (remaining_size - attrs._minh - ctp - cbp - remaining_spacing) / expand_units
                end
                -- This is an expanded child which was not reflowed in pass 1, so do it now.
                local child_maxw = rtk.clamp(w - clp - crp, attrs._minw, attrs._maxw)
                local child_maxh = rtk.clamp(expanded_size - ctp - cbp - spacing, attrs._minh, attrs._maxh)
                -- Ensure height offered to child can't extend past what remains of our overall box.
                child_maxh = math.min(child_maxh, h - maxh - spacing)
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
                if attrs.stretch == rtk.Box.STRETCH_FULL and greedyw then
                    -- Just sets cell width. If stretch is siblings then we'll do a second pass.
                    ww = maxw
                end
                -- Indicate this expanded child as having consumed the full height offered (even if it
                -- didn't) so that below when we calculate the offset we ensure the next sibling is
                -- properly positioned.  And if it actually consumed more than offered, we'll have
                -- no choice but to overflow as well.
                wh = math.max(child_maxh, wh)
                cellh = ctp + wh + cbp
                remaining_size = remaining_size - spacing - cellh
                -- If width or horizontal alignment is dependent on sibling width, queue
                -- for a second pass.
                if need_second_pass then
                    second_pass[#second_pass+1] = {
                        widget, attrs, offx, offy, ww, child_maxh, ctp, crp, cbp, clp, offset, spacing
                    }
                else
                    self:_align_child(widget, attrs, offx, offy, ww, child_maxh, crp, cbp)
                    self:_set_cell_box(attrs, lp, tp + offset + spacing, ww + clp + crp, cellh)
                end
            else
                -- Non-expanded widget with native size, already reflowed in pass 1.  Just need
                -- to adjust position.
                ww = attrs.stretch == rtk.Box.STRETCH_FULL and greedyw and (maxw-clp-crp) or wcalc.w
                wh = math.max(wcalc.h, attrs._minh or 0)
                cellh = ctp + wh + cbp
                if need_second_pass then
                    second_pass[#second_pass+1] = {
                        widget, attrs, offx, offy, ww, wh, ctp, crp, cbp, clp, offset, spacing
                    }
                else
                    self:_align_child(widget, attrs, offx, offy, ww, wh, crp, cbp)
                    self:_set_cell_box(attrs, lp, tp + offset + spacing, ww + clp + crp, cellh)
                end
            end
            if wcalc.position & rtk.Widget.POSITION_INFLOW ~= 0 then
                offset = offset + spacing + cellh
            end
            maxw = math.max(maxw, ww + clp + crp)
            maxh = math.max(maxh, offset)
            spacing = (attrs.spacing or self.spacing) * uiscale
            if not need_second_pass then
                widget:_realize_geometry()
            end
        end
    end
    if #second_pass > 0 then
        for n, widgetinfo in ipairs(second_pass) do
            local widget, attrs, offx, offy, ww, child_maxh, ctp, crp, cbp, clp, offset, spacing = table.unpack(widgetinfo)
            if attrs.stretch == rtk.Box.STRETCH_TO_SIBLINGS then
                -- Widget size depended on siblings, so we need to reflow.
                widget:reflow(
                    -- Just use origin as we'll realign based on given offsets later.
                    0, 0,
                    maxw, child_maxh,
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
            self:_align_child(widget, attrs, offx, offy, maxw, child_maxh, crp, cbp)
            self:_set_cell_box(attrs, lp, tp + offset + spacing, maxw + clp + crp, child_maxh + ctp + cbp)
            widget:_realize_geometry()
        end
    end
    return maxw, maxh
end

function rtk.VBox:_align_child(widget, attrs, offx, offy, cellw, cellh, crp, cbp)
    local x, y = offx, offy
    local wcalc = widget.calc
    -- Horizontal alignment applies when the available cell width is greater than
    -- the widgets width.  And fillw=true implies cell width (which excludes
    -- cell padding) and widget width (which includes widget padding) are equal,
    -- so this wouldn't apply in that case either.
    if cellh > wcalc.h then
        if attrs._valign == rtk.Widget.BOTTOM then
            y = (offy - cbp) + cellh - wcalc.h - cbp
        elseif attrs._valign == rtk.Widget.CENTER then
            y = offy + (cellh - wcalc.h) / 2
        end
    end
    if attrs._halign == rtk.Widget.CENTER then
        x = (offx - crp) + (cellw - wcalc.w) / 2
    elseif attrs._halign == rtk.Widget.RIGHT then
        x = offx + cellw - wcalc.w - crp
    end
    wcalc.x = wcalc.x + x
    widget.box[1] = x
    wcalc.y = wcalc.y + y
    widget.box[2] = y
end