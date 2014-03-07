# OpenShift Users Read This!
#
# This vcl is designed for Drupal users on OpenShift, there are two variables
#   you need to fill out on line 13 and line 26.  Both of these variables
#   should be the DNS name of the application you are looking to accelerate.
#   For example, if your drupal app is "drupal-mydomain.rhcloud.com", that is
#   what you would put in these sections


backend drupalsite {
# Example:
# .host = "drupal-mydomain.rhcloud.com";

.host = "$REPLACE_ME.rhcloud.com";
.port = "80";
.connect_timeout = 600s;
.first_byte_timeout = 600s;
.between_bytes_timeout = 600s;
.max_connections = 800;
}

sub vcl_recv {
  set req.backend = drupalsite;
  # Example: 
  #set req.http.Host = "drupal-domain.rhcloud.com";

  set req.http.Host = "$REPLACE_ME.rhcloud.com";

  # Get rid of progress.js query params 
  if (req.url ~ "^/misc/progress\.js\?[0-9]+$") { 
    set req.url = "/misc/progress.js";
  } 

  # Pipe these paths directly to Apache for streaming.
  if (req.url ~ "^/admin/content/backup_migrate/export") { 
    return (pipe);
 } 

# If global redirect is on
# if (req.url ~ "node\?page=[0-9]+$") {
#  set req.url = regsub(req.url, "node(\?page=[0-9]+$)", "\1");
#  return (lookup);
# }

# Do not cache these paths.
  if (req.url ~ "^/status\.php$" ||
      req.url ~ "^/update\.php" ||
      req.url ~ "^/install\.php" ||
      req.url ~ "^/admin" ||
      req.url ~ "^/admin/.*$" || 
      req.url ~ "^/user" ||
      req.url ~ "^/user/.*$" || 
      req.url ~ "^/users/.*$" ||
      req.url ~ "^/info/.*$" ||
      req.url ~ "^/flag/.*$" ||
      req.url ~ "^.*/ajax/.*$" || 
      req.url ~ "^.*/ahah/.*$") {
      return (pass);
  } 

  # Do not allow outside access to cron.php or install.php 
  #if (req.url ~ "^/(cron|install)\.php$" && !client.ip ~ internal) {
    # Have Varnish throw the error directly. 
 #   error 404 "Page not found.";
    # Use a custom error page that you've defined in Drupal at the path "404". 
    # set req.url = "/404"; 
  #} 

  # Always cache the following file types for all users.
  if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js|html|htm)(\?[a-z0-9]+)?$") {
    unset req.http.Cookie;
  }

  # Remove all cookies that Drupal doesn't need to know about. ANY remaining
  # cookie will cause the request to pass-through to Apache. For the most part
  # we always set the NO_CACHE cookie after any POST request, disabling the
  # Varnish cache temporarily. The session cookie allows all authenticated users
  # to pass through as long as they're logged in.
  ## See: http://drupal.stackexchange.com/questions/53467/varnish-problem-user-log...  # 1. Append a semi-colon to the front of the cookie string.
  # 2. Remove all spaces that appear after semi-colons.
  # 3. Match the cookies we want to keep, adding the space we removed
  # previously, back. (\1) is first matching group in the regsuball.
  # 4. Remove all other cookies, identifying them by the fact that they have
  # no space after the preceding semi-colon.
  # 5. Remove all spaces and semi-colons from the beginning and end of the
  # cookie string.
  if (req.http.Cookie) {
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
    set req.http.Cookie = regsuball(req.http.Cookie, ";(S{1,2}ESS[a-z0-9]+|NO_CACHE)=", "; \1=");
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

    if (req.http.Cookie == "") {
      # If there are no remaining cookies, remove the cookie header. If there
      # aren't any cookie headers, Varnish's default behavior will be to cache
      # the page.
      unset req.http.Cookie;
    }
    else {
      # If there is any cookies left (a session or NO_CACHE cookie), do not
      # cache the page. Pass it on to Apache directly.
      return (pass);
    }
  }

    # Remove the "has_js" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");

    # Remove the "Drupal.toolbar.collapsed" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "Drupal.toolbar.collapsed=[^;]+(; )?", "");

    # Remove any Google Analytics based cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");

    # Remove the Quant Capital cookies (added by some plugin, all __qca)
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");

    # Are there cookies left with only spaces or that are empty?
    if (req.http.cookie ~ "^ *$") {
        unset req.http.cookie;
    }

    # Cache static content unique to the theme (so no user uploaded images)
    if (req.url ~ "^/themes/" && req.url ~ ".(css|js|png|gif|jp(e)?g)") {
        unset req.http.cookie;
    }
}
