local sharecode = {}

-- Fixed reference point so timestamps encode as a small delta instead of the full unix value.
local EPOCH = 1700000000

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local function b64encode(data)
    local out = {}
    local len = #data
    local i = 1
    while i <= len do
        local b1, b2, b3 = string.byte(data, i, i + 2)
        b2 = b2 or 0
        b3 = b3 or 0
        local n = b1 * 65536 + b2 * 256 + b3
        local rem = len - i + 1
        out[#out + 1] = string.sub(B64_CHARS, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = string.sub(B64_CHARS, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        if rem >= 2 then
            out[#out + 1] = string.sub(B64_CHARS, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
        end
        if rem >= 3 then
            out[#out + 1] = string.sub(B64_CHARS, n % 64 + 1, n % 64 + 1)
        end
        i = i + 3
    end
    return table.concat(out)
end

local function b64decode(str)
    local out = {}
    local len = #str
    local i = 1
    while i <= len do
        local s1, s2, s3, s4 = string.sub(str, i, i), string.sub(str, i + 1, i + 1), string.sub(str, i + 2, i + 2), string.sub(str, i + 3, i + 3)
        local c1 = string.find(B64_CHARS, s1, 1, true) - 1
        local c2 = (s2 ~= "" and string.find(B64_CHARS, s2, 1, true) or 1) - 1
        local c3 = s3 ~= "" and (string.find(B64_CHARS, s3, 1, true) - 1) or nil
        local c4 = s4 ~= "" and (string.find(B64_CHARS, s4, 1, true) - 1) or nil
        local n = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c3 then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if c4 then
            out[#out + 1] = string.char(n % 256)
        end
        i = i + 4
    end
    return table.concat(out)
end

-- Packs an unsigned integer into `nbytes` big-endian raw bytes (arithmetic only, no bit ops needed).
local function intToBytes(value, nbytes)
    value = math.floor(value or 0)
    local bytes = {}
    for i = nbytes, 1, -1 do
        bytes[i] = value % 256
        value = math.floor(value / 256)
    end
    local chars = {}
    for i = 1, nbytes do
        chars[i] = string.char(bytes[i])
    end
    return table.concat(chars)
end

local function bytesToInt(str)
    local value = 0
    for i = 1, #str do
        value = value * 256 + string.byte(str, i)
    end
    return value
end

-- sextant = { longitude="E"/"W", deg_long, min_long, sec_long, latitude="N"/"S", deg_lat, min_lat, sec_lat }
-- Packs buildingId + sextant into one 48-bit value (well under Lua's 2^53 exact-integer limit).
local function packGroupA(buildingId, sextant)
    local v = buildingId or 0                                        -- 7 bits (0-127)
    v = v * 2 + ((sextant.longitude == "W") and 1 or 0)               -- 1 bit
    v = v * 256 + (sextant.deg_long or 0)                             -- 8 bits (0-255)
    v = v * 64 + (sextant.min_long or 0)                              -- 6 bits (0-59)
    v = v * 64 + (sextant.sec_long or 0)                              -- 6 bits (0-59)
    v = v * 2 + ((sextant.latitude == "S") and 1 or 0)                -- 1 bit
    v = v * 128 + (sextant.deg_lat or 0)                              -- 7 bits (0-89)
    v = v * 64 + (sextant.min_lat or 0)                               -- 6 bits (0-59)
    v = v * 64 + (sextant.sec_lat or 0)                               -- 6 bits (0-59)
    return v
end

local function unpackGroupA(v)
    local secLat = v % 64; v = math.floor(v / 64)
    local minLat = v % 64; v = math.floor(v / 64)
    local degLat = v % 128; v = math.floor(v / 128)
    local latDir = (v % 2 == 1) and "S" or "N"; v = math.floor(v / 2)
    local secLong = v % 64; v = math.floor(v / 64)
    local minLong = v % 64; v = math.floor(v / 64)
    local degLong = v % 256; v = math.floor(v / 256)
    local lonDir = (v % 2 == 1) and "W" or "E"; v = math.floor(v / 2)
    local buildingId = v % 128

    return buildingId, {
        longitude = lonDir,
        deg_long = degLong,
        min_long = minLong,
        sec_long = secLong,
        latitude = latDir,
        deg_lat = degLat,
        min_lat = minLat,
        sec_lat = secLat,
    }
end

-- Encodes buildingId + sextant + unixtime as an opaque binary blob, with owner appended as plain text.
-- Not human-readable, but ~25 chars shorter than a delimited text format for typical inputs.
function sharecode.Encode(buildingId, sextant, owner, unixtime)
    local a = packGroupA(buildingId or 0, sextant or {})
    local blob = intToBytes(a, 6) .. intToBytes((unixtime or EPOCH) - EPOCH, 4)
    return b64encode(blob) .. "|" .. tostring(owner or "")
end

-- Reverses sharecode.Encode. Returns buildingId, sextant (table), owner, unixtime.
function sharecode.Decode(code)
    local blobPart, owner = string.match(code, "^(.-)|(.*)$")
    if blobPart == nil then
        return nil
    end
    local blob = b64decode(blobPart)
    local buildingId, sextant = unpackGroupA(bytesToInt(string.sub(blob, 1, 6)))
    local unixtime = bytesToInt(string.sub(blob, 7, 10)) + EPOCH
    return buildingId, sextant, owner, unixtime
end

return sharecode
