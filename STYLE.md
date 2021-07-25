# Coding Style

The following style rules apply to all rtk source code.

Most of these conventions are borrowed from the [LuaRocks style guide](https://github.com/luarocks/lua-style-guide).  Refer to that guide for more details.

Below we review the salient points, and highlight areas that disagree with and supercede LuaRocks' style guide.


## Naming

What | Style | Guidance
-|-|-
Variables | `lowercase_snake_case` | Err toward more short and concise than long and overly descriptive for smaller scopes.  Underscores can be skipped for short dual word names when the words combined are still visually clear, e.g. `tonumber()` or `startswith()`.  In contrast, something like `tooctal()` is odd looking and requires some cognitive load to parse. There is obviously some subjectivity here, and context matters.
Functions and Methods | `lowercase_snake_case` | Same guidance as variables. Prefix internal-only table fields (including methods) with underscores to denote these are not part of the public interface (and therefore may have an unstable signature or semantics).
Modules | `lowercase` | Module names are lower case without any underscores.  Likewise, assign imported modules to local lowercase variables and avoid underscores.
Classes | `PascalCase` | Classes use the metaclass module
Constants | `UPPERCASE_SNAKE_CASE` | Lua 5.3 doesn't have native constants, but this convention signals the intention to be treated as constant


## Formatting

1. Indentation is **4 spaces**. No tabs.

1. Prefer single quotes for strings, except when the string contains a single quote, in which case use double quotes.  If the string contains both types of quotes, use whichever approach results in the least amount of escaping.

1. Use spaces between operators and after commas, but not before or after parens in function calls, or
   with keyword arguments (see next item):

    ```lua
    y = (x + z) / 1.5
    if baz and foo + bar > 42 then
        do_something(foo, bar, baz)
    end
    ```
   Allowed exception: drop spaces for longer math expressions when doing so improves readability and/or inference of order of operations:

    ```lua
    -- Technically correct by convention
    c = math.sqrt(a * a + b * b)
    -- But this is easier to read and more clearly expresses the intention
    -- without needing to introduce parentheses.
    c = math.sqrt(a*a + b*b)
    ```

1. When passing a table to a function as a form of keyword arguments (as is idiomatic in Lua), don't put
   spaces around equals signs.  (This is similar to Python PEP 8's guidance.)  Also, when a table is used
   in this way (to simulate keyword arguments), drop the parens from the function call, using only braces:

   ```lua
   local c = rtk.VBox{
       spacing=10,
       focusable=true,
       z=100,
       tpadding=25,
       bpadding=25,
   }
   local b = rtk.Button{label='Big Red button', color='#ff0000'}
   b:animate{'color', dst='red', duration=2}
   img:blit{dx=10, dy=100, alpha=0.65}
   ```
   However, when passing a table as an argument to a function in other contexts, include the braces, and
   uses spacing within the table definition as normal:

   ```lua
   -- Passing a color using the table formatted variant, not a keyword argument context.
   rtk.color.set({1, 0.5, 0.25})
   -- A menu layout table, again not keywords.
   nativemenu:set({
       {'Open', id='open'},
       {'Close', id='close'},
   })
   ```


1. Do not align variable assignments with whitespaces in order to reduce diff noise in commits when the longest name changes:

    ```lua
    -- Don't do this
    local some_long_variable = 1
    local shorter_variable   = 2
    local foo                = 3

    -- Do this
    local some_long_variable = 1
    local shorter_variable = 2
    local foo = 3
    ```

1. Do not collapse functions, if statements, loops, etc. onto one line, or consolidate multple statements on one line with semicolons.  Split them over multiple lines.  And unlike other style guides, there's no exception for conditionals with simple statements like break, continue, or return.

    ```lua
    -- Don't do this
    if foo and bar then x = x + 1 end
    if baz then break end
    a = 1; b = 2

    -- Do this
    if foo and bar then
        x = x + 1
    end
    if baz then
        break
    end
    a = 1
    b = 2
    ```

   Allowed exception: anonymous single-statement functions:

    ```lua
    local callback = function() return 42 end
    defer(function() app:do_something(42) end)
    ```

1. Add 1 blank lines between function definitions. Use single blank lines inside functions judiciously to establish logical groups of code.

1. Include a trailing comma after the last element of a table when writing it over multiple lines:

   ```lua
   local items = {
       'one',
       'two',
       'three',
   }
   ```
1. Avoid multi-variable assignments with many variables or long variable names. This is a bit of a judgment call but it's better to err on the side of expanding to multiple lines if there's a chance the multi-variable assignment can't be easily visually chunked.  (Putting assignments each on their own line is a bit faster, but not so much that it should outweigh code readability.)

    ```lua
    -- Don't do this
    self.foo, self.bar, self.baz, self.qux = foo, bar, baz, qux

    -- Do this instead
    self.foo = foo
    self.bar = bar
    self.baz = baz
    self.qux = qux

    -- But this is certainly fine, and preferable to using a tmp variable
    a, b = b, a
    ```