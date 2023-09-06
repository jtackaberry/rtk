-- Copyright 2022-2023 Jason Tackaberry
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

--- @warning Experimental functionality
--    This module is **not stable** and its API and behaviors are subject to change. Do
--    not use this API if you are targeting the ReaPack installation, as future versions
--    are likely to introduce backward incompatible changes.  If you
--    @{loading.library_bundle|bundle your own copy of rtk} with your script then this
--    risk is removed.
--
--    Feedback is appreciated during this API preview phase.
--
-- This module implements a fairly naive XML parser, supporting a limited but useful
-- subset of XML. Despite its limitations (see below for more details), in practice it
-- copes with many XML documents in the wild.
--
-- It tries to be robust in what it does implement, tolerating common minor malformations
-- (such as attributes missing quotes).  In this sense alone it is not a valid XML
-- processor, as the XML spec requires any document with syntactically invalid content to
-- be rejected.  Meanwhile, rtk's implementation favors pragmatism when reasonable.
--
-- ### Simple Example
--
-- In its simplest invocation, `rtk.xmlparse()` reads a string containing an XML document
-- and returns a hierarchy of nested Lua tables representing the parsed document:
--
-- @code
--    local document = [[
--        <?xml version="1.0" encoding="UTF-8"?>
--        <bookstore>
--            <book category="children">
--                <title lang="en">Harry Potter</title>
--                <author>J K. Rowling</author>
--                <year>2005</year>
--                <price>29.99</price>
--            </book>
--            <book category="web">
--                <title lang="en">Learning XML</title>
--                <author>Erik T. Ray</author>
--                <year>2003</year>
--                <price>39.95</price>
--            </book>
--      </bookstore>
--    ]]
--    local root = rtk.xmlparse(document)
--    rtk.log.info('root element is: %s', root.tag)
--    rtk.log.info('first element is: %s, category=%s', root[1].tag, root[1].attrs.category.value)
--
-- Each element is expressed as a Lua table.  See `rtk.xmlparse()` for details about how element
-- tables are structured.
--
-- This example crawls the parsed element hierarchy, printing a nested tree of elements
-- showing their tag names and content (if any):
--
-- @code
--    local function showelem(elem, depth)
--        -- Indent the output according to the element's nested depth
--        rtk.log.info('%s- %s (%s)', string.rep(' ', depth * 2), elem.tag, elem.content)
--        for _, child in ipairs(elem) do
--            showelem(child, depth + 1)
--        end
--    end
--    showelem(root, 0)
--
-- ### Advanced Example
--
-- It's also possible to provide custom callback functions that get invoked when a new tag
-- is started (`ontagstart`), when an element's attribute is parsed (`onattr`), and when a
-- tag is ended (`ontagend`). You can also optionally provide custom userdata of your
-- choosing that is passed along to these callbacks.
--
-- Your callbacks can attach custom fields to the element or attribute tables that will
-- be available after parsing is finished.  With the `onattr` callback, you can also
-- rewrite the attribute name and value by replacing those fields in the attribute table
-- that is passed to the callback.
--
-- When using this more advanced invocation of `rtk.xmlparse()`, you pass it a table.  The
-- example below reuses the XML document from the first example, and maintains a total
-- count of elements by tag across the document. It also also rewrites the `category`
-- attribute as `genre` and converts the values to upper case.
--
-- @code
--    -- We'll keep track of element counts per tag.
--    local state = {counts={}}
--    local root = rtk.xmlparse{
--        document,
--        userdata=state,
--        ontagstart=function(elem, state)
--            state.counts[elem.tag] = (state.counts[elem.tag] or 0) + 1
--        end,
--        onattr=function(elem, attr, state)
--            -- Rewrite the 'cateogry' attribute as 'genre' with an uppercase value
--            if attr.name == 'category' then
--                attr.name = 'genre'
--                attr.value = attr.value:upper()
--            end
--        end,
--    }
--    rtk.log.info('tag counts: %s', table.tostring(state.counts))
--    -- This time we access the category attribute by its rewritten name 'genre',
--    -- whose value has been converted to uppercase.
--    rtk.log.info('first book genre: %s', root[1].attrs.genre.value)
--
-- The above example is a little bit contrived, because of course the callback functions
-- could easily be closures around `state` so we could just access it directly, but this
-- is useful when you want to reuse functions that are independent of some form of state.
--
-- ### Limitations
--
-- The parser has the following limitations:
--
--   * Document Type Definitions (DTD) are not supported and will be ignored.  Documents
--     containing DTDs that define custom entities that are used in the document will not
--     be parsed properly (the custom entities will remain unconverted).
--   * Because DTDs aren't supported, the parser is non-validating.
--   * The `encoding` field in the XML declaration (`<? xml encoding="UTF-8"?>`) is ignored.
--     *Only* UTF-8 is supported.
--   * It's not going to win any awards on speed.  It's about as fast as Python's minidom
--     parser, and about 2x faster than [xml2lua](https://github.com/manoelcampos/xml2lua)
--     (but it's also less featureful than either), and it gets decimated by C-native
--     parsers.  But it's perfectly serviceable for smaller XML docs (under a few thousand
--     lines).
--
-- @module xml

-- Lua patterns we iterate through to find attributes within tags.  Many of these are not
-- valid for XML but we parse them anyway for robustness.  Similarly, the mustache syntax
-- is a custom extension for rtk and definitely isn't valid XML.
local ATTR_PATTERNS = {
    -- Double quoted value
    {'quoted', '^%s*([^>/%s=]+)%s*(=)%s*"([^"]+)"%s*(%/?)(%>?)'},
    -- Single quoted value
    {'quoted', "^%s*([^>/%s=]+)%s*(=)%s*'([^']+)'%s*(%/?)(%>?)"},
    -- {{ expression }}.  We can only go as far as {{ because Lua doesn't support
    -- non-greedy matching.  So we'll need to take care of the self-close and
    -- terminator tokens separately.
    {'mustache', '^%s*([^>/%s=]+)%s*(=)%s*({{)'},
    -- Unquoted value
    {'unquoted', '^%s*([^>/%s=]+)%s*(=)%s*([^%s/>]+)%s*(%/)(%>)'},
    {'unquoted', '^%s*([^>/%s=]+)%s*(=)%s*([^%s>]+)(%s*)(%>?)'},
    -- No value
    {'novalue', '^%s*([^>/%s]+)%s*()()(%/?)(%>?)'},
}

local ENTITIES = {
    lt = '<',
    gt = '>',
    amp = '&',
    apos = "'",
    quot = '"',
    -- Not technically XML
    nbsp = " ",
}

local function _unescape_entity(entity)
    local r = ENTITIES[entity]
    if not r and entity:sub(1, 1) == '#' then
        -- Code point.
        if entity:sub(2, 2) == 'x' then
            -- Hex code point
            r = utf8.char(tonumber(entity:sub(3), 16))
        else
            -- Decimal code point
            r = utf8.char(tonumber(entity:sub(2)))
        end
    end
    return r
end

local function _unescape(s)
    return s and s:gsub('&([^;]+);', _unescape_entity)
end

-- Parses an open or close tag <...>.
--
-- Returns
--  1. newpos: index where parsing ended, where nil means stop processing
--  2. elem: an elem table, either the one passed in if a close tag, or a new elem table if start tag
--  3. closed: false if this is an open tag, 1 if close tag, 2 if self-closing tag.
local function _gettag(s, pos, elem, userdata, ontagstart, onattr)
    local a, b, preamble, close, tag, selfclose, term = s:find('^([^%<]*)%<%s*(%/?)%s*([^>/%s]+)%s*(%/?)%s*(%>?)', pos)
    if not a then
        -- No tag found after pos.
        return
    end
    -- Advance position to after the match
    pos = b + 1
    preamble = preamble:strip()
    if tag == '!--' then
        -- Comment. Find the terminator.
        local finish = s:find('%-%->', pos)
        if finish then
            return finish + 3, nil, false
        else
            -- Unterminated comment, so assume the rest of the document is commented.
            return
        end
    elseif tag == '!DOCTYPE' then
        -- We don't support DTDs yet.  Toss it.
        local finish = s:find(']>', pos)
        if finish then
            return finish + 2, nil, false
        else
            log.warning('rtk.xml: invalid XML: DOCTYPE is not terminated')
        end
    elseif tag:sub(1, 8) == '![CDATA[' then
        -- CDATA was being detected as a tag.  Grab the full CDATA contents and add it
        -- as the (unescaped) contents of the current element.
        local finish = s:find(']]>', pos)
        if finish then
            if elem then
                elem.content = tag:sub(9) .. s:sub(pos, finish - 1)
            else
                -- We have no where to add this content.
                log.warning('rtk.xml: invalid XML: CDATA occurs outside an element')
            end
            return finish + 3, nil, false
        else
            log.warning('rtk.xml: invalid XML: unterminated CDATA')
            if elem then
                -- Absent anything better to do, grab content to the end of the document
                -- before we give up.
                elem.content = tag:sub(9) .. s:sub(pos)
            end
            return
        end
    end
    if close == '/' then
        -- Full close tag.  Make sure end tag name matches current elem.
        if not elem then
            log.warning('rtk.xml: invalid XML: unexpected end tag "%s"', tag)
            return
        elseif elem.tag ~= tag then
            log.warning('rtk.xml: mismatched end tag "%s" -- expected "%s"', tag, elem.tag)
            return
        end
        if preamble ~= "" then
            elem.content = (elem.content or '') .. _unescape(preamble)
        end
        return pos, elem, close == '/' and 1
    elseif preamble ~= "" and elem then
        elem.preamble = preamble
    end

    -- If here, we have a new tag.
    elem = {tag=tag}
    if ontagstart and tag ~= '?xml' then
        ontagstart(elem, userdata)
    end
    if term == '>' then
        -- Open tag with no attributes.
        return pos, elem, false
    end

    -- Parse all attributes in this element.
    local attrs = {}
    elem.attrs = attrs
    local attr, eq, value, whitespace
    while true do
        local pattern_type = nil
        for p = 1, #ATTR_PATTERNS do
            local typ, pattern = table.unpack(ATTR_PATTERNS[p])
            a, b, attr, eq, value, selfclose, term = s:find(pattern, pos)
            if a then
                pattern_type = typ
                break
            end
        end
        -- We either couldn't find an attribute, or what we did find will fail to properly
        -- advance the parsing in which case we defensively abort as this could be
        -- infinite loop territory.
        if not pattern_type or b + 1 <= pos then
            break
        end
        if pattern_type == 'mustache' then
            -- This is a direct mustache expression.  Find termination point and parse out
            -- the value.  This obviously isn't XML, but it's an rtk extension that we use
            -- for RML.  Because this is an extension, we use error() rather than logging
            -- a warning, as it implies code issues.
            local finish = s:find('}}', b+1)
            if not finish then
                error(string.format('rtk.xml: terminating }} for expression not found for "%s"', attr), 3)
            end
            value = s:sub(b+1, finish-1)
            -- Advance position and find self-close and terminator tokens if applicable.
            b = finish + 2
            a, b, whitespace, selfclose, term = s:find('^(%s*)(%/?)(%>?)', b)
            if #selfclose == 0 and #term == 0 and #whitespace > 0 then
                error('rtk.xml: mustache expression has trailing characters -- perhaps quotes are needed?', 3)
            end
        elseif pattern_type == 'novalue' then
            value = nil
        else
            value = _unescape(value)
        end
        local attrtable = {name=attr, value=value, type=pattern_type}
        if onattr and tag ~= '?xml' then
            onattr(elem, attrtable, userdata)
        end
        assert(attrtable.name, 'attribute is missing name')
        attrs[attrtable.name] = attrtable
        pos = b + 1
        if term == '>' then
            break
        end
    end
    return pos, elem, selfclose == '/' and 2
end

--- Parses an XML document, returning the root element.
--
-- The `args` parameter is either a string that contains the XML document to parse, or
-- it's a table that acts as keyword arguments that allow defining more options to control
-- parsing.  When `args` is a table, it takes the following fields.
--
-- | Field | Type | Required | Description |
-- |-|-|-|-|
-- | `xml` or first positional field | *string* | yes | the XML document string to parse |
-- | `userdata` or second positional field | *any* | no | arbitrary user-defined data that is passed to callback functions |
-- | `ontagstart` | *function* | no | an optional callback function that will be invoked when a new tag is started, before attribute parsing has begin.  The callback takes the arguments `(element, userdata)`, where `element` is the element table defined below, and `userdata` is the same-named field passed in the `args` table, which will be nil if not defined. |
-- | `onattr` | *function* | no | an optional callback function that will be invoked when an attribute has been parsed within the currently open tag.  The callback takes the arguments `(element, attr, userdata)`, where `attr` is the attribute table defined below. |
-- | `ontagend` | *function* | no | an optional callback function that will be invoked when a tag is closed.  The callback takes the arguments `(element, userdata)`. |
--
-- #### Element Tables
--
-- Elements are represented as Lua tables, with named fields for metadata about the
-- element, and positional fields holding the element's children.  Each element table
-- has:
--
-- | Field | Type | Description |
-- |-|-|-|
-- | `tag` | *string* | The tag name of the element |
-- | `attrs` | *table* or *nil* | A table of attributes for the element keyed on attribute name, or *nil* if the element has no attributes |
-- | `content` | *string* or *nil* | The character data content within the element stripped of leading and trailing whitespace, or *nil* if there is no non-whitespace content |
-- | Positional fields | element *table* | Zero or more positional fields in the table representing any child elements |
--
--
-- #### Attribute Tables
--
-- The `attrs` field within an element table, if present, is a table keyed on attribute name and has the following fields:
--
-- | Field | Type | Description |
-- |-|-|-|
-- | `value` | *string* | the value of the attribute as defined in the XML document, or filtered by a user-defined `onattr` handler (see below) |
-- | `name` | *string* | the name of the attribute as defined in the XML document, or filtered by a user-defined `onattr` handler (see below). This is the same as the key in the element's `attrs` table. |
-- | `type` | *string* | contains context of how the attribute was parsed, which is one of `quoted` when the attribute was properly quoted in the document (e.g. `lang="en"`), `unquoted` when the attribute lacks quotes (e.g. `lang=en`, which is technically invalid XML), or `novalue` when the attribute has no value at all (where you can decide what, if anything, to use as a default value). |
--
-- @usage
--   local root = rtk.xmlparse([[
--       <addressbook>
--         <contact>
--           <name>Alice</name>
--           <email>alice@example.com</email>
--         </contact>
--         <contact>
--           <name>Bob</name>
--           <email>bob@example.com</email>
--         </contact>
--       </addressbook>
--   ]])
--
-- @tparam string|table args the XML document string or table containing the XML document
--     string and other parser options (see above)
-- @treturn table|nil the element table of the root node, or nil if the document could not be parsed
function rtk.xmlparse(args)
    local xml, userdata, ontagstart, ontagend, onattr
    if type(args) == 'string' then
        xml = args
    elseif type(args) == 'table' then
        xml = args.xml or args[1]
        userdata = args.userdata or args[2]
        ontagstart = args.ontagstart
        ontagend = args.ontagend
        onattr = args.onattr
    else
        error('rtk.xmlparse() must receive either a string or table')
    end
    assert(type(xml) == 'string', 'the XML document must be a string')
    local stack = {}
    local root = nil
    local pos = 1
    while true do
        local last = stack[#stack]
        -- Returned elem can be nil in the case of comments.
        local newpos, elem, closed = _gettag(xml, pos, last, userdata, ontagstart, onattr)
        -- If newpos is nil then we've finished parsing, but we also check defensively if
        -- newpos failed to advance (or if somehow it went backward) relative to the current
        -- position, which could cause us to loop infinitely.
        if not newpos or newpos <= pos then
            break
        end
        pos = newpos
        if closed and ontagend then
            ontagend(elem, userdata)
        end
        if closed == 1 then
            table.remove(stack, #stack)
        elseif elem and elem.tag ~= '?xml' then
            if #stack > 0 then
                local current = stack[#stack]
                current[#current+1] = elem
            end
            if not closed then
                stack[#stack+1] = elem
            end
        end
        if not root then
            root = stack[#stack]
        end
    end
    return root
end
