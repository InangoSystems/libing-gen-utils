/* ing_container.h
 *
 * Copyright (c) 2013-2021 Inango Systems LTD.
 *
 * Author: Inango Systems LTD. <support@inango-systems.com>
 * Creation Date: Jun 2013
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

/*
 * Inango hash container implementation
 */

#ifndef ING_CONTAINTER_H_
#define ING_CONTAINTER_H_

#include "uthash_ing.h"

#include "ing_gen_utils.h"
#include "bitmap.h"


#define _GENERATE_DB_TYPE(RECORD_TYPE, _DB_TYPE_SUFFIX) \
typedef struct RECORD_TYPE##_DB_TYPE_SUFFIX { \
    int max_rec_num;            /* max number of records */ \
    int rec_num;                /* current number of records */ \
    RECORD_TYPE *records;       /* records array */ \
    bitmap_t map_free;          /* bit map of free blocks */ \
    RECORD_TYPE *head;          /* hash table pointer */ \
    void *hash_buf;             /* TODO buffer for hash table */ \
} RECORD_TYPE##_DB_TYPE_SUFFIX;

#define GENERATE_DB_TYPE(RECORD_TYPE)   _GENERATE_DB_TYPE(RECORD_TYPE, _db_t)

#define _GENERATE_DB_DECLARATIONS(RECORD_TYPE, _DB_TYPE_SUFFIX, KEYFIELD_NAME) \
ing_stat_t init_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, int max_rec_num); \
ing_stat_t destroy_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db); \
ing_stat_t add_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, const RECORD_TYPE *xi_val); \
ing_stat_t del_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, const void *xi_key); \
ing_stat_t get_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, const void *xi_key, RECORD_TYPE **xo_val); \
int size_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db);

#define GENERATE_DB_DECLARATIONS(RECORD_TYPE, KEYFIELD_NAME) \
    _GENERATE_DB_DECLARATIONS(RECORD_TYPE, _db_t, KEYFIELD_NAME)

#define _GENERATE_DB_FUNCTIONS(RECORD_TYPE, _DB_TYPE_SUFFIX, KEYFIELD_NAME) \
ing_stat_t init_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, int max_rec_num) \
{ \
    if (!db) return ING_STAT_INVALID_ARGUMENT; \
    memset(db, 0, sizeof(RECORD_TYPE##_DB_TYPE_SUFFIX)); \
    db->max_rec_num = max_rec_num; \
    db->records = (RECORD_TYPE *)malloc(max_rec_num*sizeof(RECORD_TYPE)); \
    if (!db->records) \
        return ING_STAT_OUTOFMEMORY; \
    memset(db->records, 0, (max_rec_num*sizeof(RECORD_TYPE))); \
    if (bitmap_init(&db->map_free, max_rec_num, 1) < 0) \
        { free(db->records); return ING_STAT_SYSTEM_ERROR; } \
    return ING_STAT_OK; \
} \
 \
ing_stat_t destroy_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db) \
{ \
    if (!db) return ING_STAT_INVALID_ARGUMENT; \
    bitmap_destroy(&db->map_free); \
    if (db->head) \
        HASH_CLEAR(hh, db->head); \
        db->rec_num = 0; \
    if (db->records) { free(db->records); db->records = NULL; } \
    if (db->hash_buf) { free(db->hash_buf); db->hash_buf = NULL; } \
    return ING_STAT_OK; \
} \
 \
ing_stat_t add_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, const RECORD_TYPE *xi_val) \
{ \
    if (!db || !xi_val) return ING_STAT_INVALID_ARGUMENT; \
     \
    /* check if already exists */ \
    RECORD_TYPE *tmp; \
    HASH_FIND(hh, db->head, &(xi_val->KEYFIELD_NAME), \
        FIELD_SIZE(RECORD_TYPE, KEYFIELD_NAME), tmp); \
    if (tmp) \
        return ING_STAT_ALREADY_EXISTS; \
     \
    /* check if we have space */ \
    if (db->rec_num >= db->max_rec_num) return ING_STAT_FULL; \
    int ifree = bitmap_ffs(&db->map_free); \
    if (ifree < 0) return ING_STAT_FULL; \
     \
    /* add to array */ \
    memcpy(&db->records[ifree], xi_val, sizeof(RECORD_TYPE)); \
    bitmap_clear(&db->map_free, ifree); /* mark as occupied */ \
    db->rec_num ++; \
     \
    /* add to hash table */ \
    HASH_ADD(hh, db->head, KEYFIELD_NAME, \
        FIELD_SIZE(RECORD_TYPE, KEYFIELD_NAME), (&db->records[ifree])); \
     \
    return ING_STAT_OK; \
} \
 \
ing_stat_t del_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, const void *xi_key) \
{ \
    if (!db || !xi_key) return ING_STAT_INVALID_ARGUMENT; \
     \
    /* check if exists */ \
    RECORD_TYPE *tmp; \
    HASH_FIND(hh, db->head, xi_key, \
        FIELD_SIZE(RECORD_TYPE, KEYFIELD_NAME), tmp); \
    if (!tmp) \
        return ING_STAT_NOT_FOUND; \
     \
    /* delete from hash table */ \
    HASH_DELETE(hh, db->head, tmp); \
     \
    /* set its place free */ \
    bitmap_set(&db->map_free, tmp - db->records); \
    db->rec_num --; \
     \
    return ING_STAT_OK; \
} \
 \
