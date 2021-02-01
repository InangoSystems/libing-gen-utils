/* bitmap.h
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
 * Inango bitmap header file
 */

#ifndef BITMAP_H_
#define BITMAP_H_

#include <stdio.h>  /* printf */
#include <string.h> /* memset */
#include <stdlib.h> /* calloc, free */

#define _ulong unsigned long

/* Returns ceil(a/b) */
#define ceil_div(a,b)  ( ((a)/(b)*(b) == (a)) ? ((a)/(b)) : ((a)/(b)+1) )

typedef struct bitmap_s
{
    _ulong *map;
    int elements;
} bitmap_t;

#define NUM_ULONGS(elems)   ceil_div((elems), 8*sizeof(_ulong))
#define NUM_BYTES(elems)    (NUM_ULONGS(elems)*sizeof(_ulong))
#define I_ULONG(idx)        ((idx)/8/sizeof(_ulong))
#define I_BIT(idx)          ((idx) % (8*sizeof(_ulong)))

/* initialize bitmap; returns -1 if num_of_elements exceeds upper limit
 * if set_all is true, sets all bits to 1
 */
int bitmap_init(bitmap_t *bmp, int num_of_elements, int set_all);

/* destroy bitmap */
int bitmap_destroy(bitmap_t *bmp);

/* debug output */
int bitmap_show(bitmap_t *bmp);

/* find first set; returns -1 if didn't find anything */
int bitmap_ffs(bitmap_t *bmp);

/* set bit idx; returns -1 on if index exceeds upper limit */
int bitmap_set(bitmap_t *bmp, int idx);

/* reset bit idx; returns -1 if index exceeds upper limit
 * if idx < 0, clears whole bitmap
 */
int bitmap_clear(bitmap_t *bmp, int idx);

/* get bit status; returns -1 if index exceeds upper limit */
int bitmap_get(bitmap_t *bmp, int idx);

#endif /* BITMAP_H_ */
