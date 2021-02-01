--[[
################################################################################
#
# libconfig-test.lua
#
# Copyright (c) 2013-2021 Inango Systems LTD.
#
# Author: Inango Systems LTD. <support@inango-systems.com>
# Creation Date: 20 Sep 2017
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
--  Description: Tests for libconfig.lua module
--]]

local config = require("mmx/libconfig")

--------------------------------------------------------------------------------
-- String buffer writer
--------------------------------------------------------------------------------
local str_writer_mt = {}

function str_writer_mt:__call(...)
    --local arg = {n = select('#', ...), ...}
    --for i = 1, arg.n do
    --end
    self.s = self.s .. table.concat({...})
end

local function str_writer()
    local inst = {s = ""}
    setmetatable(inst, str_writer_mt)
    return inst
end
--------------------------------------------------------------------------------
-- Sorted pairs iterator
--------------------------------------------------------------------------------
local spairs_mt = {}

function spairs_mt:__call(t)
    self.i = self.i + 1
    local name = self.keys[self.i]
    if name == nil then
        return nil
    end

    return name, t[name]
end

local function spairs_comp(lhs, rhs)
    if type(lhs) ~= type(rhs) then
        return tostring(lhs) < tostring(rhs)
    end

    return lhs < rhs
end

local function spairs(t)
    local inst = {i = 0, keys = {}}
    setmetatable(inst, spairs_mt)
    local keys = inst.keys
    for key in pairs(t) do
        table.insert(keys, key)
    end
    table.sort(keys, spairs_comp)

    return inst, t, nil
