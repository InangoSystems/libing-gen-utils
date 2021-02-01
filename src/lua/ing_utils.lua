#!/usr/bin/lua
--[[
################################################################################
#
# ing_utils.lua
#
# Copyright (c) 2013-2021 Inango Systems LTD.
#
# Author: Inango Systems LTD. <support@inango-systems.com>
# Creation Date: 27 Jan 2014
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
  Creation date: Jan 27, 2014

  Description:
       File contains number of common Lua functions used by various
       Inango MMX components
--]]

LOG_TYPE="file"
ing = ing or {}
ing.utils = {}

--[[----------------------------------------------
    MMX Result Codes
------------------------------------------------]]
ing.ResCode = {
    SUCCESS      = 0,
    FAIL         = 1,
    WRONG_USAGE  = 2,
    INVALID_DATA = 3,
    FORBIDDEN    = 4,
}

--[[----------------------------------------------
    MMX Status Codes
------------------------------------------------]]
ing.StatCode = {
    OK      = 0, -- No additional actions are required
    RESTART = 1, -- Restart Backend
}

ing.types = {
    string = "string",
    number = "number",
    boolean = "boolean",
    enum = "enum",
    commaSeparatedList = "commaSeparatedList"
}

--[[-------------------------------------------------------------------------------
    Prints resCode and its variable arguments separated
    by semicolon then terminates the script with
    the exit status equal to resCode. The default value
    for resCode is ing.ResCode.SUCCESS.

    Example:
     ing.utils.exit(ing.ResCode.SUCCESS, ing.StatCode.OK, "br-vlan2", "10.0.0.120")

    Output example:
     0; 0; br-vlan2; 10.0.0.120;
---------------------------------------------------------------------------------]]
function ing.utils.exit(resCode, ...)
    resCode = resCode or ing.ResCode.SUCCESS

    local output = resCode..";"
    for _, argument in ipairs({...}) do
        output = output.." "..tostring(argument)..";"
    end

    print(output)
    os.exit(resCode)
end

--[[-----------------------------------------------------
    Executes command then returns a table containing
    its exit status under exitStatus key and united
    stdout and stderr output split up into lines under
    output key. If execution fails returns nil and an
    error message.
-------------------------------------------------------]]
function ing.utils.runCommand(command)
    command = ('output=`{ %s\n } 2>&1`; echo "$?"; echo -n "$output"'):format(command)
    local pipe, errorMsg = io.popen(command)
    if not pipe then
        return nil, errorMsg
    end

    local result = {};
    result.exitStatus = pipe:read("*number", "*line") -- NOTE: "*line" is to skip the line feed

    result.output = {}
    for line in pipe:lines() do
        table.insert(result.output, line)
    end

    pipe:close()
    return result
end

local function extractKeyArgs(args)
    local keyArgs = {}

    for index, token in pairs(args) do
        local isParam, param = ing.utils.startsWith(token, "-")
        if isParam
        and index > 0
        and param ~= ""
        and param ~= "pname"
        and param ~= "pvalue" then
            local arg = args[index + 1]
            if not arg then
                return false, args, keyArgs
            end

            keyArgs[param] = arg
            args[index], args[index + 1] = nil, nil
        end
    end

    return true, args, keyArgs
end

local function extractSetVarArgs(args)
    local varArgs = {}

    for index, token in pairs(args) do
        if token == "-pname" then
            local param = args[index + 1]
            if not param then
                return false, args, varArgs
            end

            if args[index + 2] ~= "-pvalue" then
                return false, args, varArgs
            end

            token = args[index + 3]
            if token ~= "-pname" then
                varArgs[param] = token or ""
                args[index + 3] = nil
            else
                varArgs[param] = ""
            end

            args[index], args[index + 1], args[index + 2] = nil, nil, nil
        end
    end

    return true, args, varArgs
end

local function extractGetVarArgs(args)
    local varArgs = {}

    for index, token in pairs(args) do
        if token == "-pname" then
            local param = args[index + 1]
            if not param then
                return false, args, varArgs
            end

            varArgs[param] = true
            args[index], args[index + 1] = nil, nil
        end
    end

    return true, args, varArgs
end

