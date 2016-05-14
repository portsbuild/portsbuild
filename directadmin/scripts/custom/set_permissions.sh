#!/bin/sh

# Script to set the file ownerships and
# permissions of all DA related files on
# the system.  Should be quite useful
# for system restores, just make sure
# that the user accounts have already
# been created in the /etc/passwd,
# /etc/shadow, /etc/group files.

## 2016-05-12: PortsBuild version
## Todo:

OS=$(uname)
ECHO_LOG=1
SAVE_LOG=1
LOG=/tmp/set_perm.log
ERRLOG=/tmp/set_perm.err.log

DAPATH=/usr/local/directadmin
DIRECTADMIN=${DAPATH}/directadmin

DOVECOT=$(grep -c 'dovecot=1' ${DAPATH}/conf/directadmin.conf)
RT_GRP="wheel"

HAVE_HTTPD=1
HAVE_NGINX=0
if [ -s ${DIRECTADMIN} ]; then
  if [ "$(${DIRECTADMIN} c | grep ^nginx= | cut -d= -f2)" -eq 1 ]; then
    HAVE_HTTPD=0
    HAVE_NGINX=1
  fi
  if [ "$(${DIRECTADMIN} c | grep ^nginx_proxy= | cut -d= -f2)" -eq 1 ]; then
    HAVE_HTTPD=1
    HAVE_NGINX=1
  fi
fi

## Show Help
show_help() {
  echo ""
  echo "DirectAdmin File Permission/Ownership script"
  echo ""
  echo "Usage:"
  echo "  $0 all"
  echo ""
  echo "  $0 da_files" #don't forget /home/tmp
  echo "  $0 user_homes"
  echo "  $0 mysql"
  echo "  $0 email"
  echo "  $0 logs"
  echo "  $0 etc_configs"
  echo ""
  echo "internal:"
  echo "  $0 maildir <user> <path/Maildir>"
  echo "  $0 set_user_home <user>"
  echo "";
}

## Writes to log file
log() {
  if [ $SAVE_LOG -eq 1 ]; then
    echo "$1" >> $LOG
  fi
  if [ $ECHO_LOG -eq 1 ]; then
    echo "$1"
  fi
}

error_log(){
  echo "Error: $1"
  echo "$1" >> $ERRLOG
  log "$1"
}

###########
# set_file /file user group 755  -R
##########
set_file() {
  if [ -e "$1" ] || [ "$6" = "nocheck" ]; then
    log "set $1 $2:$3 $4 flag $5";

    #chown goes first.
    #A 4755 file is set to 755 if chown is called after chmod.

    chown $5 $2:$3 $1
    chmod $5 $4 $1
  fi
}

###########################################
# gets a list of the DA users on the system
all_users() {
  for i in `ls $DAPATH/data/users`; do
  {
    if [ -e $DAPATH/data/users/$i/user.conf ]; then
      printf "%s" "$i"
    fi
  };
  done
}

set_user_perm() {
  log "set_user_perm $1"
  DIR=$DAPATH/data/users/$1
  set_file $DIR diradmin diradmin 711
  set_file $DIR/bandwidth.tally root $RT_GRP 600
  set_file $DIR/ftp.passwd root ftp 640
  set_file $DIR/crontab.conf diradmin diradmin 600
  set_file $DIR/domains.list diradmin diradmin 600
  set_file $DIR/domains diradmin diradmin 711
  set_file $DIR/httpd.conf diradmin $1 640
  set_file $DIR/nginx.conf diradmin $1 640
  set_file $DIR/ticket.conf diradmin diradmin 600
  set_file $DIR/tickets.list diradmin diradmin 600
  set_file $DIR/user.conf diradmin diradmin 600
  set_file $DIR/user.usage diradmin diradmin 600
  set_file $DIR/user.history diradmin diradmin 600
  set_file $DIR/user.comments diradmin diradmin 600
  set_file $DIR/user_ip.list diradmin diradmin 600
  set_file $DIR/login.hist diradmin diradmin 600

  #hmm... do we want to rebuild the files?.. bit more than just "set permissions"

  for j in `cat $DIR/domains/*.conf | grep -e '^domain=' | cut -d= -f2`; do
  {
    COUNT=`cat $DIR/domains.list | grep -c $j`
    if [ $COUNT -eq 0 ]; then
      log "Found missing domain $j for user $1";
      echo $j >> $DIR/domains.list
    fi
  };
  done;

  set_file $DIR/domains diradmin diradmin 600 -R
  set_file $DIR/domains diradmin diradmin 711
}

