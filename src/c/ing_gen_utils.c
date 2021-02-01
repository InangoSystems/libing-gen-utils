/* ing_gen_utils_common.c
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

#include <string.h>
#include <errno.h>
#include <sys/sysinfo.h>
#include "ing_gen_utils.h"


ing_stat_t unix_socket_init(int *sock, const char *sun_name)
{
    return unix_socket_init_full(sock, sun_name, NULL, NULL);
}

ing_stat_t unix_socket_init_full(int *sock, const char *sun_name,
    struct sockaddr_un *saddr, int *saddr_size)
{
    int res;
    struct sockaddr_un addr = {0};

    /* create socket */
    int s = socket(AF_UNIX, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    if (s < 0)
    {
        ing_log(LOG_ERR," %s (%d):  Cannot create socket: %s\n", __func__, __LINE__, strerror(errno));
        return ING_STAT_GENERAL_ERROR;
    }
    *sock = s;

    /* assign address if specified */
    if (sun_name)
    {
        /* fill address structure */
        addr.sun_family = AF_UNIX;
        if (strlen(sun_name) == 0)
        {
            return ING_STAT_INVALID_ARGUMENT;
        }

        strcpy(addr.sun_path, sun_name);

        /* remove socket file if exists */
        unlink(addr.sun_path);

        /* assign address for the socket */
        res = bind(s, (struct sockaddr *)&addr, strlen(addr.sun_path) +
                                                       sizeof(addr.sun_family));
        if (res < 0)
        {
            ing_log(LOG_ERR," %s (%d):  Cannot bind socket: %s\n", __func__, __LINE__, strerror(errno));
            return ING_STAT_SYSTEM_ERROR;
        }

        if (saddr && saddr_size)
        {
            *saddr_size = strlen(addr.sun_path)+sizeof(addr.sun_family);
            memcpy(saddr, &addr, *saddr_size);
        }
    }

    return ING_STAT_OK;
}

ing_stat_t udp_socket_init(int *sock, in_addr_t addr, in_port_t port)
{
    struct sockaddr_in sock_addr = {0};

    /* create socket */
    int s = socket(PF_INET, SOCK_DGRAM | SOCK_CLOEXEC, IPPROTO_UDP);
    if (s < 0)
    {
        ing_log(LOG_ERR," %s (%d): Cannot create socket: %s\n", __func__, __LINE__, strerror(errno));
        return ING_STAT_SYSTEM_ERROR;
    }
    *sock = s;

    /* assign port if specified */
    if (port)
    {
        sock_addr.sin_family = AF_INET;                  /* Internet/IP */
        sock_addr.sin_addr.s_addr = htonl(addr);         /* IP address */
        sock_addr.sin_port = htons(port);                /* server port */

        /* Bind the socket */
        if (bind(s, (struct sockaddr *)&sock_addr, sizeof(sock_addr)) < 0)
        {
            ing_log(LOG_ERR," %s (%d):  Cannot bind socket: %s\n", __func__, __LINE__, strerror(errno));
            return ING_STAT_SYSTEM_ERROR;
        }
    }

    return ING_STAT_OK;
}

/*
 * Writes current time to buf in the following format:
 *  dd.MM hh:mm:ss
 */
static char *time2str(char *buf)
{
    time_t t = time(0);
    struct tm *lt = localtime(&t);
    sprintf(buf, "%02d.%02d %02d:%02d:%02d", (lt)->tm_mday,
                 (lt)->tm_mon+1, (lt)->tm_hour, (lt)->tm_min, (lt)->tm_sec);
    return buf;
}

static const char *priority2str(int priority)
{
    switch(priority)
    {
    case LOG_DEBUG: return "DEBUG";
    case LOG_INFO:  return "INFO ";
    case LOG_ERR:   return "ERROR";
    case LOG_CRIT:  return "CRIT ";
    };
    return "UNKNW";
}

static void vflog(FILE *file, int priority, char *msg, va_list arglist)
{
    char buf[64];
    time2str(buf);
    strcat(buf, " |");
    fputs(buf, file);
    sprintf(buf, "%s| ", priority2str(priority));
    fputs(buf, file);
    vfprintf(file, msg, arglist);
    fflush(file);
}

void ing_openlog(void)
{
#if USE_SYSLOG
    openlog("EP", LOG_CONS | LOG_PID | LOG_NDELAY, LOG_DAEMON);
#endif
}