local function parseArgs(args, keyParams, optionalVarParams, mandatoryVarParams, flags)
    local argsNum = #args

    local result = {}
    result.valid, result.key, result.variable = false, {}, {}

    flags = flags or {}
    if flags.get then
        result.valid, args, result.variable = extractGetVarArgs(args)
    else
        result.valid, args, result.variable = extractSetVarArgs(args)
    end
    if not result.valid then
        local errorMsg = "Variable arguments are malformed"
        return result, errorMsg
    end

    result.valid, args, result.key = extractKeyArgs(args)
    if not result.valid then
        local errorMsg = "Key arguments are malformed"
        return result, errorMsg
    end

    keyParams = keyParams or {}
    for _, param in pairs(keyParams) do
        if result.key[param] == nil then
            result.valid = false
            local errorMsg = ("Key argument %s is missing"):format(param)
            return result, errorMsg
        end
    end

    mandatoryVarParams = mandatoryVarParams or {}
    for _, param in pairs(mandatoryVarParams) do
        if result.variable[param] == nil then
            result.valid = false
            local errorMsg = ("Mandatory variable argument %s is missing"):format(param)
            return result, errorMsg
        end
    end

    if flags.strictly then
        for param, _ in pairs(result.key) do
            if not ing.utils.tableContainsValue(keyParams, param) then
                result.valid = false
                local errorMsg = "Extra key argument "..param
                return result, errorMsg
            end
        end

        optionalVarParams = optionalVarParams or {}
        for param, _ in pairs(result.variable) do
            if not ing.utils.tableContainsValue(optionalVarParams, param)
               and not ing.utils.tableContainsValue(mandatoryVarParams, param) then
                result.valid = false
                local errorMsg = "Extra variable argument "..param
                return result, errorMsg
            end
        end
    end

    for i = 1, argsNum do
        local argument = args[i]
        if argument then
            result.valid = false
            local errorMsg = "Unrecognized argument "..argument
            return result, errorMsg
        end
    end

    return result
end

--[[----------------------------------------------------------------------------------------------
      Parses command line arguments formatted in MMX set style
    (ie [-key key]... [-pname pname -pvalue [pvalue] ]... ).
      Command line arguments are passed in args table where args[1] and args[n]
    are the first and the last nth arguments respectively and args contains
    no holes.
      Expected key parameters are passed in keyParams table containing their
    names without leading "-" (eg {"ifname", "ipaddr", "netmask"}). keyParams
    are optional thus nil or empty table are ok.
      Possible variable parameters are passed in optionalVarParams and mandatoryVarParams
    tables containing their names (eg {"IPAddress", "SubnetMask", "AddressingType"}).
    mandatoryVarParams is for mandatory parameters which have to be passed on the command
    line whereas optionalVarParams is for optional parameters which may be passed on
    the command line. Both tables are optional thus nil or empty table are ok.
      If parseStrictly is false (default is true) then properly formatted extra parameters
    not listed in keyParams, varParams or mandatoryVarParams tables don't lead to parsing
    error and are also parsed and returned with other parsed parameters.
      Returns a table containing "valid" key with a boolean value conveying command line
    is valid or not. Parsed key and variable parameters are in subtables with "key" and
    "variable" keys respectively. This subtables contains a record for the each recognized
    parameter where its key is parameter's name and its value is parameter's value.
    Subtables are always present and in case of invalid command line contains valid
    parameters parsed until parsing error occurs.
      If parsing error occurs (not MMX style, absent key or mandatory variable parameter,
    extra parameters) additionaly returns error message.

    Example:
     #1 keyParams = {"ifname"}; optionalVarParams = {"SubnetMask"}; mandatoryVarParams = {"IPAddress"}
     -ifname br-vlan1 -pname IPAddress -pvalue 10.0.0.120 -pname Extra -pvalue

     #2 keyParams = {"ifname"}; optionalVarParams = {"SubnetMask"}; parseFreely = true
     -ifname st0 -pname SubnetMask -pvalue 255.255.255.0

     #3 keyParams = {"ifname"}; optionalVarParams = {"SubnetMask"}; mandatoryVarParams = {"IPAddress"}
     -ifname st0 -pname SubnetMask -pvalue 255.255.255.0

     #4 keyParams = {"ifname", "ipaddr"}; optionalVarParams = {"IPAddress", "SubnetMask"}
     -ifname st0 -pname IPAddress -pvalue

    Example result:
     #1 {valid = false, -- Not listed Extra variable parameter
         key = {ifname = "br-vlan1"},
         variable = {IPAddress = "10.0.0.120", Extra = ""}}

     #2 {valid = true,
         key = {ifname = "st0"},
         variable = {SubnetMask = "255.255.255.0", Extra = ""}}

     #3 {valid = false, -- Absent mandatory IPAddress variable parameter
         key = {ifname = "st0"},
         variable = {SubnetMask = "255.255.255.0"}}

     #4 {valid = false, -- Absent ipaddr key parameter
         key = {ifname = "st0"},
         variable = {IPAddress = ""}}