set_reseller_perm() {
  log "set_reseller_perm $1";
  DIR=$DAPATH/data/users/$1
  set_file $DIR/ip.list diradmin diradmin 600
  set_file $DIR/packages diradmin diradmin 600 -R
  set_file $DIR/packages diradmin diradmin 700
  set_file $DIR/packages.list diradmin diradmin 600
  set_file $DIR/reseller.allocation diradmin diradmin 600
  set_file $DIR/reseller.conf diradmin diradmin 600
  set_file $DIR/reseller.usage diradmin diradmin 600
  set_file $DIR/reseller.history diradmin diradmin 600
  set_file $DIR/u_welcome.txt diradmin diradmin 600
  set_file $DIR/bandwidth.tally.cache diradmin diradmin 600

  set_file $DIR/users.list diradmin diradmin 600
  set_file $DIR/reseller.history diradmin diradmin 600
}

set_admin_perm() {
  log "set_admin_perm"
  DIR=$DAPATH/data/admin

  set_file $DIR diradmin diradmin 600 -R
  set_file $DIR diradmin diradmin 700
  set_file $DIR/ips diradmin diradmin 700
  set_file $DIR/packages diradmin diradmin 700
  set_file $DIR/task_queue_processes diradmin diradmin 700
}

da_files() {
  set_file /home/tmp root $RT_GRP 1777
  set_file $DAPATH diradmin diradmin 755
  set_file $DAPATH/conf diradmin diradmin 600 -R
  set_file $DAPATH/conf diradmin diradmin 700

  if [ -e $DAPATH/directadmin ]; then
      $DAPATH/directadmin p
  fi

  for i in `all_users`; do
  {
    set_user_perm $i

    if [ -e $DAPATH/data/users/$i/reseller.conf ]; then
        set_reseller_perm $i
    fi
  };
  done

  set_file $DAPATH/data/users diradmin diradmin 711

  set_admin_perm

  set_file $DAPATH/data/sessions diradmin diradmin 600 -R
  set_file $DAPATH/data/sessions diradmin diradmin 700

  set_file $DAPATH/data/tickets diradmin diradmin 700 -R
  #set_file "$DAPATH/data/tickets/*" diradmin diradmin 700
  #set_file "$DAPATH/data/tickets/*/*" diradmin diradmin 700
  set_file "$DAPATH/data/tickets/*/*/*" diradmin diradmin 600 '' nocheck
}

set_user_home() {
  log "set_user_home $1";
  UHOME=`grep -e "^${1}:" /etc/passwd | cut -d: -f6`

  if [ "$UHOME" = "" ]; then
    log "Home directory for $1 is empty. Check the /etc/passwd file, make sure the account exists"
    return
  fi

  set_file $UHOME $1 $1 711
  set_file $UHOME/domains $1 $1 711
  set_file "$UHOME/domains/*" $1 $1 711 '' nocheck
  set_file $UHOME/domains/default $1 $1 755
  set_file $UHOME/domains/sharedip $1 $1 755
  set_file $UHOME/domains/suspended $1 $1 755
  set_file $UHOME/backups $1 $1 700
  set_file "$UHOME/backups/*" $1 $1 600 '' nocheck
  set_file $UHOME/user_backups $1 $1 711
  set_file "$UHOME/user_backups/*" $1 $1 755 '' nocheck
  set_file $UHOME/imap $1 mail 770 -R
  set_file $UHOME/.spamassassin $1 mail 771
  set_file $UHOME/.spamassassin/spam $1 mail 660
  set_file $UHOME/.spamassassin/user_spam $1 mail 771
  set_file "$UHOME/.spamassassin/user_spam/*" mail $1 660

  # not sure how much else we should do.. the public_html and cgi-bins
  # should really be left untouched in case of any custom permission
  # like being owned by apache, or 777 etc.

  #reset for secure_access_group
  SAC=`grep -c secure_access_group /usr/local/directadmin/conf/directadmin.conf`
  if [ "$SAC" -gt 0 ]; then
    echo "action=rewrite&value=secure_access_group" >> /usr/local/directadmin/data/task.queue
  fi
}

user_homes() {
  log "user_homes"

  set_file /home root $RT_GRP 711

  for i in `all_users`; do
  {
    set_user_home $i
  };
  done
}

