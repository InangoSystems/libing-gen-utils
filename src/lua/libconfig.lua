--[[
################################################################################
#
# libconfig.lua
#
# Copyright (c) 2013-2021 Inango Systems LTD.
#
# Author: Inango Systems LTD. <support@inango-systems.com>
# Creation Date: 25 Jun 2013
#
# The author may be reached at support@inango-systems.com
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Subject to the terms and conditions of this license, each copyright holder
# and contributor hereby grants to those receiving rights under this license
# a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable
# (except for failure to satisfy the conditions of this license) patent license
# to make, have made, use, offer to sell, sell, import, and otherwise transfer
# this software, where such license applies only to those patent claims, already
# acquired or hereafter acquired, licensable by such copyright holder or contributor
# that are necessarily infringed by:
#
# (a) their Contribution(s) (the licensed copyrights of copyright holders and
# non-copyrightable additions of contributors, in source or binary form) alone;
# or
#
# (b) combination of their Contribution(s) with the work of authorship to which
# such Contribution(s) was added by such copyright holder or contributor, if,
# at the time the Contribution is added, such addition causes such combination
# to be necessarily infringed. The patent license shall not apply to any other
# combinations which include the Contribution.
#
# Except as expressly stated above, no rights or licenses from any copyright
# holder or contributor is granted under this license, whether expressly, by
# implication, estoppel or otherwise.
#
# DISCLAIMER
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# NOTE
#
# This is part of a management middleware software package called MMX that was developed by Inango Systems Ltd.
#
# This version of MMX provides web and command-line management interfaces.
#
# Please contact us at Inango at support@inango-systems.com if you would like to hear more about
# - other management packages, such as SNMP, TR-069 or Netconf
# - how we can extend the data model to support all parts of your system
# - professional sub-contract and customization services
#
################################################################################
--]]
--[[
  Description:

    File contains Lua functions to handle requests in libconfig format used by
    various Inango MMX components.

    This module returns libconfig table with the following defined functions:

    libconfig = {
        decode(string) -> table   - decodes libconfig format string into a Lua table
        encode(table)  -> string  - encodes Lua table into a libconfig format string
        empty_array()  -> table   - returns Lua table, accepted by encoder as an empty array
        empty_list ()  -> table   - returns Lua table, accepted by encoder as an empty list
        empty_group()  -> table   - returns Lua table, accepted by encoder as an empty group
    }


    libconfig - is a simple lib for structured configuration file

    libconfig basically is a list of settings in the form of name-value pairs -
    so-called group. Values can be a scalar type or an array or a list or a
    group again. Array, list and group are named commonly also as an aggregate
    types.

    This requirements allow us generally to encode data in the form of Lua table
    into the libconfig format data format with the following considerations:

      - table containing name only keys (Lua map) is considered to be a
        libconfig group

      - table containing numeric only keys (Lua array) with scalar type values
        of the same type is considered to be a libconfig array

      - table containing numeric only keys (Lua array) with mixed type or
        aggregate values is considered to be a libconfig list

      - allowed scalar types are Lua boolean, string and number

      - pure empty tables as values are allowed but related names are skipped
        while encoding because their type is not deducible

    All other table constructs are not compliant to the livconfig format and
    will cause the encoding error.

    The decoding of libcofig format string into Lua data structures is
    straightforward because arrays, lists and groups can be represented as Lua
    tables with no restrictions as far as libconfig data source format is
    correct.

    libconfig BNF grammar:

      configuration     = setting-list | empty
      setting-list      = setting | setting-list setting
      setting           = name (":" | "=") value (";" | "," | empty)
      value             = scalar-value | array | list | group
      value-list        = value | value-list "," value
      scalar-value      = boolean | integer | integer64 | hex | hex64 | float | string
      scalar-value-list = scalar-value | scalar-value-list "," scalar-value
      array             = "[" (scalar-value-list | empty) "]"
      list              = "(" (value-list | empty) ")"
      group             = "{" (setting-list | empty) "}"
      empty             =

    Scalar values are defined below as regular expressions:

      boolean      ([Tt][Rr][Uu][Ee])|([Ff][Aa][Ll][Ss][Ee])
      string       \"([^\"\\]|\\.)*\"
      name         [A-Za-z\*][-A-Za-z0-9_\*]*
      integer      [-+]?[0-9]+
      integer64    [-+]?[0-9]+L(L)?
      hex          0[Xx][0-9A-Fa-f]+
      hex64        0[Xx][0-9A-Fa-f]+L(L)?
      float        ([-+]?([0-9]*)?\.[0-9]*([eE][-+]?[0-9]+)?)|([-+]([0-9]+)(\.[0-9]*)?[eE][-+]?[0-9]+)


  Implementation notes:

    Encoding function is a pure Lua standalone implementation.
    Decoding function requires lualibconfig C module for Lua.
--]]

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------
local config = {
    clue       = "@",
    type_class = {
        UNKNOWN   = 1,
        SCALAR    = 2,
        ARRAY     = 3,
        LIST      = 4,
        GROUP     = 5,
        AGGREGATE = 6
    }
}