------------------------------------------------------------------------------------------------]]
function ing.utils.parseSetArgs(arg, keyParams, optionalVarParams, mandatoryVarParams, parseStrictly)
    if parseStrictly == nil then
        parseStrictly = true;
    end

    return parseArgs(
        arg, keyParams, optionalVarParams, mandatoryVarParams, {strictly = parseStrictly})
end

--[[----------------------------------------------------------------------------------------------
      Parses command line arguments formatted in MMX get style
    (ie [-key key]... [-pname pname]... ).
      Command line arguments are passed in args table where args[1] and args[n]
    are the first and the last nth arguments respectively and args contains
    no holes.
      Expected key parameters are passed in keyParams table containing their
    names without leading "-" (eg {"ifname", "ipaddr", "netmask"}). keyParams
    are optional thus nil or empty table are ok.
      Possible variable parameters are passed in optionalVarParams and mandatoryVarParams
    tables containing their names (eg {"IPAddress", "SubnetMask", "AddressingType"}).
    mandatoryVarParams is for mandatory parameters which have to be passed on the command
    line whereas optionalVarParams is for optional parameters which may be passed on
    the command line. Both tables are optional thus nil or empty table are ok.
      If parseStrictly is false (default is true) then properly formatted extra parameters
    not listed in keyParams, varParams or mandatoryVarParams tables don't lead to parsing
    error and are also parsed and returned with other parsed parameters.
      Returns a table containing "valid" key with a boolean value conveying command line
    is valid or not. Parsed key and variable parameters are in subtables with "key" and
    "variable" keys respectively. This subtables contains a record for the each recognized
    parameter where its key is parameter's name and its value is parameter's value (true
    for variable parameters). Subtables are always present and in case of invalid command
    line contains valid parameters parsed until parsing error occurs.
      If parsing error occurs (not MMX style, absent key or mandatory variable parameter,
    extra parameters) additionaly returns error message.

    Example:
     #1 keyParams = {"ifname"}; optionalVarParams = {"IPAddress", "SubnetMask"}
     -ifname br-vlan1 -pname IPAddress

     #2 keyParams = {"ifname"}; optionalVarParams = {"SubnetMask"}
     -ifname br-vlan1 -pname SubnetMask -pname IPAddress

     #3 keyParams = {"ifname", "ipaddr"}; varParams = {}
     -ifname br-vlan1 -ipaddr 10.0.0.120

    Example result:
     #1 {valid = true,
         key = {ifname = "br-vlan1"},
         variable = {IPAddress = true}}

     #2 {valid = false, -- Extra IPAddress variable parameter
         key = {ifname = "br-vlan1"},
         variable = {SubnetMask = true, IPAddress = true}}

     #3 {valid = true,
         key = {ifname = "br-vlan1", ipaddr = "10.0.0.120"},
         variable = {}}
------------------------------------------------------------------------------------------------]]
function ing.utils.parseGetArgs(arg, keyParams, optionalVarParams, mandatoryVarParams, parseStrictly)
    if parseStrictly == nil then
        parseStrictly = true;
    end

    return parseArgs(
        arg, keyParams, optionalVarParams, mandatoryVarParams, {get = true, strictly = parseStrictly})
end

function ing.utils.toNumber(value)
    local num = tonumber(value)
    if num == nil then
        return nil, ("incorrect type: %s ~= number"):format(value)
    end
    return num
end

function ing.utils.toBoolean(value)
    local res, boolValue = ing.utils.isBoolean(value)
    if res ~= 0 then
        return nil, ("incorrect type: %s ~= boolean"):format(value)
    end
    return boolValue
end

function ing.utils.toEnum(value, rule)
    local itemRule = rule.itemRule or {["type"] = rule.itemType}
    local value, errorMsg = ing.utils.convertValue(value, itemRule)
    if value == nil then
        return nil, errorMsg
    end

    local res = ing.utils.tableContainsValue(rule.enum, value)
    if not res then
        return nil, ("incorrect type: enumeration not contains value %s"):format(value)
    end

    return value
end

function ing.utils.toList(value, rule)
    local itemRule = rule.itemRule or {["type"] = rule.itemType}
    local list = ing.utils.split(value, ",")

    for k, v in pairs(list) do
        local res, errorMsg = ing.utils.convertValue(v, itemRule)
        if res == nil then
            return nil, errorMsg
        end
        list[k] = res
    end

    return list
end