## PB: Todo: Verify:
do_mysql() {
  log "do_mysql"

  MDIR=/var/lib/mysql

  if [ -e /home/mysql ]; then
    MDIR=/home/mysql
  else
    MDIR=/usr/local/mysql/data
  fi


  for i in `ls $MDIR`; do
  {
    if [ -d $MDIR/$i ]; then
      set_file $MDIR/$i mysql mysql 700
      set_file "$MDIR/$i/*" mysql mysql 660 '' nocheck
    else
      set_file $MDIR/$i mysql mysql 600
    fi
  };
  done;

  set_file "${MDIR}*" mysql mysql 755 '' nocheck
}

get_domain_user() {
  if [ "$1" = "" ]; then
    error_log "get_domain_user: no domain passed"
    echo ""
    return
  fi

  USERN=`grep -e "^$1:" /etc/virtual/domainowners | cut -d\  -f2`
  if [ "$USERN" = "" ]; then
    error_log "can't find user for $1 in /etc/virtual/domainowners";
      echo "";
    return
  fi

  echo "$USERN";
}

set_maildir() {
  if [ "$2" = "" ]; then
      log "***Warning empty Maildir string***";
      return;
  fi

  if [ ! -e $2 ]; then
      log "cannot find $2 : skipping";
      return;
  fi

  user=$1;
  md=$2;

  set_file $md $user mail 770
  chown -R $user:mail $md

  OLD_EL=$ECHO_LOG
  ECHO_LOG=0

  for f in `ls -A $md`; do
  {
      file=$md/$f;

      if [ -d $file ]; then
          $0 maildir $user $file
      else
          set_file $file $user mail 660
      fi
  };
  done

  ECHO_LOG=$OLD_EL
}

set_dovecot_domain()
{
    log "set_dovecot_domain $1 $2 $3";

    user=$1
    domain=$2
    uhome=$3

    set_file $uhome/imap/$domain $user mail 770

    for e in `ls $uhome/imap/$domain`; do
    {
        p=$uhome/imap/$domain/$e
        set_file $p $user mail 770
        if [ -e $p/Maildir ]; then
            $0 maildir $user $p/Maildir
        fi
    };
    done;
}

set_dovecot()
{
    log "dovecot";

    for i in `all_users`; do
    {

        uhome=`grep -e "^${i}:" /etc/passwd | cut -d: -f6`

        if [ "$uhome" = "" ]; then
            continue;
        fi

        $0 maildir $i $uhome/Maildir
        set_file $uhome/imap $i mail 770

        for d in `cat $DAPATH/data/users/$i/domains.list`; do
        {
            set_dovecot_domain $i $d $uhome
        };
        done;
    };
    done;
}

email()
{
    log "email";

    VDIR=/etc/virtual
    HN=`hostname`

    set_file $VDIR mail mail 755

    set_file $VDIR/domainowners mail mail 640
    set_file $VDIR/domains mail mail 640
    set_file $VDIR/pophosts mail mail 600
    set_file $VDIR/pophosts_user mail mail 600
    set_file $VDIR/majordomo majordomo daemon 750

    set_file $VDIR/bad_sender_hosts mail mail 600
    set_file $VDIR/bad_sender_hosts_ip mail mail 600
    set_file $VDIR/blacklist_domains mail mail 600
    set_file $VDIR/blacklist_senders mail mail 600
    set_file $VDIR/whitelist_domains mail mail 600
    set_file $VDIR/whitelist_hosts mail mail 600
    set_file $VDIR/whitelist_hosts_ip mail mail 600
    set_file $VDIR/whitelist_senders mail mail 600
    set_file $VDIR/use_rbl_domains mail mail 600
    set_file $VDIR/skip_av_domains mail mail 600
    set_file $VDIR/skip_rbl_domains mail mail 600

    for i in `ls $VDIR`; do
    {
        if [ "$i" = "majordomo" ]; then
            continue;
        fi
        if [ "$i" = "usage" ]; then
            continue;
        fi
        if [ "$i" = "$HN" ]; then
            continue;
        fi


        if [ -d $VDIR/$i ]; then

                    USERN=`get_domain_user $i`;
                    if [ "$USERN" = "" ]; then
                            USERN="mail";
                    fi

            set_file $VDIR/$i mail mail 711
            DDIR=$VDIR/$i
            set_file $DDIR/aliases mail mail 600
            set_file $DDIR/filter mail mail 640
            set_file $DDIR/filter.conf mail mail 600
            set_file $DDIR/passwd mail mail 600
            set_file $DDIR/quota mail mail 600

            set_file $DDIR/dkim.private.key mail mail 600
            set_file $DDIR/dkim.public.key mail mail 600
            set_file $DDIR/dovecot.bytes mail mail 600

            set_file $DDIR/vacation.conf mail mail 600
            set_file $DDIR/autoresponder.conf mail mail 600
            set_file $DDIR/reply mail mail 700
            set_file "$DDIR/reply/*" mail mail 600 '' nocheck
            set_file $DDIR/majordomo majordomo daemon 751
            set_file $DDIR/majordomo/majordomo.cf majordomo daemon 640
            set_file $DDIR/majordomo/list.aliases majordomo mail 640
            set_file $DDIR/majordomo/private.aliases majordomo mail 640
            set_file $DDIR/majordomo/archive majordomo daemon 751
            set_file $DDIR/majordomo/digests majordomo daemon 751
            set_file $DDIR/majordomo/lists majordomo daemon 751
            chown -R majordomo:daemon $DDIR/majordomo/lists

        fi
    };
    done;

    if  [ "$DOVECOT" -eq 0 ]; then
        VSV=/var/spool/virtual
        set_file $VSV mail mail 1777

        for i in `ls $VSV`; do
        {
            USERN=`get_domain_user $i`;
            if [ "$USERN" = "" ]; then
                continue;
            fi

            set_file $VSV/$i $USERN mail 770
            set_file "$VSV/$i/*" $USERN mail 660 '' nocheck
        };
        done;

        SPOOLM=/var/spool/mail
        if [ "$OS" = "FreeBSD" ]; then
            SPOOLM=/var/mail
        fi

        set_file $SPOOLM mail mail 1777

        for i in `ls $SPOOLM`; do
        {
            set_file $SPOOLM/$i $i mail 660
        };
        done;
    fi

    set_file /var/spool/exim mail mail 750
    set_file "/var/spool/exim/*" mail mail 750 '' nocheck
    #set_file "/var/spool/exim/*/*" mail mail 640 '' nocheck
    chown -R mail:mail /var/spool/exim

    set_file /etc/exim.cert mail mail 644
    set_file /etc/exim.key mail mail 600

    if [ "$DOVECOT" -eq 1 ]; then
        set_dovecot;
    fi

    mkdir -p /var/log/exim
    set_file /var/log/exim mail mail 640 -R
    set_file /var/log/exim mail mail 750

    set_file /usr/sbin/exim root $RT_GRP 4755
}

