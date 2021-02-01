/* luaconfig.c
 *
 * Copyright (c) 2013-2021 Inango Systems LTD.
 *
 * Author: Inango Systems LTD. <support@inango-systems.com>
 * Creation Date: Sep 2013
 *
 * The author may be reached at support@inango-systems.com
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * Subject to the terms and conditions of this license, each copyright holder
 * and contributor hereby grants to those receiving rights under this license
 * a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable
 * (except for failure to satisfy the conditions of this license) patent license
 * to make, have made, use, offer to sell, sell, import, and otherwise transfer
 * this software, where such license applies only to those patent claims, already
 * acquired or hereafter acquired, licensable by such copyright holder or contributor
 * that are necessarily infringed by:
 *
 * (a) their Contribution(s) (the licensed copyrights of copyright holders and
 * non-copyrightable additions of contributors, in source or binary form) alone;
 * or
 *
 * (b) combination of their Contribution(s) with the work of authorship to which
 * such Contribution(s) was added by such copyright holder or contributor, if,
 * at the time the Contribution is added, such addition causes such combination
 * to be necessarily infringed. The patent license shall not apply to any other
 * combinations which include the Contribution.
 *
 * Except as expressly stated above, no rights or licenses from any copyright
 * holder or contributor is granted under this license, whether expressly, by
 * implication, estoppel or otherwise.
 *
 * DISCLAIMER
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * NOTE
 *
 * This is part of a management middleware software package called MMX that was developed by Inango Systems Ltd.
 *
 * This version of MMX provides web and command-line management interfaces.
 *
 * Please contact us at Inango at support@inango-systems.com if you would like to hear more about
 * - other management packages, such as SNMP, TR-069 or Netconf
 * - how we can extend the data model to support all parts of your system
 * - professional sub-contract and customization services
 *
 */

/*/-----------------------------------------------------------------------------
 * Description: Lua module for in-memory libconfig data decoding/encoding
/*/

#include <string.h>

#include <lua.h>
#include <lauxlib.h>