end
--------------------------------------------------------------------------------
-- Prints table to console or using print_fn function if provided
--------------------------------------------------------------------------------
local function print_table(t, indent, indent_str, print_fn)
    indent     = indent     or 0
    indent_str = indent_str or "  "

    local spacing = string.rep(indent_str, indent)
    local output  = {}

    print_fn = print_fn or print

    local first = true
    for k, v in spairs(t) do
        if not first then
            output[#output + 1] = ", "
            print_fn(table.concat(output))
        else
            first = false
        end

        output = {spacing}

        if type(k) == "string" then
            output[#output + 1] = k
        else
            output[#output + 1] = "["
            output[#output + 1] = tostring(k)
            output[#output + 1] = "]"
        end

        if type(v) == "table" then
            output[#output + 1] = " = {"
            print_fn(table.concat(output))

            print_table(v, indent + 1, indent_str, print_fn)

            output = {spacing, "}"}
        else
            output[#output + 1] = " = "
            if type(v) == "string" then
                output[#output + 1] = string.format("%q", v)
            else
                if k == "@" and type(v) == "number" then
                    if v == 3 then
                        output[#output + 1] = "ARRAY"
                    elseif v == 4 then
                        output[#output + 1] = "LIST"
                    elseif v == 5 then
                        output[#output + 1] = "GROUP"
                    else
                        output[#output + 1] = tostring(v)
                    end
                else
                    output[#output + 1] = tostring(v)
                end

            end
        end
    end

    if 0 < #output then
        print_fn(table.concat(output))
    end
end
--------------------------------------------------------------------------------
-- Test helpers
--------------------------------------------------------------------------------
local function test_encode_decode(t)
    local t_str = str_writer()
    print_table(t, 0, "", t_str)
    print("\n- test t == decode(encode(t)) for table: {" .. t_str.s .. "}")

    local success = true

    local t_cfg
    if success then
        local e
        t_cfg, e = config.encode(t)
        if not t_cfg then
            success = false
            print("  e: " .. e)
        end
    end

    if success then
        local t_new, e = config.decode(t_cfg)
        if not t_new then
            success = false
            print("  e: " .. e)
        else
            local t_new_str = str_writer()
            print_table(t, 0, "", t_new_str)
            if t_new_str.s ~= t_str.s then
                success = false
                print("  original table differs from decoded after encoded one")
            end
        end
    end

    if success then
        print("= ok")
    else
        print("= fail")
    end
end
--------------------------------------------------------------------------------
local function test_encode(t, s)
    local t_str = str_writer()
    print_table(t, 0, "", t_str)
    print(("\n- test s == encode(t) for table t = {" .. t_str.s .. "} and string s = %q"):format(s))

    local success = true

    local t_cfg
    if success then
        local e
        t_cfg, e = config.encode(t)
        if not t_cfg then
            success = false
            print("  e: " .. e)
        end
    end

    if success then
        if t_cfg ~= s then
            success = false
            print(("  encoded string differs from desired: %q"):format(t_cfg))
        end
    end

    if success then
        print("= ok")
    else
        print("= fail")
    end
end
--------------------------------------------------------------------------------
local function test_encode_should_fail(t)
    local t_str = str_writer()
    print_table(t, 0, "", t_str)
    print("\n- test encode should fail for table: {" .. t_str.s .. "}")

    local t_cfg, e = config.encode(t)

    if not t_cfg then
        print("  failed to encode: " .. e)
        print("= ok")
    else
        print("  encoded: \n    '" .. t_cfg .. "'")
        print("= fail")
    end
end
--------------------------------------------------------------------------------
local function test_decode_should_fail(...)
    local arg = {n = select('#', ...), ...}
    local s = arg.n == 0 and "<none>" or ((type(arg[1]) == "string") and ("'" .. arg[1] .. "'") or tostring(arg[1]))
    print("\n- test decode should fail for argument: " .. s)

    local s_t, e = config.decode(...)
    if not s_t then
        print("  failed to decode: " .. e)
        print("= ok")
    else
        local s_t_str = str_writer()
        print_table(s_t, 0, "", s_t_str)
        print("  decoded: '" .. s_t_str.s .. "'")
        print("= fail")
    end
end
--------------------------------------------------------------------------------
-- Test cases
--------------------------------------------------------------------------------
print("\n- [begin]")

test_encode_decode({key = "hello world"})

test_encode_decode({key = "\"hello cruel world\"; [\\], [\r]"})

test_encode_should_fail({a = "a", b = {{b1a = "b1a", "b1b"}, "b2"}})

test_encode_should_fail({a = "a", b = {{b1a = "b1a", b1b = function () return nil end}, "b2"}})

test_encode_should_fail({a = "a", b = {{b1a = "b1a", [{}] = "b1b"}, "b2"}})

test_encode_decode({a = "a", b = config.empty_list(), c = config.empty_array(), d = true, e = false})

test_decode_should_fail()

test_decode_should_fail(100)

test_decode_should_fail('a = 20; 20 = "a"')

test_encode({a = {42, {}}, b = {}}, "a: (42)")

--------------------------------------------------------------------------------
-- Some poorely formalized tests
--------------------------------------------------------------------------------
local cfg_str =
[[
# Example application configuration file

version = "1.0";

application:
{
  window:
  {
    title = "My Application";
    size = { w = 640; h = 480; };
    pos = { x = 350; y = 250; };
  };

  list = ( ( "abc", 123, true ), 1.234, ( /* an empty list */) );

  books = ( { title  = "Treasure Island";
              author = "Robert Louis Stevenson";
              price  = 29.95;
              qty    = 5; },
            { title  = "Snow Crash";
              author = "Neal Stephenson";
              price  = 9.99;
              qty    = 8; } );

  misc:
  {
    pi = 3.141592654;
    bigint = 9223372036854775807L;
    columns = [ "Last Name", "First Name", "MI" ];
    bitmask = 0x1FC3;
  };
};
]]

print("\n- test general decode of complex sample libconfig data")
local cfg, msg = config.decode(cfg_str)
if not cfg then
    print("  failed, msg = " .. msg)
    print("= fail")
else
    print("  success, type(cfg) = \"" .. type(cfg) .. "\"")
end

assert(type(cfg) == "table", "returned configuration is not a table")

print("  cfg:")
print_table(cfg, 2, "  ")
print("= ok")

--------------------------------------------------------------------------------
local cfg_str_original =
[[
    version: "1.0",
    application: {
        misc: {
            bitmask: 8131,
            pi: 3.141592654,
            columns: ["Last Name", "First Name", "MI"],
            bigint: 99999999999999L
        },
        window: {
            pos: {y: 250, x: 350},
            title: "My Application",
            size: {w: 640, h: 480}
        },
        books: (
            {price: 29.95, author: "Robert Louis Stevenson", title: "Treasure Island", qty: 5},
            {price: 9.99, author: "Neal Stephenson", title: "Snow Crash", qty: 8}
        ),
        list: (("abc", 123, true), 1.234)}
]]

local cfg_str_desired = table.concat({
    'version: "1.0", ',
    'application: {',
    'window: {size: {w: 640, h: 480}, title: "My Application", pos: {y: 250, x: 350}}, ',
    'misc: {bigint: 99999999999999L, bitmask: 8131, columns: ["Last Name", "First Name", "MI"], pi: 3.141592654}, ',
    'books: (',
    '{price: 29.95, author: "Robert Louis Stevenson", title: "Treasure Island", qty: 5}, ',
    '{price: 9.99, author: "Neal Stephenson", title: "Snow Crash", qty: 8}',
    '), ',
    'list: (("abc", 123, true), 1.234)',
    '}'
})

print("\n- test encode of decoded libconfig data")
cfg, msg = config.decode(cfg_str_original)
if not cfg then
    print("  failed, error = " .. msg)
else
    cfg_str, msg = config.encode(cfg)
    if not cfg_str then
        print("  failed to encode: " .. msg)
        print("= fail")
    else
        print("  encoded: \n    '" .. cfg_str .. "'")
        assert(cfg_str == cfg_str_desired, "cfg_str != cfg_str_desired:\n    '" .. cfg_str_desired .. "'")
        print("= ok")
    end
end

print("\n- [ end ]")
