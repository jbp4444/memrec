/*
 * Copyright (c) 2003 Sun Microsystems, Inc.  All Rights Reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * Redistribution of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * 
 * Redistribution in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 
 * Neither the name of Sun Microsystems, Inc. or the names of
 * contributors may be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * 
 * This software is provided "AS IS," without a warranty of any kind.
 * ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES,
 * INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED.
 * SUN MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE
 * FOR ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING
 * OR DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES.  IN NO EVENT WILL
 * SUN OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA,
 * OR FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR
 * PUNITIVE DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF
 * LIABILITY, ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE,
 * EVEN IF SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
 * 
 * You acknowledge that this software is not designed or intended for use
 * in the design, construction, operation or maintenance of any nuclear
 * facility.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include <ipmitool/ipmi.h>
#include <ipmitool/ipmi_intf.h>

#include <freeipmi/freeipmi.h>
#include <freeipmi/udm/ipmi-udm.h>

#include <config.h>

ipmi_device_t dev = NULL;

extern int verbose;

static int ipmi_free_open(struct ipmi_intf * intf)
{
        if (getuid() != 0) {
                fprintf(stderr, "Permission denied, must be root\n");
                return -1;
        }

        if (!(dev = ipmi_open_inband (IPMI_DEVICE_KCS,
                                      0,
                                      0,
                                      0,
                                      NULL,
                                      IPMI_FLAGS_DEFAULT))) {
                if (!(dev = ipmi_open_inband (IPMI_DEVICE_SSIF,
                                              0,
                                              0,
                                              0,
                                              NULL,
                                              IPMI_FLAGS_DEFAULT))) {
                        perror("ipmi_open_inband()");
                        goto cleanup;
                }
        }

	intf->opened = 1;
	return 0;
 cleanup:
        if (dev)
                ipmi_close_device(dev);
        return -1;
}

static void ipmi_free_close(struct ipmi_intf * intf)
{
        if (dev)
                ipmi_close_device(dev);
	intf->opened = 0;
}

static struct ipmi_rs * ipmi_free_send_cmd(struct ipmi_intf * intf, struct ipmi_rq * req)
{
        u_int8_t lun = 0;
        u_int8_t cmd = req->msg.cmd;
        u_int8_t netfn = req->msg.netfn;
        u_int8_t rq_buf[IPMI_BUF_SIZE];
        u_int8_t rs_buf[IPMI_BUF_SIZE];
        u_int32_t rs_buf_len = IPMI_BUF_SIZE;
        int32_t rs_len;

	static struct ipmi_rs rsp;	

        /* achu: FreeIPMI requests have the cmd as the first byte of
         * the data.  Responses have cmd as the first byte and
         * completion code as the second byte.  This differs from some
         * other APIs, so it must be compensated for within the ipmitool
         * interface.
         */

	if (!intf || !req)
		return NULL;

	if (!intf->opened && intf->open && intf->open(intf) < 0)
		return NULL;

        if (req->msg.data_len > IPMI_BUF_SIZE)
                return NULL;

        memset(rq_buf, '\0', IPMI_BUF_SIZE);
        memset(rs_buf, '\0', IPMI_BUF_SIZE);
        memcpy(rq_buf, &cmd, 1);

        if (req->msg.data)
               memcpy(rq_buf + 1, req->msg.data, req->msg.data_len);

        if ((rs_len = ipmi_cmd_raw(dev,
                                   lun, 
                                   netfn,                    
                                   rq_buf, 
                                   req->msg.data_len + 1,
                                   rs_buf, 
                                   rs_buf_len)) < 0) {
                perror("ipmi_cmd_raw");
                return NULL;
        }

        memset(&rsp, 0, sizeof(struct ipmi_rs));
	rsp.ccode = (unsigned char)rs_buf[1];
	rsp.data_len = (int)rs_len - 2;

	if (!rsp.ccode && rsp.data_len)
		memcpy(rsp.data, rs_buf + 2, rsp.data_len);

	return &rsp;
}

struct ipmi_intf ipmi_free_intf = {
	name:		"free",
	desc:		"FreeIPMI IPMI Interface",
	open:		ipmi_free_open,
	close:		ipmi_free_close,
	sendrecv:	ipmi_free_send_cmd,
	target_addr:	IPMI_BMC_SLAVE_ADDR,
};

