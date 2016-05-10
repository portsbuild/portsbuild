#1.10
Easy Spam Fighter
Credit to http://olicomber.co.uk/blog/b/Easy,_reliable_spam_fighting_with_Exim

this version has been modified for use with a DirectAdmin System.
It requires a minimum of exim.conf 4.2.4 and exim.pl 19

It also requires exim be compiled with EXPERIMENTAL_SPF, which can be confirmed with:
exim -bV | grep ^SPF

CustomBuild 2.0 has been updated to add this to the Makefile at compile time if easy_spam_fighter=yes is set in the options.conf:
http://help.directadmin.com/item.php?id=125

====================================
Installation:

cd /etc
wget -O exim.easy_spam_fighter.tar.gz http://files1.directadmin.com/services/exim.easy_spam_fighter.tar.gz
tar xvzf exim.easy_spam_fighter.tar.gz

and ensure you have
/etc/exim.conf 4.2.4+
/etc/exim.pl 19+
Experimental_SPF in exim -bV Support

====================================
About:

The Easy Spam Fighter (simplied wording from "Easy, Reliable, Spam Fighting, with Exim")
is a set of exim ACLs that do various checks, and any check that returns a result (possible spam)
it then increases the score (saved and incremented in $acl_m_easy69)
At the end of the DATA ACL, if the score is below the limit, run a basic smtp-time SpamAssassin call
and add the "int_score to acl_m_easy69. (eg: 2.7 has int score of 27)
If already above the limit, don't bother running SpamAssassin, as it will be spam already.
This last skip will save CPU processing.

After all that, if the score is above a threshold, the message is rejected, at SMTP-time, and it never enters your queue.
If it's below the threshold, multiple headers are added to explain each score.

====================================
Files:

-- variables.conf

If you want to customize the file, create your own file:
-- variables.conf.custom, and set only the values in this file as desired, and they'll override the defaults.
EASY_LIMIT = 55			- max score before an email is considered spam before SA is rung (main purpose is just to decide if SpamAssassin run is needed)
EASY_IS_SPAM = 20		- this is a nudge score. If SpamAssass determines it's spam (based on the User threshold), this extra score is added, on top of the spam_score_int
EASY_HIGH_SCORE_DROP = 100	- very high scoring spam is dropped at this score, and not allowed to enter.
EASY_SPF_PASS = -30		- If the SPF passes, the score drops by this amount
EASY_SPF_SOFT_FAIL = 30		- If the SPF hits a softfail from ~all, this score is added.
EASY_DKIM_PASS = -20		- If the DKIM Passes, the score drops by this amount
EASY_DKIM_FAIL = 100		- If the DKIM Fails, the score is added.
EASY_NO_REVERSE_IP = 100	- Sender IP must have a reverse IP lookup, or this score is added.
EASY_FORWARD_CONFIRMED_RDNS = -10 	- Sender IP has reverse IP PLUS forward A lookup back to the same IP, so we subtract 10.
EASY_DNS_BLACKLIST = 50		- IP that is in a dns black list (RBL) gets this score
EASY_SPAMASSASSIN_MAX_SIZE = 200K	- max size that SpamAssassin will scan.
EASY_SKIP_SENDERS = /etc/virtual/esf_skip_senders		- file to hold MAIL FROM addresses that ESF should skip checks for.
EASY_SKIP_RECIPIENTS = /etc/virtual/esf_skip_recipients		- file to hold RCPT TO addresses that ESF should skip checks for.
EASY_SKIP_HOSTS = /etc/virtual/esf_skip_hosts			- file to hold hostlist that ESF should skip checks for.

-- check_mail.conf
Does the MX dns checks, SPF record checks, and reverse IP check.

-- check_rcpt.conf
Check on the RBLs and add score

-- check_message.conf
will run SpamAssassin if the score is low enough, but above that score, it doesn't bother.
If run, the int spam score is added.
After, the message is decided if it should be dropped.

-- /etc/virtual/esf_skip_senders
file to hold MAIL FROM addresses that ESF should skip checks for.
Uses wildlsearch, so can use *
Does not have to exist

-- /etc/virtual/esf_skip_recipients
file to hold RCPT TO addresses that ESF should skip checks for the final score.
Note: the RCPT TO command is not done until *after* SPF checks have already happened, so this file will not be able to skip SPF checks, or anything else that happens before RCPT TO.
Uses wildlsearch, so can use *
Does not have to exist

-- /etc/virtual/esf_skip_recipients
file to hold hostlist that ESF should skip checks for.
This file is checked at the MAIL FROM step (just after esf_skip_senders)
Uses wildlsearch, so can use *
Does not have to exist
