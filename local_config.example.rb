# File to store info that changes depending on where you deploy the code
#

# Whether we're testing or not.  If true, we won't generate the blog
# post at the end, just output what it would've been
TESTING = true

# Date that your company was founded
FOUNDING_DATE = Date.civil(2011, 6, 10)

# Location of the log file where the conversation on your IRC channel is
# logged.  At present assumes the log output from rbot, which is of the form
# [YYYY/MM/DD HH:MM:SS] <username> content
IRC_LOGFILE = "/path/to/my/irc.log"

# Location of the blog XML-RPC endpoint
BLOG_SERVER = "mydomain.com"
BLOG_XMLRPC_ENDPOINT = "/xmlrpc.php"
BLOG_USERNAME = "myuser"
BLOG_PASSWORD = "secret_password"

