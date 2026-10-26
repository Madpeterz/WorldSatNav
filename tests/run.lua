-- Run from anywhere:  luajit tests/run.lua [name filter]
-- Each tests/*_test.lua file returns function(t, env) and registers tests with t.test.
local scriptPath = arg and arg[0] or "tests/run.lua"
local testsDir = scriptPath:match("^(.*)[\\/][^\\/]*$") or "."
local root = testsDir .. "/.."

package.path = testsDir .. "/?.lua;" .. package.path

local env = require("support.env")
local lite = require("support.lite")
env.setRoot(root)
env.install()

local files = {
    "datetime_clock",
    "datetime_convert",
    "datetime_format",
    "sharecode",
    "coordinates",
    "geo",
    "misc",
    "settings",
    "eventbus",
    "buildings",
    "locationoutput",
}

for _, name in ipairs(files) do
    lite.setFile(name)
    local register = require(name .. "_test")
    register(lite, env)
end

local failures = lite.run(arg and arg[1])
os.exit(failures == 0 and 0 or 1)
