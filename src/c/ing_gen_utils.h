/* ing_gen_utils_common.h
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


#ifndef ING_GEN_UTILS_COMMON_H_
#define ING_GEN_UTILS_COMMON_H_

#include <stdlib.h>
#include <stdio.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>
#include <stdarg.h>
#include <stddef.h>
#include <ctype.h>

typedef enum ing_stat_e {
    ING_STAT_OK,
    ING_STAT_GENERAL_ERROR,
    ING_STAT_SYSTEM_ERROR,
    ING_STAT_INVALID_ARGUMENT,
    ING_STAT_OUTOFMEMORY,
    ING_STAT_ALREADY_EXISTS,
    ING_STAT_NOT_FOUND,
    ING_STAT_FULL

} ing_stat_t;


#define NVP_MAX_NAME_LEN    128
#define NVP_MAX_VALUE_LEN   256

typedef struct namevaluepair_s {
    char name[NVP_MAX_NAME_LEN];
    char value[NVP_MAX_VALUE_LEN];
} namevaluepair_t;

typedef struct nvpair_s {
    char name[NVP_MAX_NAME_LEN];
    char *pValue;
} nvpair_t;


//typedef char    BOOL;
#define TRUE    1
#define FALSE   0

#define FIELD_SIZE(type, field)     (sizeof(((type *)0)->field))

#define POSITIVE_OR_ZERO(x) (((long)(x))>0?(x):0)

#define LAST_CHAR(str)  ((str)[POSITIVE_OR_ZERO(strlen(str)-1)])

#define max(a,b) \
    ({ __typeof__ (a) _a = (a); \
        __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })

#define min(a,b) \
    ({ __typeof__ (a) _a = (a); \
        __typeof__ (b) _b = (b); \
     _a < _b ? _a : _b; })

/***************************\
*         Logging           *
\***************************/

/*
 * Opens log
 */
void ing_openlog(void);

void ing_closelog(void);

/*
 * Logs msg with given priority
 */
void ing_log(int priority, char *msg, ...);

/* This message is written to cg_critical_err.log file regardless of log level
 * Only one message is stored, old ones will be rewritten
 */
void ing_log_critical(char *msg, ...);



/*
 * Safely concatenates two strings.
 * Returns resulting string or NULL if strlen of 'from' is bigger than 'to_len'
 */
char *strcat_safe(char *to, const char *from, size_t to_len);

/*
 * Safely copies a string to buffer 'to' of size 'to_len'
 * Returns pointer to the buffer or NULL if strlen of 'from' is bigger than 'to_len'
 */
char *strcpy_safe(char *to, const char *from, size_t to_len);

ing_stat_t unix_socket_init(int *sock, const char *sun_name);

ing_stat_t unix_socket_init_full(int *sock, const char *sun_name,
    struct sockaddr_un *saddr, int *saddr_size);

/*
 * Arguments addr and port must be provided in a host byte order
 */
ing_stat_t udp_socket_init(int *sock, in_addr_t addr, in_port_t port);

char *rstrstr(const char *s1, const char *s2);

char *trim(char *str);

char *trim_quotes(char *str);

char *str_toupper(char *str);

char *str_tolower(char *str);

/*
 * Replaces the first occurrence of `placeholder' in `str' of size `str_size'
 * by `replacement'
 */
int str_replace(char *str, size_t str_size, const char *placeholder, const char *replacement);


/*
 * Gets system uptime in seconds
 */
long get_uptime();

#endif /* ING_GEN_UTILS_COMMON_H_ */