function ing.utils.convertValue(value, rule)
    if rule.type == ing.types.string then
        return tostring(value)
    elseif rule.type == ing.types.number then
        return ing.utils.toNumber(value)
    elseif rule.type == ing.types.boolean then
        return ing.utils.toBoolean(value)
    elseif rule.type == ing.types.enum then
        return ing.utils.toEnum(value, rule)
    elseif rule.type == ing.types.commaSeparatedList then
        return ing.utils.toList(value, rule)
    end
    return value
end

--[[----------------------------------------------------------------------------
    Convert arguments
    Support type: string, number, boolean, enum, commaSeparatedList.
    input arguments: args, ruleSet
        * args - table with keys and values (returned from parse{Get/Set}Args function)
        * ruleSet - set of rules that determine how to convert the value: contains
        ** type - the excpected type for value, if the type is not defined, no conversion required
        ** type specified option:
        *** for enum type
        **** enum - table with all enumeration values
        **** itemType - determine type for enumeration value
        **** itemRule - specified rule for enumeration value
        *** commaSeparatedList
        **** itemType - determine type for each item in list
        **** itemRule - specified rule for each item in list
------------------------------------------------------------------------------]]
local function convertArgs( args, ruleSet, flags )
    local function convertPart(partIn)
        local errorMsg
        local partOut = {}
        for key, value in pairs(partIn) do 
            if (ruleSet[key]) then
                partOut[key], errorMsg = ing.utils.convertValue(value, ruleSet[key])
                if partOut[key] == nil then
                    return nil, errorMsg
                end
            else
                partOut[key] = value
            end
        end
        return partOut
    end

    local vars = {}
    local keys, errorMsg = convertPart(args.key or {})
    if keys == nil then
        return nil, errorMsg
    end

    if not flags.get then
        vars, errorMsg = convertPart(args.variable or {})
    if vars == nil then
        return nil, errorMsg
        end
    end

    return {key = keys, variable = vars}
end

function ing.utils.convertGetArgs( args, ruleSet)
    return convertArgs( args, ruleSet, {get = true} )
end
function ing.utils.convertSetArgs( args, ruleSet)
    return convertArgs( args, ruleSet, {get = false} )
end

--[[ ---------- tableToString ---------------
  Small helper converting Lua table to string
   (usefull for printing Lua table as a string)
    Input params:
       t      - Lua table
       intent - intent symbols (for example, number of blanks)
    Returns:  Resulting string
-- ------------------------------------------]]
function ing.utils.tableToString (tbl, indent) 

    if tbl == nil then return "nil" end

    local indent = indent or ''
    local str = ""
    
    for key,value in pairs(tbl or {}) do
        str = str..indent..'['..tostring(key)..']'
        if type(value)=="table" and value==tbl then
            str=str..' = '.. tostring(value)..'\n' 
        elseif type(value)=="table" then 
            str=str..'\n'..ing.utils.tableToString(value,indent..'\t')
        else 
            str=str..' = '..tostring(value)..'\n' 
        end
    end

    return str
end

--[[----------------------------------------------------------------------------
    saves the table to the file.
    Are saved only next type for index or value: Number, string, boolean, table
    not saved : userdata, function, metatables
------------------------------------------------------------------------------]]
function ing.utils.tableSave( tbl, fileName )
    local charDelimeter, charEnd = "    ", "\n"
    local file, err = io.open(fileName, "wb")
    if err then return err end

    -- initiate variable for save procedure
    local tables, lookup = { tbl }, { [tbl] = 1 }
    file:write("return { " .. charEnd)

    for idx, t in pairs(tables) do
        file:write( ("-- talbe: { %d }"):format(idx) .. charEnd )
        file:write( ("{") .. charEnd )
        local thandled = {}
        -- only handle value(for indexed tables)
        for i,v in ipairs(t) do
            thandled[i] = true
            local stype = type(v)

            if stype == "table" then
                if not lookup[v] then
                    table.insert(tables, v)
                    lookup[v] = #tables
                end
                file:write( charDelimeter .. ("{ %s },"):format(lookup[v]) .. charEnd )
            elseif stype == "string" then
                file:write( charDelimeter .. ("%q,"):format(v) .. charEnd )
            elseif stype == "number" then
                file:write( charDelimeter .. ("%s,"):format(tostring(v)) .. charEnd )
            elseif stype == "boolean" then
                file:write( charDelimeter .. ("%s,"):format(tostring(v)) .. charEnd )
            end
        end

        -- handle index and value
        for i,v in pairs(t) do
            if not thandled[i] then
                -- thandled[i] = true
                local str = ""
                local stype = type( i )
                -- handle index
                if stype == "table" then
                    if not lookup[i] then
                        table.insert(tables, i)
                        lookup[i] = #tables
                    end
                    str = ( charDelimeter .. ("[{ %s }] = "):format(lookup[i]) )
                elseif stype == "string" then
                    str = ( charDelimeter .. ("[ %q ] = "):format(i) )
                elseif stype == "number" then
                    str = ( charDelimeter .. ("[ %s ] = "):format(i) )
                elseif stype == "boolean" then
                    str = ( charDelimeter .. ("[ %s ] = "):format(i) )
                end
                -- handle value
                if str ~= "" then
                    stype = type(v)
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert(tables, v)
                            lookup[v] = #tables
                        end
                        file:write( str .. ("{ %s },"):format(lookup[v]) .. charEnd )
                    elseif stype == "string" then
                        file:write( str .. ("%q,"):format(v) .. charEnd )
                    elseif stype == "number" then
                        file:write( str .. ("%s,"):format(tostring(v)) .. charEnd )
                    elseif stype == "boolean" then
                        file:write( str .. ("%s,"):format(tostring(v)) .. charEnd )
                    end
                end
            end
        end
        file:write( ("},") .. charEnd )
    end
    file:write( ("}") .. charEnd )
    file:close()