logs()
{
    log "logs";

    VL=/var/log

    if [ ! -e $VL/directadmin ]; then
        error_log "$VL/directadmin didn't exists, creating it.";
        mkdir -p $VL/directadmin
    fi

    set_file $VL/directadmin diradmin diradmin 700
    set_file "$VL/directadmin/*" diradmin diradmin 600 '' nocheck


    mkdir -p $VL/exim
    set_file $VL/exim mail mail 755
    set_file "$VL/exim/*" mail mail 644 '' nocheck

    mkdir -p $VL/proftpd
    set_file $VL/proftpd root $RT_GRP 755
    set_file "$VL/proftpd/*" root $RT_GRP 644 '' nocheck

    if [ "${HAVE_HTTPD}" -eq 1 ]; then
        #http.. well it's all root, permissions don't really matter
        mkdir -p /var/log/httpd/domains
        chmod 710 /var/log/httpd
            chmod 710 /var/log/httpd/domains
            chown root:nobody /var/log/httpd/domains
    fi
    if [ "${HAVE_NGINX}" -eq 1 ]; then
        mkdir -p /var/log/nginx/domains
        chmod 710 /var/log/nginx
        chmod 710 /var/log/nginx/domains
        chown root:nobody /var/log/httpd/domains
    fi
}

etc_configs()
{
    log "etc_configs";

    set_file "/etc/exim.*" root $RT_GRP 755 '' nocheck
    set_file /etc/system_filter.exim root $RT_GRP 755

    set_file /etc/proftpd.conf root $RT_GRP 644
    set_file /etc/proftpd.vhosts.conf root $RT_GRP 644
    set_file /etc/proftpd.passwd root ftp 640

    #httpd.. again, all root.. nothing special about it.
}

all()
{
    da_files;
    user_homes;
    do_mysql;
    email;
    logs;
    etc_configs;
}

if [ "$1" != "maildir" ]; then
    log "***********************************************";
    log "`date` : $0 $1";
fi

case "$1" in
    all) all;
        ;;

    da_files) da_files;
        ;;

    user_homes) user_homes;
        ;;

    set_user_home) set_user_home $2
        ;;

    mysql) do_mysql;
        ;;

    email) email;
        ;;

    logs) logs;
        ;;

    etc_configs) etc_configs;
        ;;

    maildir) set_maildir $2 $3;
        ;;

    *) show_help;
        ;;

esac

exit 0;