void ing_closelog(void)
{
#if USE_SYSLOG
    closelog();
#endif
}

void ing_log(int priority, char *msg, ...)
{
    va_list arg;
    va_start(arg, msg);
#if USE_SYSLOG
    extern char *program_invocation_name;
    openlog(program_invocation_name, LOG_PID|LOG_NDELAY, LOG_DAEMON);
    vsyslog(priority, msg, arg);
#else
    vflog(stdout, priority, msg, arg);
#endif
    va_end(arg);
}

/* This message is written to cg_critical_err.log file regardless of log level
 * Only one message is stored, old ones will be rewritten
 */
void ing_log_critical(char *msg, ...)
{
    char buf[128];
    strcpy(buf, getenv("INANGOLOGPATH"));
    strcat(buf, "/cg_critical_err.log");
    FILE *f = fopen(buf, "w");
    if (f)
    {
        va_list arg;

        va_start(arg, msg);
        vflog(f, LOG_CRIT, msg, arg);
        va_end(arg);

#if USE_SYSLOG
        va_start(arg, msg);
        vsyslog(LOG_CRIT, msg, arg);
        va_end(arg);
#else
        va_start(arg, msg);
        vflog(stderr, LOG_CRIT, msg, arg);
        va_end(arg);
#endif
        fclose(f);
    }
}

inline char *strcat_safe(char *to, const char *from, size_t to_len)
{
	if ((to == NULL) || (from == NULL))
	    return NULL;
	 
    if (to_len - strlen(to) > strlen(from))
        return strcat(to, from);
    else
        return NULL;
}

inline char *strcpy_safe(char *to, const char *from, size_t to_len)
{
    if (to && from && to_len > strlen(from))
        return strcpy(to, from);
    else
        return NULL;
}

char *rstrstr(const char *s1, const char *s2)
{
    size_t s1len = strlen(s1);
    size_t s2len = strlen(s2);
    char *s;

    if (s2len > s1len)
        return NULL;

    for (s = (char *)s1 + s1len - s2len; s >= s1; s--)
        if (strncmp(s, s2, s2len) == 0)
            return s;

    return NULL;
}

char *trim(char *str)
{
    if (!str) return NULL;
    char *p;
    for (p = str; *p == ' ' || *p == '\t' || *p == '\n' ||  *p == '\r'; p++)
        ;
    memmove(str, p, strlen(p)+1);
    for (p = p + strlen(p) - 1; 
         p >= str && (*p == ' ' || *p == '\t' || *p == '\n' ||  *p == '\r' || *p == '\0');
         p--)
        *p = '\0';
    return str;
}

char *trim_quotes(char *str)
{
    if (!str) return NULL;
    char *p;
    for (p = str; *p == '\'' || *p == '"'; p++)
        ;
    memmove(str, p, strlen(p)+1);
    for (p = p + strlen(p) - 1; p >= str && (*p == '\'' || *p == '"' || *p == '\0'); p--)
        *p = '\0';
    return str;
}

int str_replace(char *str, size_t str_size, const char *placeholder, const char *replacement)
{
    if (!str || !placeholder || !replacement)
        return 1;
    char *p_ph = strstr(str, placeholder);
    if (!p_ph)
        return 2;
    size_t sv_len = strlen(replacement);
    if (strlen(str) - strlen(placeholder) + sv_len >= str_size)
        return 3;
    memmove(p_ph+sv_len, p_ph+strlen(placeholder), strlen(p_ph)-1);
    memmove(p_ph, replacement, sv_len);
    return 0;
}

char *str_toupper(char *str)
{
    if (!str) return NULL;
    char *p = str;
    while (*p != '\0')
    {
        *p = (char) toupper((unsigned char) *p);
        ++p;
    }

    return str;
}

char *str_tolower(char *str)
{
    if (!str) return NULL;
    char *p = str;
    while (*p != '\0')
    {
        *p = (char) tolower((unsigned char) *p);
        ++p;
    }

    return str;
}


/*
 * Gets system uptime in seconds
 */
long get_uptime()
{
    struct sysinfo s_info;
    
    if(sysinfo(&s_info) != 0)
    {
		ing_log(LOG_ERR," %s (%d): Couldn't get uptime: %s\n", __func__, __LINE__, strerror(errno));
        return 0;
    }
    return s_info.uptime;
}
