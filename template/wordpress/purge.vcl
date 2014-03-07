# purge.vcl -- Cache Purge Library for Varnish
#
# Copyright (C) 2013 DreamHost (New Dream Network, LLC)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# There are 3 possible behaviors of purging.

# Regex purging
# Treat the request URL as a regular expression.
sub purge_regex {
	ban("obj.http.X-Req-URL ~ " + req.url + " && obj.http.X-Req-Host == " + req.http.host);
}

# Exact purging
# Use the exact request URL (including any query params)
sub purge_exact {
	ban("obj.http.X-Req-URL == " + req.url + " && obj.http.X-Req-Host == " + req.http.host);
}

# Page purging (default)
# Use the exact request URL, but ignore any query params
sub purge_page {
	set req.url = regsub(req.url, "\?.*$", "");
	ban("obj.http.X-Req-URL-Base == " + req.url + " && obj.http.X-Req-Host == " + req.http.host);
}


# The purge behavior can be controlled with the X-Purge-Method header.
#
# Setting the X-Purge-Method header to contain "regex" or "exact" will use
# those respective behaviors.  Any other value for the X-Purge header will
# use the default ("page") behavior.
#
# The X-Purge-Method header is not case-sensitive.
#
# If no X-Purge-Method header is set, the request url is inspected to attempt
# a best guess as to what purge behavior is expected.  This should work for
# most cases, although if you want to guarantee some behavior you should
# always set the X-Purge-Method header.
C{
#include <netinet/in.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
}C

sub vcl_recv {

	C{
	struct sockaddr_storage *client_ip_ss = VRT_r_client_ip(sp);
	struct sockaddr_in *client_ip_si = (struct sockaddr_in *) client_ip_ss;
	struct in_addr *client_ip_ia = &(client_ip_si->sin_addr);
	char *xff_ip = VRT_GetHdr(sp, HDR_REQ, "\020X-Forwarded-For:");

	if (xff_ip != NULL) {
	// Copy the ip address into the struct's sin_addr.
	inet_pton(AF_INET, xff_ip, client_ip_ia);
	}
	}C



	if (req.request == "PURGE") {
		if (client.ip !~ purge) {
			error 405 "Not allowed.";
		}

		if (req.http.X-Purge-Method) {
			if (req.http.X-Purge-Method ~ "(?i)regex") {
				call purge_regex;
			} elsif (req.http.X-Purge-Method ~ "(?i)exact") {
				call purge_exact;
			} else {
				call purge_page;
			}
		} else {
			# No X-Purge-Method header was specified.
			# Do our best to figure out which one they want.
			if (req.url ~ "\.\*" || req.url ~ "^\^" || req.url ~ "\$$" || req.url ~ "\\[.?*+^$|()]") {
				call purge_regex;
			} elsif (req.url ~ "\?") {
				call purge_exact;
			} else {
				call purge_page;
			}
		}

		error 200 "Purged.";
	}
}

sub vcl_fetch {
	set beresp.http.X-Req-Host = req.http.host;
	set beresp.http.X-Req-URL = req.url;
	set beresp.http.X-Req-URL-Base = regsub(req.url, "\?.*$", "");
}

sub vcl_deliver {
	unset resp.http.X-Req-Host;
	unset resp.http.X-Req-URL;
	unset resp.http.X-Req-URL-Base;
}