end

--[[----------------------------------------------------------------------------
    load table from file.
    file format "return { {<tbl1>}... }"
------------------------------------------------------------------------------]]
function ing.utils.tableLoad( fileName )
    local ftables, err = loadfile( fileName )
    if err then return _,err end

    local tables = ftables()
    for idx = 1, #tables do
        local tolinki = {}
        for i,v in pairs(tables[idx]) do
            if type(v) == "table" then
                tables[idx][i] = tables[v[1]]
            end
            if type(i) == "table" and tables[i[1]] then
                table.insert(tolinki, {i, tables[i[1]]})
            end
        end
        for _,v in ipairs(tolinki) do
            tables[idx][v[2]],tables[idx][v[1]] = tables[idx][v[1]], nil
        end
    end
    return tables[1]
end


--[[ --------------- split ----------------------
 The function breaks the input text string into substrings based on
  specified delimiter and return tables containing the resulting substrings.
  Delimiter may be specified as a string or as regular expression.
 Input parameters:
  text  - String containing the data to be splitted up
  delim - String containing separator pattern (delimiter) - optional parameter.
          if not presented - space symbols used as delimiter
  isRegex - Boolean value. If "true" the delimiter pattern is regarded as
          regular expression, otherwise the delimiter is interpreted
          as a plain text. Optional parameter, default value is false.
  max   - Maximum times to split; optional parameter

 Return: Lua table containing resulting substrings

 Examples:
  1.      split(test_str, "[&%s]", 4 , true)
     Split test_str string by delimiters "&" or any space symbol and return
     the first 4 substrings

  2.        split(test_str, " ")
     Split test_str with delimiter that is exactly one space symbol and return
     all received substring

  3.      split(test_str, ".{i}.")
     Split test_str with delimiter ".{i}." and return all received substring
----------------------------------------------------------------------------]]
function ing.utils.split(text, delim, isRegex, max)
    local list = {}
    local pos = 1

    -- If optional input parameters are not specified set then to the defaults
    if max == nil then max = #text end
    if isRegex == nil then isRegex = false end
    if delim == nil then
       delim = "%s"
       isRegex = true
    end

    -- Short verification of the input parameters
    if #text == 0 then return {""} end
    if max == 0 then return text end

    repeat
        local first, last = string.find(text, delim, pos, not isRegex)

        if first then
            --Delimiter is found. Save substr from pos to the delimiter
            table.insert(list, string.sub(text, pos, first-1))
            pos = (last and last+1) or (#text + 1)
        else
           --Delimiter is not found. Save substr from pos to the end
           table.insert(list, string.sub(text, pos))
           break
        end
    until not first or #list >= max or pos > #text

    return list
end

--[[--------------------------------------------------
    If the string starts with the prefix returns true
    and a suffix such that prefix..suffix == string;
    otherwise returns false
----------------------------------------------------]]
function ing.utils.startsWith(string, prefix)
    prefix = tostring(prefix)
    local len = prefix:len()
    if prefix == string:sub(1, len) then
        return true, string:sub(len + 1)
    end

    return false
end


--[[ ------------------------ matchCount -------------------------
 The function returns number of occurances of the specified pattern
 in the given string
 Input params:
   str - string to be processed
   pat - pattern searched in the string
 Return: number
------------------------------------------------------------]]
function ing.utils.matchCount(str, pat)
   local count = 0
   for _ in string.gmatch(str, pat) do
       count = count + 1
   end
   return count
end

--[[ ------------------------ is_ip -------------------------
 The function validates input string on IPv4 address pattern
 Input params:
   str - string to be validated
 Return: boolean value:
   true  - if the input string is a valid IPv4 address,
   false - otherwise
------------------------------------------------------------]]
function ing.utils.is_ip(str)
    local regex = "^(%d+)%.(%d+)%.(%d+)%.(%d+)$"

    --Save all 4 captures in case of pattern is matched
    local bytes = {string.match(str, regex)}

    if #bytes > 0 then
        for _, byte in ipairs(bytes) do
            byte = tonumber(byte)
            if not byte or byte < 0 or byte > 255 then
                return false
            end
        end
        return true
    else
        return false
    end
end

--[[ -------------------- is_mac ----------------------
  The function validates input string on mac address pattern
  (Correct MAC address may contains ":" or "-" delimiters.
  i.e. 00:11:22:33:44:55 or 00-11-22-33-44-55)
  Input params:
    str - string to be validated as mac address
  Return: boolean value:
   true  - if the input string is a valid MAC address,
   false - otherwise
-------------------------------------------------------------]]
function ing.utils.is_mac(str)
    local regex = "^[%x][%x]?[:-][%x][%x]?[:-][%x][%x]?[:-][%x][%x]?[:-][%x][%x]?[:-][%x][%x]?$"
    return (string.match(string.lower(str or ""), regex) ~= nil)
end

--[[ ----------------------- trim ----------------------------------------
  The function removes leading and trailing whitespaces from input string
  Input params:
    str - string to be processed
  Return:
    string without leading and trailing whitespace symbols
-------------------------------------------------------------------------]]
function ing.utils.trim(str)
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end


--[[ -------------------- is_bigendian --------------------------------
--- The function test whether the CPU is operating in big endian mode.
--  Return: boolean value
      true  - in case of our CPU is big endian
      false - in case of our CPU is little-endian
----------------------------------------------------------------------]]
function ing.utils.is_bigendian()
    return string.byte(string.dump(function() end), 7) == 0
end

--[[ -------------------------------------------------------
    The funtion performs reading from file and
    returns content of the file
    Input params:
        filepath - path to the file including file name
    Example:
        ing.utils.readFromFile("/tmp/file.txt")
    Return:
        res - string contains content of the file
-- --------------------------------------------------------]]
function ing.utils.readFromFile(filepath)
        local res = nil
        local file = io.open(filepath, "r")
        if file ~= nil then
            res = file:read()
            io.close(file)
        end

        return res
end

--[[ -------------------------------------------------------
    The funtion performs reading multiline file and
    returns content of the file
    Input params:
        filepath - path to the file including file name
    Example:
        ing.utils.readFromFile("/tmp/file.txt")
    Return:
        res - string contains content of the file
-- --------------------------------------------------------]]
function ing.utils.readFromMlFile(filepath)
        local res = nil
        local file = io.open(filepath, "r")
        if file ~= nil then
            res = file:read("*all")
            io.close(file)
        end

        return res
end

--[[-------------------------------------------------------
      Writes the value (string or number are acceptable) to
    the file whose location is the path.
      Returns true on success; otherwise false and an
    error message.
----------------------------------------------------------]]
function ing.utils.writeToFile(path, value)
    local file, errorMsg = io.open(path, "w")
    if not file then
        return false, errorMsg
    end

    local done, errorMsg = file:write(value)
    if not done then
        file:close()
        return false, errorMsg
    end

    file:close()
    return true
end

--[[ -------------------------------------------------------
    The funtion checks if the value is a boolean.
    The function returns resulting code
    and boolean value of input <value> if it is boolean
    Return:
        rescode - 0 is bool; 1 not bool
        res - true/false
-- --------------------------------------------------------]]
function ing.utils.isBoolean(value)
    if string.lower(value) == "true" or tonumber(value) == 1 or
    value == "1" or value == true then
        res = true
        return 0, res
    elseif string.lower(value) == "false" or tonumber(value) == 0 or
    value == "0" or value == false then
        res = false
        return 0, res
    else
        return nil
    end
end

--[[-------------------------------------------------------
      Checks if the value is an integer and returns
    true plus this integer if so; otherwise false
----------------------------------------------------------]]
function ing.utils.isInteger(value)
    local number = tonumber(value)
    if not number or math.floor(number) ~= number then
        return false
    end

    return true, number
end

--[[-------------------------------------------------------
      Checks if the value is an unsigned integer and
    returns true plus this integer if so; otherwise false
----------------------------------------------------------]]
function ing.utils.isUnsignedInteger(value)
    local isInteger, integer = ing.utils.isInteger(value)
    if not isInteger or integer < 0 then
        return false
    end

    return true, integer
end

--[[ -------------------------------------------------------
    (Temporary solution. Should be improved)
    The function writes message to log file.
    Input params:
        fileName - name of the log file
        <second and next parametes> - which will be concatinated to one log message
    Example:
        ing.utils.logMessage("logFile", "Log message 1", "Log message 2")
    Return:
        res - string contains content of the file
-- --------------------------------------------------------]]
function ing.utils.logMessage(fileName,  ...)


    if fileName == nil or type(fileName) ~= "string" then return end
    if (LOG_TYPE == "file") then
        local logpath = "/var/log/mmx"  --TODO move to EV
        for i=1,#arg do
            arg[i]=tostring(arg[i])
        end

        local file = io.open(logpath.."/"..fileName..".log","a")
        if not file then
            file = io.open(logpath.."/"..fileName..".log","a")
        end
        if file then
            file:write(os.date("[%Y-%m-%d %X] ")..(table.concat(arg," ")).."\n")
            file:close()
        end
    elseif (LOG_TYPE == "syslog") then
        log = require("posix")
        log.openlog(fileName, log.LOG_NDELAY + log.LOG_PID,log.LOG_USER)
        for i=1,#arg do
            log.syslog(log.LOG_INFO, tostring(arg[i]))
        end
        log.closelog()
    end
end

--[[-------------------------------------------------------------
    Returns table with the bunch of convenient wrapper functions
    around ing.utils.logMessage function
---------------------------------------------------------------]]
function ing.utils.getLogger(log, facility)
    local errorHdr   = (facility and tostring(facility).." <error>") or "<error>"
    local warningHdr = (facility and tostring(facility).." <warning>") or "<warning>"
    local infoHdr    = (facility and tostring(facility).." <info>") or "<info>"
    local debugHdr   = (facility and tostring(facility).." <debug>") or "<debug>"

    local logger = {}
    logger.error   = function (...) ing.utils.logMessage(log, errorHdr, ...) end
    logger.warning = function (...) ing.utils.logMessage(log, warningHdr, ...) end
    logger.info    = function (...) ing.utils.logMessage(log, infoHdr, ...) end
    logger.debug   = function (...) ing.utils.logMessage(log, debugHdr, ...) end

    return logger
end

--[[ -------------------------------------------------------
    The funtion input list and returns array without duplicated values
-- --------------------------------------------------------]]
function ing.utils.create_unique_list(list)
    local res = {}
    local tmpVal = nil

    table.sort(list)
    for key, val in pairs(list) do
        if tmpVal ~= val then
            res[#res + 1] = val
        end
        tmpVal = val
    end
    return res
end

--[[ -------------------------------------------------------
    The funtion input table and returns array without duplicated values
    Note: The input table must be "one-dimentional array", i.e
    it must not contains subtables
-- --------------------------------------------------------]]
function ing.utils.get_distinct_val(tbl)
    local res = {}
    local test = nil
    local isFound = false

    for key, val in pairs(tbl or {}) do
        isFound = false
        for i, resVal in pairs(res) do
            if val == resVal then
                isFound = true
                break
            end
        end
        if isFound == false then
            res[#res + 1] = val
        end
    end
    return res
end

--[[ -------------------------------------------------------
    Function returns file modification timestamp in seconds, or current
    timestamp in seconds if file is nil.
-- --------------------------------------------------------]]
function ing.utils.get_timestamp_in_secs(file)
    if file then
        file = "-r "..file
    else
        file = ""
    end

    local pipe = io.popen("date '+%s' "..file.." 2>/dev/null")
    local str = pipe:read("*line")
    pipe:close()

    return tonumber(str)
end

--[[ -------------------------------------------------------
    function return Unique values list
-- --------------------------------------------------------]]
function  ing.utils.removeDuplicatesFromList(list)
  local key_set = {}
  local res_list = {}
  for k,v in pairs(list) do
    if not key_set[v] then
      key_set[v] = true
      res_list[#res_list + 1] = v
    end
  end
  return res_list
end

--[[ -------------------------------------------------------
    Function returns true in case table contains specified value and false otherwise
-- --------------------------------------------------------]]
function  ing.utils.tableContainsValue(table, value)
    for k, v in pairs(table) do
        if value == v then
            return true
        end
    end
    return false
end

--[[ -------------------------------------------------------
    Function returns number of key-value entries in given table
-- --------------------------------------------------------]]
function  ing.utils.getTableSize(table)
    local count = 0

    for k, v in pairs(table or {}) do
        count = count + 1
    end

    return count
end

--[[---------------------------------------------------------- -
    Returns true if the table is empty; otherwise returns false
--------------------------------------------------------------]]
function ing.utils.isTableEmpty(table)
    return next(table) == nil
end

--[[ -------------------------------------------------------
    Function returns true in case 'list1' is equal to 'list2' and false otherwise.
    Boolean argument 'removeDuplicates' (true - by default) specifies
    if lists should be compared only by unique elements.
-- --------------------------------------------------------]]
function ing.utils.isListEqual(list1, list2, removeDuplicates)
    if list1 == nil or list2 == nil then
        return false
    end
    if removeDuplicates then
      list1 = ing.utils.removeDuplicatesFromList(list1)
      list2 = ing.utils.removeDuplicatesFromList(list2)
    end
    if #list1 ~= #list2 then
        return false
    end
    for key, value in pairs (list1) do
        if not ing.utils.tableContainsValue(list2, value) then
            return false
        end
    end
    return true
end
--[[ -------------------------------------------------------
    The function checks if list contains only unique elements, it works only with the indexed list.
    Function returns true if the list is unique or false otherwise.
-- --------------------------------------------------------]]
function ing.utils.isUniqList(list)
    local key_set = {}
    for _, v in ipairs(list) do
        if key_set[v] then
            return false
        else
            key_set[v] = true
        end
    end
    return true
end

--[[----------------------------------------------------------------------------
    If tmpfs overlay is used, function saves the specified filepath from tmpfs to flash.
    Otherwise, nothing done.
------------------------------------------------------------------------------]]
function ing.utils.saveToPersistMemory(filepath)
    local cmdFmt = "{ which tmpovrlctl && tmpovrlctl save -f %s ; } &>/dev/null"

    local cmd = cmdFmt:format(filepath)
    os.execute(cmd)
end

--[[ -------------------------------------------------------
    function subtracts list2 from list1.
    work with only indexes list.
    return result list with all value contains in list 1 and not contains in list2
-- --------------------------------------------------------]]
function ing.utils.substractList(list1, list2)
    local acc = {}
    local diffList = {}

    for k,v in ipairs(list1) do acc[v]=true end
    for k,v in ipairs(list2) do acc[v]=nil end
    local n = 0
    for k,v in ipairs(list1) do
        if acc[v] then table.insert(diffList, v) end
    end
    return diffList
end

--[[-------------------------------------------------------
      Returns true if the path resolves to an existing
    file; false otherwise. Returns nil if some error
    occurs.
----------------------------------------------------------]]
function ing.utils.fileExist(path)
    local status = os.execute(('[ -e "%s" ]'):format(path))
    if status == 0 then -- command exit code is 0
        return true
    elseif status == 256 then -- command exit code is 1
        return false
    else -- an error occured during command execution
        return nil
    end
end

--[[-------------------------------------------------------
      Returns true if the path resolves to an existing
    directory; false otherwise. Returns nil if some error
    occurs.
----------------------------------------------------------]]
function ing.utils.isDir(path)
    local status = os.execute(('[ -d "%s" ]'):format(path))
    if status == 0 then -- command exit code is 0
        return true
    elseif status == 256 then -- command exit code is 1
        return false
    else -- an error occured during command execution
        return nil
    end
end

--[[-------------------------------------------------------
      Returns true if the path resolves to an existing
    regular file; false otherwise. Returns nil if some
    error occurs.
----------------------------------------------------------]]
function ing.utils.isFile(path)
    local status = os.execute(('[ -f "%s" ]'):format(path))
    if status == 0 then -- command exit code is 0
        return true
    elseif status == 256 then -- command exit code is 1
        return false
    else -- an error occured during command execution
        return nil
    end
end

--[[-------------------------------------------------------
      Makes a directory and returns true on success;
    false otherwise
----------------------------------------------------------]]
function ing.utils.mkDir(path)
    local status = os.execute(('mkdir -p "%s" '):format(path))
    return status == 0
end

--[[-------------------------------------------------------
      Returns a table with the contents of the path;
    otherwise nil and an error message
----------------------------------------------------------]]
function ing.utils.lsPath(path)
    local command = ("ls -1 %s"):format(path)
    local execution, errorMsg = ing.utils.runCommand(command)
    if not execution then
        return nil, "Couldn't list path contents: "..errorMsg

    elseif execution.exitStatus ~= 0 then
        return nil, "Couldn't list path contents: "..table.concat(execution.output, '\n')
    end

    return execution.output
end

return ing
