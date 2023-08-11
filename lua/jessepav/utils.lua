module(..., package.seeall)

local rex = require('rex_pcre2')

-- trim() {{{1
local trim_re = rex.new([[^\s*(.*?)\s*$]])

function trim(s)
    return rex.match(s, trim_re)
end

-- isdigit() {{{1
local isdigit_re = rex.new([[\d+]])

function isdigit(s)
    return rex.match(s, isdigit_re) ~= nil
end

-- indexof() {{{1
function indexof(array, value)
    for i = 1, #array do
        if array[i] == value then return i end
    end
    return nil
end

-- truthy() {{{1
-- Returns true or false, depending on whether 'val' is truthy according to Vim
-- Also returns false if val is nil or false (in Lua)
function truthy(val)
    vtype = vim.type(val)
    if val == nil or val == false or
       vtype == "number" and val == 0 or
       indexof({"string", "blob", "list", "dict"}, vtype) and #val == 0 then
        return false
    else
        return true
    end
end

-- extend() {{{1
-- Add all the elements from 'extension' to 'array', return array
-- If filterfunc is given, it will be called for each element in extension, and
-- if it returns false, the element will not be added.
function extend(array, extension, filterfunc)
    if type(extension) == "table" then
        for _, el in ipairs(extension) do
            if not filterfunc or filterfunc(el) then
                table.insert(array, el)
            end
        end
    end
    return array
end

-- toarray() {{{1
-- Converts a vim list to a Lua array, if applicable
function toarray(list)
    if vim.type(list) == "list" then
        local array = {}
        for item in list() do
            table.insert(array, item)
        end
        return array
    else  -- otherwise just return what we were given
        return list
    end
end
