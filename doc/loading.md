# Loading rtk

First, a word about how rtk approaches versioning ...
## API versions


Releases are versioned according to [semantic
versioning](https://en.wikipedia.org/wiki/Software_versioning), and applies the following
philosophy:

 1. The API of major versions are backward-compatible with minor or patch releases within the same major version
    * For example, if you develop a script against rtk v1.1.5, if the user has v1.5.9 installed, your script will continue to work
    * Because of this, the major rtk version is called the **API version**
 1. Although breaking the API is generally avoided, it's sometimes necessary for proper design
    * Whenever a breaking change is introduced within rtk, the API version is incremented
 1. When rtk releases a new API version, development on previous API versions is stopped, notwithstanding critical bug fixes
    * So, as a developer, while rtk's ongoing development will not break your existing scripts, you're encouraged to keep your scripts updated to track the latest API version of rtk so that you benefit from the latest features and non-critical fixes
 1. The website documentation always refers to the latest API version, which is indicated in the top navigation bar
 1. When installed via ReaPack, within `Scripts/rtk/`, there is a subdirectory for all API versions ever released
    * This ensures that old, abandoned scripts will continue to work as users keep their ReaPacks up to date

## ReaPack

When rtk is @{index.1_reapack|installed via ReaPack}, it will live within REAPER's
resource folder under `Scripts/rtk`.  Because it's installed at this well-known location, when your script targets the ReaPack install, it can be loaded like this:

```lua
-- Set package path to find rtk installed via ReaPack
package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require('rtk')
```

Notice the `1/` component of `package.path` in the above example. This indicates the API
version that the script is targeting.


Here's a slightly more complex example, which includes not just the path to rtk, but also
the directory that holds the entrypoint script (i.e. the one that invoked the action), so
you're able to load other scripts that exist alongside the entrypoint script:


```lua
local entrypath = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = string.format('%s/Scripts/rtk/1/?.lua;%s?.lua;', reaper.GetResourcePath(), entrypath)
```

While the above examples are straightforward, they aren't not very robust and will error
out ungracefully if the rtk ReaPack isn't installed.  Here's a more practical if more
complex snippet:

```lua
package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local ok, rtk = pcall(function() return require('rtk') end)
if not ok then
    reaper.MB(
        'This script requires the REAPER Toolkit ReaPack. Visit https://reapertoolkit.dev for instructions.',
        'Missing Library',
        0
    )
    return
end
```

#### Automatic Installation via ReaPack API

As long as the user has the ReaPack extension installed, we can get fairly clever by using
the ReaPack extension API to automatically install rtk if the user so chooses.

This is a significantly more complex bit of logic, but it provides a nicer user experience,
and it's copy-pastable directly into your script.

```lua
-- Setup package path locations to find rtk via ReaPack
local entrypath = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = string.format('%s/Scripts/rtk/1/?.lua;%s?.lua;', reaper.GetResourcePath(), entrypath)

-- Loads rtk in the global scope, and, if missing, attempts to install using
-- ReaPack APIs.
local function init(attempts)
    local ok
    ok, rtk = pcall(function() return require('rtk') end)
    if ok then
        -- Import worked. We can invoke the main function.
        return main()
    end
    local installmsg = 'Visit https://reapertoolkit.dev for installation instructions.'
    if not attempts then
        -- This is our first failed attempt, so prompt the user if they want us to install
        -- rtk via ReaPack automatically.
        if not reaper.ReaPack_AddSetRepository then
            -- The ReaPack extension isn't installed, so inform the user they need to do a
            -- manual install.
            return reaper.MB(
                'This script requires the REAPER Toolkit ReaPack. ' .. installmsg,
                'Missing Library',
                0 -- Ok
            )
        end
        -- Ask the user if they want us to install rtk
        local response = reaper.MB(
            'This script requires the REAPER Toolkit ReaPack. Would you like to automatically install it?',
            'Automatically install REAPER Toolkit ReaPack?',
            4 -- Yes/No
        )
        if response ~= 6 then
            -- User said no, we're done.
            return reaper.MB(installmsg, 'Automatic Installation Refused', 0)
        end
        -- User said yes, so add the ReaPack repository.
        local ok, err = reaper.ReaPack_AddSetRepository('rtk', 'https://reapertoolkit.dev/index.xml', true, 1)
        if not ok then
            return reaper.MB(
                string.format('Automatic install failed: %s.\n\n%s', err, installmsg),
                'ReaPack installation failed',
                0 -- Ok
            )
        end
        reaper.ReaPack_ProcessQueue(true)
    elseif attempts > 150 then
        -- After about 5 seconds we still couldn't find rtk, so give up.
        return reaper.MB(
            'Installation took too long. Assuming a ReaPack error occurred and giving up. ' .. installmsg,
            'ReaPack installation failed',
            0 -- Ok
        )
    end
    -- If we've made it this far we keep trying to load rtk
    reaper.defer(function() init((attempts or 0) + 1) end)
end

-- Invoked by init() when rtk has successfully been loaded.  Your script's main content
-- goes here.
function main()
    local window = rtk.Window()
    window:add(rtk.Text{'Hello world!'})
    window:open()
end

init()
```


## Library Bundle

In lieu of using the global ReaPack install, you can distribute rtk along with your own
projects.  You might choose to do this because:

  1. You want to be 100% sure that the version of rtk you've tested is what your users are using
  2. You want to avoid asking your users to install a third party dependency
  3. You've made local customizations to rtk that aren't available upstream
  4. You want to use alpha or beta APIs that are subject to change and want to avoid ReaPack
     updates breaking your scripts.

rtk uses a custom tool called *LuaKnit* to assemble all of the project files into a single
packed [`rtk.lua`](https://reapertoolkit.dev/rtk.lua) source file that makes it convenient
for script authors to import and distribute.

Suppose your script is called `myapp.lua` and you have
[`rtk.lua`](https://reapertoolkit.dev/rtk.lua) in the same directory alongside it:

```lua
-- Setup package path locations to find rtk via ReaPack
local entrypath = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = string.format('%s?.lua;', entrypath)
local rtk = require('rtk')
```

And that's all there is to it.

### Combining rtk and scripts

You can use LuaKnit yourself to combine your own source files, and even include
`rtk.lua` so you're able to distribute a single executable script.

In addition to consolidating into a single file, LuaKnit also does its best to minify
the code, stripping out comments and reducing the amount of redundant whitespace.  It's
not perfect -- it doesn't tokenize Lua source code, only uses naive regexps -- but it
does a decent enough job not to have motivated anything more sophisticated.

[Fetch `luaknit.py` from rtk's git
repository](https://raw.githubusercontent.com/jtackaberry/rtk/master/tools/luaknit.py).
LuaKnit is a Python script and requires Python 3.6 or later to be installed.

Suppose you have a directory containing `rtk.lua`, and your own project files `main.lua`
and `commands.lua`.  It's easy to bundle all these together:

```bash
# Linux and OS X
$ python3 /path/to/luaknit.py rtk.lua main.lua commands.lua -o myscript.lua

# Windows
C:\projects\myscript> python3 \path\to\luaknit.py rtk.lua main.lua commands.lua -o myscript.lua
```

That's really all there is to it.  The file `myscript.lua` can now be executed directly by
REAPER.

If your script `require()`s another module, if the module is located in the current
directory, it will be automatically processed.  If not, you can pass it (either a
file or directory) directly to LuaKnit and specify the module name.

For example, you could bundle your script directly with rtk's raw source directory which
contains all its original files.  Suppose you have cloned [rtk's git repo](https://github.com/jtackaberry/rtk)
at `/path/to/rtk`, then:

```bash
$ python3 /path/to/luaknit.py rtk=/path/to/rtk/src main.lua commands.lua -o myscript.lua
```