/* Delete db entry that is already found in the db, so searching in not needed */  \
ing_stat_t del_val_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, RECORD_TYPE *xi_val) \
{ \
    if (!db || !xi_val) return ING_STAT_INVALID_ARGUMENT; \
     \
    /* delete from hash table */ \
    HASH_DELETE(hh, db->head, xi_val); \
     \
    /* set its place free */ \
    bitmap_set(&db->map_free, xi_val - db->records); \
    db->rec_num --; \
     \
    return ING_STAT_OK; \
} \
\
ing_stat_t get_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db, const void *xi_key, RECORD_TYPE **xo_val) \
{ \
    *xo_val = NULL; \
     \
    if (!db || !xi_key) return ING_STAT_INVALID_ARGUMENT; \
     \
    /* check if exists */ \
    RECORD_TYPE *tmp; \
    HASH_FIND(hh, db->head, xi_key, \
        FIELD_SIZE(RECORD_TYPE, KEYFIELD_NAME), tmp); \
    if (!tmp) \
        return ING_STAT_NOT_FOUND; \
    else \
        *xo_val = tmp; \
    return ING_STAT_OK; \
} \
 \
int size_##RECORD_TYPE(RECORD_TYPE##_DB_TYPE_SUFFIX *db) \
{ \
    if (!db) \
        return 0; \
    else \
        return db->rec_num; \
}

#define GENERATE_DB_FUNCTIONS(RECORD_TYPE, KEYFIELD_NAME) \
   _GENERATE_DB_FUNCTIONS(RECORD_TYPE, _db_t, KEYFIELD_NAME)

#define IC_INIT(RECORD_TYPE, DB_PTR, MAX_SIZE) \
    init_##RECORD_TYPE(DB_PTR, MAX_SIZE)

#define IC_DESTROY(RECORD_TYPE, DB_PTR) \
    destroy_##RECORD_TYPE(DB_PTR)

#define IC_ADD(RECORD_TYPE, DB_PTR, VAL_PTR) \
    add_##RECORD_TYPE(DB_PTR, VAL_PTR)

#define IC_DEL(RECORD_TYPE, DB_PTR, KEY_PTR) \
    del_##RECORD_TYPE(DB_PTR, KEY_PTR)

#define IC_DEL_VAL(RECORD_TYPE, DB_PTR, VAL_PTR) \
    del_val_##RECORD_TYPE(DB_PTR, VAL_PTR)

#define IC_GET(RECORD_TYPE, DB_PTR, KEY_PTR, VAL_PTR_PTR) \
    get_##RECORD_TYPE(DB_PTR, KEY_PTR, VAL_PTR_PTR)

#define IC_SIZE(RECORD_TYPE, DB_PTR) \
    size_##RECORD_TYPE(DB_PTR)
    
#define IC_DB_TYPE(RECORD_TYPE) RECORD_TYPE##_db_t

/* Macros implementing "for" loop over database specified by */
/* its record type and pointer to the DB itself              */

/* Loop over the whole DB container */ 
#define IC_FOREACH(RECORD_TYPE, ELEM, DB_PTR) \
    RECORD_TYPE *ELEM, *_tmp; \
    for ((ELEM) = (DB_PTR)->head, _tmp = ((DB_PTR)->head ? (DB_PTR)->head->hh.next : NULL); \
        (ELEM); (ELEM) = _tmp, _tmp = (_tmp ? _tmp->hh.next : NULL))

/* Loop over LIMIT number of elements of the DB container */
#define IC_FOREACH_LIMIT(RECORD_TYPE, ELEM, DB_PTR, LIMIT) \
    RECORD_TYPE *ELEM, *_tmp; int ic_cnt = 0; \
    for ((ELEM) = (DB_PTR)->head, _tmp = ((DB_PTR)->head ? (DB_PTR)->head->hh.next : NULL); \
        (ELEM) && ic_cnt < (LIMIT); \
        (ELEM) = _tmp, _tmp = (_tmp ? _tmp->hh.next : NULL), ic_cnt++)

/* Loop over the DB container starting from the specified element FROM */
#define IC_FOREACH_FROM(RECORD_TYPE, ELEM, FROM, DB_PTR) \
    RECORD_TYPE *ELEM, *_tmp; \
    for ((ELEM) = (FROM), _tmp = ((FROM) ? (FROM)->hh.next : NULL); \
        (ELEM); (ELEM) = _tmp, _tmp = (_tmp ? _tmp->hh.next : NULL), (FROM) = (ELEM))

/* Loop over LIMIT elements of the DB, starting from the specified element FROM */
#define IC_FOREACH_FROM_WITH_LIMIT(RECORD_TYPE, ELEM, DB_PTR, FROM, LIMIT) \
    RECORD_TYPE *ELEM, *_tmp; int ic_cnt = 0; \
    for ((ELEM) = (FROM), _tmp = ((FROM) ? (FROM)->hh.next : NULL); \
        (ELEM) && ic_cnt < (LIMIT); \
        (ELEM) = _tmp, _tmp = (_tmp ? _tmp->hh.next : NULL), (FROM) = (ELEM))

#endif /* ING_CONTAINTER_H_ */
