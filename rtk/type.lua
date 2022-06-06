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
local class = require('rtk.middleclass')

--- Defines an attribute of a widget class.
--
-- This class is only needed when creating custom widgets by subclassing `rtk.Widget`.
--
-- @example
--   local MyWidget = rtk.class('MyWidget', rtk.Widget)
--   MyWidget.register{
--       myattr = rtk.Attribute{
--           default=42,
--           -- Convert stringified numbers to actual numbers when attr() is called
--           calculate=function(self, attr, value, target)
--               return tonumber(value)
--           end,
--           -- Changing myattr affects geometry so require a full reflow when setting.
--           reflow=rtk.Widget.REFLOW_FULL,
--       }
--   }
--
-- When a subclass registers an rtk.Attribute instance for an attribute that a parent
-- class already registered, then the subclass's fields will overwrite those from the
-- parent, but otherwise will be merged, so there is no need to reimplement fields
-- from the parent class if no changes are needed.
--
-- @class rtk.Attribute
-- @see rtk.class

--- Attribute Constants.
--
-- @section attrconst
-- @compact fields
-- @fullnames

rtk.Attribute = {
    -- Internal value used for defaults when the default passed to rtk.Attribute
    -- is a function.
    FUNCTION = {},

    --- Proxy for nil keys or values, since Lua-native nils can't otherwise be used
    -- as table keys.  See `calculate`.
    NIL = {},


    --- Special value that can be passed to `rtk.Widget:attr()` in order to restore the
    -- class default value for an attribute.
    DEFAULT = {},

    --- Class API
    -- @section api

    --- The default value for the attribute when the class is instantiated.
    --
    -- This can also be a function, in which case it is invoked at object instantiation
    -- time, not at import time, and so can be used as a means of providing lazy or
    -- dynamic defaults.  A common use case for this is attributes that default to
    -- some value in the current theme: as the current theme isn't known at import time,
    -- this needs to be lazy-evaluated.
    --
    --  If it's a function, it will receive 2 arguments:
    --   1. the instance of the object whose default is being fetched
    --   2. the attribute name
    -- @type any|function
    default = nil,
    --- Optional type used to coerce values to the given type without the need for an
    -- explicit `calculate` function.  One of `number`, `string`, or `boolean`.  If
    -- nil (default), then no automatic coersion is done.
    --
    -- @type string|nil
    type = nil,
    --- Allows attribute values to be arbitrarily translated as part of the generation
    -- of the attribute's calculated value.
    --
    -- If this is table, then it's a simple LUT mapping input -> output.
    --
    -- If a function, then the function will receive 5 arguments:
    --   1. the instance of the object whose attribute is being set
    --   2. the attribute name
    --   3. the attribute value
    --   4. the target table for any injected dynamically calculated attributes (e.g. for shorthand attributes
    --      such as `rtk.Widget.padding`, which implicitly generates `tpadding`, `rpadding`,
    --      etc.)
    --   5. if true, the attribute is being calculated for purposes of an animation and so
    --      must return an animatable, non-nil value
    --
    -- The function must return the calculated version of the value.
    --
    -- @warning Beware side effects
    --   This function will be invoked in each step of an animation against this attribute,
    --   so be careful about side effects in this function, especially costly ones.  Define
    --   a `set` function instead, unless you really want the side effect(s) to occur within
    --   each animation frame.
    --
    -- @type table|function|nil
    calculate = nil,
    --- If true, ensures that the attribute is calculated after all non-priority
    -- attributes. This is used for attributes that either override or depend upon other
    -- attributes. For example, shorthand attributes like `rtk.Widget.padding` which
    -- overrides @{rtk.Widget.tpadding|tpadding}, @{rtk.Widget.rpadding|rpadding}, etc. or
    -- attributes like `rtk.Button.icon` which have a dependency on `rtk.Button.color` for
    -- luma-adaptive icon styling.
    -- @type boolean|nil
    priority = nil,
    --- Defines the @{rtk.Widget.reflow|reflow behavior} when this attribute is set. When
    -- nil, `rtk.Widget.REFLOW_PARTIAL` is used.
    -- @type reflowconst|nil
    reflow = nil,
    --- When `reflow` is set to `rtk.Widget.REFLOW_NONE` reflow is skipped and a straight redraw
    -- is queued instead.  If you also want to skip the redraw, set redraw=false.  If nil or true
    -- then a redraw is queued when the attribute is modified.
    -- @type boolean|nil
    redraw = nil,
    --- A table of one or more attribute names that will be set to nil when this attribute
    -- is set.  Useful when setting the attribute intends to replace other attributes.
    -- For example, setting `rtk.Widget.padding` will clear any previous values for
    -- @{rtk.Widget.tpadding|tpadding}, @{rtk.Widget.rpadding|rpadding}, etc.
    -- @type table|nil
    replaces = nil,
    --- If defined, provides a step function for animating the attribute.  The step function
    -- receives two arguments: the widget instance being animated, and a table describing
    -- the animation.  Relevant keys in the animation table are src (originating value),
    -- dst (target value the animation moves towards), and pct (the percentage from 0.0 to 1.0
    -- within the animation).  The same table will be passed to the step function each time,
    -- so it can also be used to hold custom state between invocations.
    --
    -- The animation function must return two values: the new calculated value of that
    -- attribute, and the corresponding new exterior value (or "decalculated" value).  For
    -- example, animating width or height may need to be adjusted by the scale factor in
    -- the calculated value, but the exterior value is before scaling.  The exterior value
    -- must not be nil -- return `rtk.Attribute.NIL` if needed.
    --
    -- If an attribute does not define an animate function, then calculate() will be called
    -- instead (if it exists), and the returned value will be used both as the calculated
    -- value during the animation, as well as the exterior value.
    -- @type function|nil
    animate = nil,
    --- An optional custom function to fetch the current calculated value for the attribute.
    --
    -- Normally those interested in calculated attributes will consult the
    -- `rtk.Widget.calc` table but attributes can define custom getters.  One use case for
    -- this is calculated shorthand metrics.  For example, suppose a widget has
    -- `padding=20` and `lpadding=50`.  The `calc.padding` value would be `{20, 20, 20, 20}`
    -- because that's the table representation of the `padding` attribute, but for *practical*
    -- purposes, callers would want a table version of underlying `tpadding`, `rpadding`, etc.
    -- attributes, or `{20, 20, 20, 50}` in the previous example.  One case of such a
    -- caller is `rtk.Widget:animate()` which needs to know the proper starting value to
    -- animate shorthand attributes.
    --
    -- This function receives 3 arguments:
    --   1. the instance of the object whose attributes are being fetched
    --   2. the attribute name
    --   3. the target table holding calculated attributes (`rtk.Widget.calc` typically)
    --
    -- The function then returns the current calculated value of the attribute.
    -- @type function|nil
    get = nil,

    --- An optional custom function to set the current calculated value for the attribute.
    --
    -- By default (when not defined), the return value of `calculate()` is assigned to the
    -- attribute's field in the widget's @{rtk.Widget.calc|calc} table, however if this function
    -- is defined, it's invoked instead.
    --
    -- This function receives 3 arguments:
    --   1. the instance of the object whose attributes are being fetched
    --   2. the attribute name
    --   3. the user-defined pre-calculated value for the attribute
    --   4. the calculated version of the value (as returned by `calculate()`.
    --   5. the target table holding calculated attributes (`rtk.Widget.calc` typically)
    --
    -- The function's return value has no significance.
    --
    -- @type function|nil
    set = nil,
}

-- Pseudo class, but not using middleclass since we don't need the overhead.
setmetatable(rtk.Attribute, {
    __call = function(self, attrs)
        attrs._is_rtk_attr = true
        return attrs
    end
})

-- For value coersion based on type field.
local falsemap = {
    [false]=true,
    [0]=true,
    ['0']=true,
    ['false']=true,
    ['False']=true,
    ['FALSE']=true
}

local typemaps = {
    number=function(v)
        local n = tonumber(v)
        if n then
            return n
        elseif v == 'true' or v == true then
            return 1
        elseif v == 'false' or v == false then
            return 0
        end
    end,
    string=tostring,
    boolean=function(v)
        if falsemap[v] then
            return false
        elseif v then
            return true
        end
    end,
}

--- References the `rtk.Attribute` field from another attribute in the class or its
-- superclasses.
--
-- References are resolved after all attributes are registered, so an attribute can
-- reference a field from another attribute that hasn't been defined yet.
--
-- It's also possible to clone an entire attribute, not just one of its fields.
--
-- @example
--    MyWidget.register{
--        iconpos=rtk.Attribute{
--            default=rtk.Widget.RIGHT,
--            -- Clone the calculate field from superclass's halign attribute
--            calculate=rtk.Reference('halign'),
--        },
--        -- Clone the superclass's bg attribute's metadata completely
--        color=rtk.Reference('bg'),
--    }
--
function rtk.Reference(attr)
    return {
        _is_rtk_reference = true,
        attr = attr
    }
end

local function register(cls, attrs)
    local attributes = cls.static.attributes
    if attributes and attributes.__class == cls.name then
        -- Attributes were already registered on this class, so we can continue
        -- to use the attributes value as-is.
    elseif cls.super then
        -- Initial registration of new subclass
        attributes = {}
        for k, v in pairs(cls.super.static.attributes) do
            if k ~= '__class' and k ~= 'get' then
                attributes[k] = table.shallow_copy(v)
            end
        end
    else
        -- Registration of base class.
        attributes = {defaults={}}
    end
    local refs = {}
    for attr, attrtable in pairs(attrs) do
        assert(
            attr ~= 'id' and attr ~= 'get' and attr ~= 'defaults',
            "attempted to assign a reserved attribute"
        )
        if type(attrtable) == 'table' and attrtable._is_rtk_reference then
            -- This is a top-level rtk.Reference at the attribute level, so we clone
            -- everything from the referenced attribute.
            local srcattr = attrtable.attr
            attrtable = {}
            refs[#refs+1] = {attrtable, nil, srcattr, attr}
        else
            if type(attrtable) ~= 'table' or not attrtable._is_rtk_attr then
                attrtable = {default=attrtable}
            end
            if attributes[attr] then
                attrtable = table.merge(attributes[attr], attrtable)
            end
            for field, v in pairs(attrtable) do
                if type(v) == 'table' and v._is_rtk_reference then
                    -- Attribute field is an rtk.Reference, so we queue it up to be resolved later.
                    refs[#refs+1] = {attrtable, field, v.attr, attr}
                end
            end
            local deftype = type(attrtable.default)
            if deftype == 'function' then
                attrtable.default_func = attrtable.default
                attrtable.default = rtk.Attribute.FUNCTION
            end
            -- Convert type string to coerce function.  If default is specified and
            -- there's no calculate function then we infer the type from the default
            -- value, which covers most cases.
            if (not attrtable.type and not attrtable.calculate) or type(attrtable.type) == 'string' then
                attrtable.type = typemaps[attrtable.type or deftype]
            end
        end
        attributes[attr] = attrtable
        attributes.defaults[attr] = attrtable.default
    end
    -- Now resolve any references.
    for _, ref in ipairs(refs) do
        local attrtable, field, srcattr, dstattr = table.unpack(ref)
        local src = attributes[srcattr]
        -- If the new attribute is lacking default, copy from referenced source (which may be nil)
        -- provided this is a top-level rather than a field-level reference.
        if not attributes.defaults[dstattr] and not field then
            attributes.defaults[dstattr] = attributes.defaults[srcattr]
        end
        if field then
            -- Single field rtk.Reference
            attrtable[field] = src[field]
        else
            -- Entire attribute rtk.Reference, copy everything
            for k, v in pairs(src) do
                attrtable[k] = v
            end
        end
    end
    attributes.__class = cls.name
    -- Note that rtk.Widget:_setattrs() bypasses this function for performance reasons.
    attributes.get = function(attr)
        return attributes[attr] or rtk.Attribute.NIL
    end
    cls.static.attributes = attributes
end


--- Creates a new class.
--
-- This function [wraps middleclass](https://github.com/kikito/middleclass/wiki/Reference)
-- and includes a static class method `register()` on the returned class for registering
-- attributes.  The `register()` function takes a table that describes the class's attributes,
-- where each field in the table is an instance of `rtk.Attribute`.
--
-- All classes in rtk use this function, and therefore provide all the same capabilities
-- as [middleclass](https://github.com/kikito/middleclass) itself.  Middleclass is bundled
-- with rtk, but also includes some minor tweaks (e.g. to support finalizers for garbage
-- collection).
--
-- For simple attributes that don't need any special behavior or treatment, the value
-- can be the attribute's default value, rather than an `rtk.Attribute`.
-- @see rtk.Attribute
-- @within rtk
-- @order first
function rtk.class(name, super, attributes)
    local cls = class(name, super)
    cls.static.register = function(attrs)
        register(cls, attrs)
    end
    if attributes then
        register(cls, attributes)
    end
    return cls
end

--- Determine if a value is an instance or sublcass of a particular class.
--
-- @tparam any v the value to test
-- @tparam rtk.class cls a class object as returned by `rtk.class()`
-- @treturn boolean true if the value is an instance of cls (or a subclass thereof)
-- @within rtk
-- @order after rtk.class
function rtk.isa(v, cls)
    if type(v) == 'table' and v.isInstanceOf then
        return v:isInstanceOf(cls)
    end
    return false
end