#include <libconfig.h>
//------------------------------------------------------------------------------
typedef enum
{
    ST_SCALAR,
    ST_AGGREGATE
} AddedSettingType;
//------------------------------------------------------------------------------
// Finalization functions.
// Functions push arguments returned by Lua functions to the stack and return
// arguments count.
//------------------------------------------------------------------------------
static int set_success_result(lua_State *lua, int table_index)
{
    if (table_index != lua_gettop(lua) && table_index != -1)
        lua_pushvalue(lua, table_index);
    return 1;
}
//------------------------------------------------------------------------------
static int set_failure_result(lua_State *lua, const char *message)
{
    lua_pushnil(lua);
    lua_pushstring(lua, message);
    return 2;
}
//------------------------------------------------------------------------------
static int set_config_failure_result(lua_State *lua, config_t *cfg)
{
    static const int BUFFER_SIZE = 1024;

    char message[BUFFER_SIZE];
    snprintf(message, BUFFER_SIZE, "%s at line %d", config_error_text(cfg), config_error_line(cfg));

    config_destroy(cfg);

    lua_pushnil(lua);
    lua_pushstring(lua, message);
    return 2;
}
//------------------------------------------------------------------------------
// Lua stack helpers
//------------------------------------------------------------------------------
static void lua_push_str_or_int(lua_State * lua, const char * str, int num)
{
    if (str)
        lua_pushstring(lua, str);
    else
        lua_pushinteger(lua, num);
}
//------------------------------------------------------------------------------
// Lua table helpers
//------------------------------------------------------------------------------
static void lua_set_table_int(lua_State *lua, const char *name, int i, int value)
{
    lua_push_str_or_int(lua, name, i);
    lua_pushinteger(lua, value);
    lua_settable(lua, -3);
}
//------------------------------------------------------------------------------
static void lua_set_table_num(lua_State *lua, const char *name, int i, double value)
{
    lua_push_str_or_int(lua, name, i);
    lua_pushnumber(lua, value);
    lua_settable(lua, -3);
}
//------------------------------------------------------------------------------
static void lua_set_table_str(lua_State *lua, const char *name, int i, const char *value)
{
    lua_push_str_or_int(lua, name, i);
    lua_pushstring(lua, value);
    lua_settable(lua, -3);
}
//------------------------------------------------------------------------------
static void lua_set_table_bool(lua_State *lua, const char *name, int i, int value)
{
    lua_push_str_or_int(lua, name, i);
    lua_pushboolean(lua, value);
    lua_settable(lua, -3);
}
//------------------------------------------------------------------------------
static void lua_set_table_newtable(lua_State *lua, const char *name, int i, int n_arr, int n_rec)
{
    // function adds new table to the table and keeps new table on top of the stack
    lua_createtable(lua, n_arr, n_rec);
    lua_push_str_or_int(lua, name, i);
    lua_pushvalue(lua, -2);              // stack: |...|-4: table|-3: new_table|-2: name or i|-1: new_table|
    lua_settable(lua, -4);               // stack: |...|-2: table|-1: new_table|
}
//------------------------------------------------------------------------------
static void lua_set_table_function(lua_State *lua, const char *name, lua_CFunction fn)
{
    lua_pushstring(lua, name);
    lua_pushcfunction(lua, fn);
    lua_settable(lua, -3);
}
//------------------------------------------------------------------------------
static AddedSettingType lua_set_table_setting(lua_State *lua, config_setting_t *setting, int i)
{
    const char *name = config_setting_name(setting);

    switch (config_setting_type(setting))
    {
    case CONFIG_TYPE_INT:    lua_set_table_int (lua, name, i, config_setting_get_int(setting));    break;
    case CONFIG_TYPE_INT64:  lua_set_table_num (lua, name, i, config_setting_get_int64(setting));  break;
    case CONFIG_TYPE_FLOAT:  lua_set_table_num (lua, name, i, config_setting_get_float(setting));  break;
    case CONFIG_TYPE_STRING: lua_set_table_str (lua, name, i, config_setting_get_string(setting)); break;
    case CONFIG_TYPE_BOOL:   lua_set_table_bool(lua, name, i, config_setting_get_bool(setting));   break;

    case CONFIG_TYPE_ARRAY:
    case CONFIG_TYPE_LIST:
        lua_set_table_newtable(lua, name, i, config_setting_length(setting), 0);
        return ST_AGGREGATE;

    case CONFIG_TYPE_GROUP:
        lua_set_table_newtable(lua, name, i, 0, config_setting_length(setting));
        return ST_AGGREGATE;

    default:
        break;  // suppressing warning
    }

    return ST_SCALAR;
}
//------------------------------------------------------------------------------
static int lua_new_table_from_settings(lua_State *lua, config_setting_t *setting)
{
    int table_stack_index   = lua_gettop(lua)   + 1;
    int parents_stack_index = table_stack_index + 1;
    int start_index         = 1;

    lua_newtable(lua);       // new result table (what we return)
    lua_newtable(lua);       // new helper table (used to store references to parent tables fot children)
    lua_pushvalue(lua, -2);  // stack: |...|-3: table|-2: parents_table|-1: table|

    for (config_setting_t *parent_setting = setting; parent_setting;)
    {
        for (int i = start_index; i <= config_setting_length(parent_setting);)
        {
            setting = config_setting_get_elem(parent_setting, (unsigned int)(i - 1));

            if (ST_AGGREGATE != lua_set_table_setting(lua, setting, i))
            {
                ++i;
            }
            else  // stack: |...|-2: table|-1: new_table|
            {
                // add the reference to the table using new_table as a key and remove the table from stack
                lua_pushvalue(lua, -1);                  // stack: |...|-3: table|-2: new_table|-1: new_table|
                lua_pushvalue(lua, -3);                  // stack: |...|-4: table|-3: new_table|-2: new_table|-1: table|
                lua_settable(lua, parents_stack_index);  // stack: |...|-2: table|-1: new_table|, Lua: key_table[new_table] = table
                lua_replace(lua, -2);                    // stack: |...|-1: new_table|

                // prepare to go one level down not leaving the for()
                parent_setting = setting;
                i              = 1;
            }
        }

        // all elements where enumerated on the level - returning to the upper level if we can or the work is done
        if (config_setting_is_root(parent_setting))
            parent_setting = NULL;  // done
        else
        {
            // getting parent table of the table
            lua_pushvalue(lua, -1);                  // stack: |...|-2: table|-1: table|
            lua_gettable(lua, parents_stack_index);  // stack: |...|-2: table|-1: parent_table|
            if (!lua_istable(lua, -1))
            {
                lua_settop(lua, table_stack_index);  // leave only result table on top
                return 0;
            }

            // remove table from stack leaving parent on the top
            lua_replace(lua, -2);                    // stack: |...|-1: parent_table|

            // !!!: config_setting_index() is rather heavy operation as it involves full scan on parent elements
            start_index    = 2 + config_setting_index(parent_setting);  // (index next to the parent) + 1 == parent index + 2
            parent_setting = config_setting_parent(parent_setting);
        }
    }

    lua_settop(lua, table_stack_index);  // leave only result table on top
    return 1;
}
//------------------------------------------------------------------------------
// Exported Lua functions
//------------------------------------------------------------------------------
static int lua_config_decode(lua_State *lua)
{
    const char *str_config;
    config_t    cfg;

    if (!lua_gettop(lua))
        return set_failure_result(lua, "No arguments are provided");

    if (LUA_TSTRING != lua_type(lua, 1))
        return set_failure_result(lua, "The argument is not a string");

    str_config = lua_tostring(lua, 1);
    if (str_config == NULL)
        return set_failure_result(lua, "Failed to cast Lua argument as C string");

    config_init(&cfg);

    if (!config_read_string(&cfg, str_config))
        return set_config_failure_result(lua, &cfg);

    if (!config_root_setting(&cfg))
    {
        config_destroy(&cfg);
        return set_failure_result(lua, "Config root setting is NULL");
    }

    lua_settop(lua, 0);      // no need for arguments anymore

    if (!lua_new_table_from_settings(lua, config_root_setting(&cfg)))
    {
        config_destroy(&cfg);
        return set_failure_result(lua, "Decoder internal navigation failure");
    }

    config_destroy(&cfg);
    return set_success_result(lua, -1);  // result table is on top of the stack
}
//------------------------------------------------------------------------------
// Entry points for Lua require()
//------------------------------------------------------------------------------
int luaopen_lualibconfig(lua_State *lua)
{
    static const struct luaL_Reg funcs[] =
    {
        {"decode", lua_config_decode},
        {NULL    , NULL}
    };

    // no need for global table - just return unnamed table with functions
    lua_newtable(lua);
    for (const luaL_Reg *fn_reg = funcs; NULL != fn_reg->name; ++fn_reg)
        lua_set_table_function(lua, fn_reg->name, fn_reg->func);

    return 1;
}
//------------------------------------------------------------------------------
int luaopen_mmx_lualibconfig(lua_State *lua)
{
    // Workaround for loading module from mmx subdirectory of lua home directory
    // Module should be loaded using require("mmx.lualibconfig")
    return luaopen_lualibconfig(lua);
}