config.lua_type_classes = {
    ["nil"     ] = config.type_class.UNKNOWN,
    ["function"] = config.type_class.UNKNOWN,
    ["thread"  ] = config.type_class.UNKNOWN,
    ["userdata"] = config.type_class.UNKNOWN,
    ["number"  ] = config.type_class.SCALAR,
    ["string"  ] = config.type_class.SCALAR,
    ["boolean" ] = config.type_class.SCALAR,
    ["table"   ] = config.type_class.AGGREGATE
}
--------------------------------------------------------------------------------
function config.empty_array()
    return {[config.clue] = config.type_class.ARRAY}
end
--------------------------------------------------------------------------------
function config.empty_list()
    return {[config.clue] = config.type_class.LIST }
end
--------------------------------------------------------------------------------
function config.empty_group()
    return {[config.clue] = config.type_class.GROUP}
end
--------------------------------------------------------------------------------
function config.type_class_of(value)
    local value_tc = config.lua_type_classes[type(value)]

    if value_tc  == config.type_class.UNKNOWN then
        return config.type_class.UNKNOWN, (" - inappropiate value type '%s'"):format(type(value))
    end

    if value_tc == config.type_class.SCALAR then
        return config.type_class.SCALAR;
    end

    local has_aggr_values   = false;
    local has_string_keys   = false;
    local has_numeric_keys  = false;
    local has_same_types    = true;
    local is_empty          = true;
    local scalar_type

    for k, v in pairs(value) do
        if k == config.clue then
            return v
        end

        is_empty = false

        if     type(k) == "number" then
            has_numeric_keys = true
        elseif type(k) == "string" then
            has_string_keys  = true
        else
            return config.type_class.UNKNOWN, (" - contains invalid key type '%s'"):format(type(k))
        end

        if has_numeric_keys == has_string_keys then
            return config.type_class.UNKNOWN, " - contains mixed string and number key types"
        end

        local v_tc = config.lua_type_classes[type(v)]
        if v_tc == config.type_class.UNKNOWN then
            local context
            if type(k) == "number" then
                context = "[" .. k .. "]"
            else
                context = "." .. k
            end
            return config.type_class.UNKNOWN, ("%s - inappropriate value type '%s'"):format(context, type(v))
        end

        has_aggr_values  = has_aggr_values  or v_tc == config.type_class.AGGREGATE

        if has_same_types and v_tc == config.type_class.SCALAR then
            if not scalar_type then
                scalar_type = type(v)
            else
                if scalar_type ~= type(v) then
                    has_same_types = false
                end
            end
        end
    end

    if is_empty then
        return config.type_class.AGGREGATE
    end

    if has_string_keys then
        return config.type_class.GROUP
    end

    if has_aggr_values or not has_same_types then
        return config.type_class.LIST
    end

    return config.type_class.ARRAY
end
--------------------------------------------------------------------------------
-- forward declarations
--------------------------------------------------------------------------------

local libconfig_setting_encoders  -- table[config.type_class.*] = encode_*

