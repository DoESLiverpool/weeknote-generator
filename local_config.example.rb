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

# URL for the events calendar iCal feed
CAL_URL = "https://www.example.com/calendar/ical/basic.ics"
# If your calendar uses HTTPS rather than HTTP, set this to true
CAL_URL_IS_HTTPS = true

# URL for the issue list
# NB: This is likely only to work with Github
ISSUE_URL = "https://api.github.com/repos/mygithubuser/my-issues-repo/issues"
# If your issue list uses HTTPS rather than HTTP, set this to true
ISSUE_URL_IS_HTTPS = true

# Mail server details
MAIL_SERVER = 'smtp.mydomain.com'
MAIL_PORT = 587
MAIL_DOMAIN = 'mydomain.com'
MAIL_USER = 'my email username'
MAIL_PASS = 'secret password'
MAIL_AUTHTYPE = :login
MAIL_FROM_ADDRESS = "myemail@mydomain.com"
MAIL_LONG_FROM_ADDRESS = "My Name <myemail@mydomain.com>"
MAIL_NOTIFY_ADDRESS = "whotoinform@mydomain.com"
MAIL_LONG_NOTIFY_ADDRESS = "Person To Inform <whotoinform@mydomain.com>"


