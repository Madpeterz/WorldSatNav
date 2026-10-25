-- Minimal test runner: registers tests, runs each in isolation under pcall, reports.
local lite = {}

local tests = {}
local currentFile = "?"

function lite.setFile(name)
    currentFile = name
end

-- Registers a test. `setup` runs first (use it to reset the environment).
function lite.test(name, fn)
    table.insert(tests, { file = currentFile, name = name, fn = fn })
end

local function describe(value)
    if type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

local function fail(message, level)
    error(message, (level or 1) + 1)
end

function lite.eq(actual, expected, message)
    if actual ~= expected then
        fail((message and (message .. ": ") or "") .. "expected " .. describe(expected) .. ", got " .. describe(actual), 2)
    end
end

function lite.near(actual, expected, tolerance, message)
    if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 1e-9) then
        fail((message and (message .. ": ") or "") .. "expected ~" .. describe(expected) .. ", got " .. describe(actual), 2)
    end
end

function lite.truthy(value, message)
    if not value then
        fail((message or "expected a truthy value") .. ", got " .. describe(value), 2)
    end
end

function lite.falsy(value, message)
    if value then
        fail((message or "expected a falsy value") .. ", got " .. describe(value), 2)
    end
end

function lite.isnil(value, message)
    if value ~= nil then
        fail((message and (message .. ": ") or "") .. "expected nil, got " .. describe(value), 2)
    end
end

-- Expects fn to raise an error whose text contains `pattern` (plain match).
function lite.raises(fn, pattern)
    local ok, err = pcall(fn)
    if ok then
        fail("expected an error, none was raised", 2)
    end
    if pattern ~= nil and not tostring(err):find(pattern, 1, true) then
        fail("error " .. describe(tostring(err)) .. " does not contain " .. describe(pattern), 2)
    end
end

function lite.deepEq(actual, expected, message, path)
    path = path or "value"
    if type(actual) ~= type(expected) then
        fail((message or path) .. ": type " .. type(actual) .. " ~= " .. type(expected), 2)
    end
    if type(expected) ~= "table" then
        if actual ~= expected then
            fail((message or path) .. ": expected " .. describe(expected) .. ", got " .. describe(actual), 2)
        end
        return
    end
    for key, value in pairs(expected) do
        lite.deepEq(actual[key], value, message, path .. "." .. tostring(key))
    end
    for key in pairs(actual) do
        if expected[key] == nil then
            fail((message or path) .. ": unexpected key " .. tostring(key), 2)
        end
    end
end

-- Runs everything; returns the number of failures.
function lite.run(filter)
    local passed, failed = 0, 0
    local failures = {}
    for _, test in ipairs(tests) do
        local label = test.file .. " > " .. test.name
        if filter == nil or label:lower():find(filter:lower(), 1, true) then
            local ok, err = xpcall(test.fn, function(message)
                return message
            end)
            if ok then
                passed = passed + 1
                io.write(".")
            else
                failed = failed + 1
                io.write("F")
                table.insert(failures, { label = label, err = tostring(err) })
            end
        end
    end
    io.write("\n\n")
    for _, failure in ipairs(failures) do
        print("FAIL " .. failure.label)
        print("     " .. failure.err)
    end
    print(string.format("%d passed, %d failed", passed, failed))
    return failed
end

return lite