--------------------------------------------------------------------------------
-- implementations
--------------------------------------------------------------------------------
local function libconfig_encode_scalar(value)
    if type(value) == "string" then
        return ("%q"):format(value)  -- %q handles escape sequences `\"`, `\\`, `\r` except `\f`, `\n`, `\t`
    end
    
    if type(value) == "number" and (value > 2147483647 or value < -2147483648) then
        return tostring(value) .. "L"
    end

    return tostring(value)
end
--------------------------------------------------------------------------------
local function libconfig_encode_setting(value, name)
    local value_tc, e = config.type_class_of(value)
    if value_tc == config.type_class.UNKNOWN then
        return nil, e
    end
    return libconfig_setting_encoders[value_tc](value, name)
end
--------------------------------------------------------------------------------
local function libconfig_encode_group(t)
    local output = {}
    for name, value in pairs(t) do
        if name ~= config.clue then
            local s, e = libconfig_encode_setting(value, name)
            if not s then
                return nil, ("." .. name .. e)
            end
            if s ~= "" then
                output[#output + 1] = s
            end
        end
    end
    return (0 == #output) and "" or table.concat(output, ", ")
end
--------------------------------------------------------------------------------
local function libconfig_encode_list(t)
    local output = {}
    for i, value in ipairs(t) do
        local s, e = libconfig_encode_setting(value)
        if not s then
            return nil, ("[" .. i .. "]" .. e)
        end
        if s ~= "" then
            output[#output + 1] = s
        end
    end
    return (0 == #output) and "" or table.concat(output, ", ")
end
--------------------------------------------------------------------------------
local function libconfig_encode_array(t)
    local output = {}
    for _, value in ipairs(t) do
        output[#output + 1] = libconfig_encode_scalar(value)
    end
    return (0 == #output) and "" or table.concat(output, ", ")
end
--------------------------------------------------------------------------------
local function libconfig_encode(t)
    if type(t) ~= "table" then
        return nil, "Argument is not a table"
    end

    if next(t) == nil then
       return ""
    end

    if config.type_class.GROUP ~= config.type_class_of(t) then
        return nil, "Argument is not formed as a group table"
    end

    return libconfig_encode_group(t)
end
--------------------------------------------------------------------------------
local function build_setting(fn, value, name, prefix, suffix)
    local value_str, e
    if fn then
        value_str, e = fn(value)
    else
        value_str = value
    end

    if not value_str then
        return nil, e
    end

    local output = name and {name, ": "} or {}
    if prefix then
        output[#output + 1] = prefix
    end
    output[#output + 1] = value_str
    if suffix then
        output[#output + 1] = suffix
    end

    return table.concat(output)
end
--------------------------------------------------------------------------------
-- libconfig_setting_encoders table defifnition
--------------------------------------------------------------------------------
libconfig_setting_encoders = {
    [config.type_class.SCALAR] = function (value, name)
        return build_setting(libconfig_encode_scalar, value, name)
    end,

    [config.type_class.GROUP] = function (value, name)
        return build_setting(libconfig_encode_group , value, name, '{', '}')
    end,

    [config.type_class.LIST] = function (value, name)
        return build_setting(libconfig_encode_list  , value, name, '(', ')')
    end,

    [config.type_class.ARRAY] = function (value, name)
        return build_setting(libconfig_encode_array , value, name, '[', ']')
    end,

    [config.type_class.AGGREGATE] = function ()
        return ""  -- case with the pure empty table as a value => encode nothing
    end,

    [config.type_class.UNKNOWN] = function ()
        return nil, " - unknown libconfig data type class"
    end
}
--------------------------------------------------------------------------------

--[[
-- Require lib
--]]
local lualibconfig = require("mmx.lualibconfig")

--[[
-- libconfig
--]]
local libconfig = {
    decode      = lualibconfig.decode,  -- decodes libconfig string into a Lua table
    encode      = libconfig_encode,     -- encodes Lua table into a libconfig string
    empty_array = config.empty_array,   -- returns Lua table, viewed by encoder as an empty array
    empty_list  = config.empty_list,    -- returns Lua table, viewed by encoder as an empty list
    empty_group = config.empty_group    -- returns Lua table, viewed by encoder as an empty group
}

libconfig.sType = {
    ["group"] = "Groups",
    ["array"] = "Arrays",
    ["list"] = "Lists",
    ["int"] = "Integer",
    ["bool"] = "Boolean",
    ["string"] = "String",
}

--[[
--  To prepare a new structure for libconfig
--]]
function libconfig:new()
    local obj= {}
    setmetatable(obj, self)
    self.__index = self; return obj
end

--[[
--  Add libconfig settings in structure with value
--]]
function libconfig:addSetting( sType, sName, sValue )
    self.type = (self.type or "Base")
    if self.type == "Base" or self.type == "Groups" then
        self.value = (self.value or {})
        self.value[sName] = {}
        self.value[sName].type = sType
        self.value[sName].name = sName
        if sType == "Groups" then
            self.value[sName].value = {}
        elseif sType == "Arrays" then
            self.value[sName].value = {}
        elseif sType == "Lists" then
            self.value[sName].value = {}
        elseif sType == "Integer" then
            self.value[sName].value = sValue
        elseif sType == "Boolean" then
            self.value[sName].value = sValue
        elseif sType == "String" then
            self.value[sName].value = sValue
        end
        setmetatable(self.value[sName], {__index=libconfig, __tostring = libconfig.__tostring})
        return self.value[sName]
    end
end

--[[
-- create a new settings
--]]
function libconfig:newSetting( sType, sName, sValue )
    local value = {}
    value[sName] = {}
    value[sName].name = sName
    value[sName].type = sType
    if sType == "Groups" then
        value[sName].value = {}
    elseif sType == "Arrays" then
        value[sName].value = {}
    elseif sType == "Lists" then
        value[sName].value = {}
    elseif sType == "Integer" then
        value[sName].value = sValue
    elseif sType == "Boolean" then
        value[sName].value = sValue
    elseif sType == "String" then
        value[sName].value = sValue
    end
    setmetatable(value[sName], {__index=libconfig, __tostring = libconfig.__tostring})
    return value[sName]
end

--[[
--  Add libconfig value in structure with value
--]]
function libconfig:addValue( sType, sValue )
    self.value = (self.value or {})
    local gr = {}
    if self.type == "Arrays" or self.type == "Lists" then
        gr.type = sType
        if sType == "Groups" then
            gr.value = {}
        elseif sType == "Arrays" then
            gr.value = {}
        elseif sType == "Lists" then
            gr.value = {}
        elseif sType == "Integer" then
            gr.value = sValue
        elseif sType == "Boolean" then
            gr.value = sValue
        elseif sType == "String" then
            gr.value = sValue
        end
        table.insert(self.value, gr)
    end
    setmetatable(gr, {__index=libconfig, __tostring = libconfig.__tostring})
    return gr
end

--[[
--   converted the lua structure libconfig to a string libconfig
--]]
function libconfig:__tostring()
    local res = ""
    local value = self.value
    local name = self.name
    local lType = self.type
    local notfirst = true
    if name then
        res = res .. name .. " : "
    end
    if lType == "Base" then
        for k, v in pairs(value) do
            res = res .. tostring(v)
        end
    elseif lType == "Groups" then
        res = res .. " { "
        for k, v in pairs(value) do
            res = res .. tostring(v) .. " ; "
        end
        res = res .. " } "
    elseif lType == "Arrays" then
        res = res .. " [ "
        for k, v in pairs(value) do
            if k == #value then
                res = res .. tostring(v)
            else
                res = res .. tostring(v) .. " , "
            end
        end
        res = res .. " ] "
    elseif lType == "Lists" then
        res = res .. " ( "
        for k, v in pairs(value) do
            if k == #value then
                res = res .. tostring(v)
            else
                res = res .. tostring(v) .. " , "
            end
        end
        res = res .. " ) "
    elseif lType == "Integer" then
            res = res ..  tostring(value)
    elseif lType == "Boolean" then
            res = res ..  tostring(value)
    elseif lType == "String" then
            res = res ..  ("%q"):format(value)
    end
    return res
end

return libconfig
