#!/bin/sh
#
## roundcube.sh

# Roundcube port installed in: /usr/local/www/RoundCube
# DA expecting it in /var/www/html/roundcube

doroundcube() {

  ensure_webapps_logrotate

  #initMySQL

  cd "${CWD}" || exit

  REALPATH=/usr/local/www/roundcube

  ALIASPATH=${WWW_DIR}/roundcube

  HTTPPATH=${WEBPATH_SERVICES}/all/roundcube

  # Variables for the database:
  ROUNDCUBE_DB=da_roundcube
  ROUNDCUBE_DB_USER=da_roundcube
  ROUNDCUBE_DB_PASS=$(random_pass)
  ROUNDCUBE_DES_KEY=$(random_pass 24)
  ROUNDCUBE_MY_CNF=${REALPATH}/config/my.cnf

  if [ -e "${ALIASPATH}" ]; then
    if [ -d "${ALIASPATH}/logs" ]; then
      cp -fR "${ALIASPATH}/logs" ${REALPATH} >/dev/null 2>&1
    fi
    if [ -d "${ALIASPATH}/temp" ]; then
      cp -fR "${ALIASPATH}/temp" ${REALPATH} >/dev/null 2>&1
    fi
  fi

  # link it from a fake path:
  /bin/rm -f "${ALIASPATH}"
  /bin/ln -sf "roundcubemail-${ROUNDCUBE_VER}" "${ALIASPATH}"

  chown -h "${APPUSER}:${APPUSER}" "${ALIASPATH}"
  cd ${REALPATH} || exit

  if [ "${ROUNDCUBE_MAJOR_VER}" -eq 0 ]; then
    EDIT_CONFIG=main.inc.php
    CONFIG_DIST=main.inc.php.dist
    EDIT_DB=db.inc.php
    DB_DIST=db.inc.php.dist
  else
    EDIT_CONFIG=config.inc.php
    CONFIG_DIST=config.inc.php.sample
    EDIT_DB=${EDIT_CONFIG}
    DB_DIST=${CONFIG_DIST}
  fi

  MYSQLSHOW=/usr/local/bin/mysqlshow

  # Insert data to mysql and create database/user for roundcube:
  if ! ${MYSQLSHOW} --defaults-extra-file=/usr/local/directadmin/conf/my.cnf | grep -m1 -q ' da_roundcube '; then
    if [ -d SQL ]; then
      echo "Inserting data to mysql and creating database/user for roundcube..."
      mysql --defaults-extra-file="${DA_MY_CNF}" -e "CREATE DATABASE ${ROUNDCUBE_DB};" --host="${MYSQLHOST}" 2>&1
      mysql --defaults-extra-file="${DA_MY_CNF}" -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host="${MYSQLHOST}" 2>&1

      rm -f ${ROUNDCUBE_MY_CNF}
      ensure_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"
      mysql --defaults-extra-file=${ROUNDCUBE_MY_CNF} -e "use ${ROUNDCUBE_DB}; source SQL/mysql.initial.sql;" --host="${MYSQLHOST}" 2>&1

      echo "Database created, ${ROUNDCUBE_DB_USER} password is ${ROUNDCUBE_DB_PASS}"
    else
      echo "Cannot find SQL directory in roundcubemail-${ROUNDCUBE_VER}"
      do_exit 0
    fi
  else
    if [ -e "${ROUNDCUBE_CONFIG_DB}" ]; then
      COUNT_MYSQL=$(grep -m1 -c 'mysql://' "${ROUNDCUBE_CONFIG_DB}")
      if [ "${COUNT_MYSQL}" -gt 0 ]; then
        PART1=$(grep -m1 "\$config\['db_dsnw'\]" "${ROUNDCUBE_CONFIG_DB}" | awk '{print $3}' | cut -d\@ -f1 | cut -d'/' -f3)
        ROUNDCUBE_DB_USER=$(echo "${PART1}" | cut -d\: -f1)
        ROUNDCUBE_DB_PASS=$(echo "${PART1}" | cut -d\: -f2)
        PART2=$(grep -m1 "\$config\['db_dsnw'\]" "${ROUNDCUBE_CONFIG_DB}" | awk '{print $3}' | cut -d\@ -f2 | cut -d\' -f1)
        MYSQL_ACCESS_HOST=$(echo "${PART2}" | cut -d'/' -f1)
        ROUNDCUBE_DB=$(echo "${PART2}" | cut -d'/' -f2)
      fi
    fi

    mysql --defaults-extra-file="${DA_MY_CNF}" -e "SET PASSWORD FOR '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' = PASSWORD('${ROUNDCUBE_DB_PASS}');" --host="${MYSQLHOST}" 2>&1
    mysql --defaults-extra-file="${DA_MY_CNF}" -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,LOCK TABLES,INDEX ON ${ROUNDCUBE_DB}.* TO '${ROUNDCUBE_DB_USER}'@'${MYSQL_ACCESS_HOST}' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';" --host="${MYSQLHOST}" 2>&1

    #in case anyone uses it for backups
    rm -f ${ROUNDCUBE_MY_CNF}
    ensure_my_cnf ${ROUNDCUBE_MY_CNF} "${ROUNDCUBE_DB_USER}" "${ROUNDCUBE_DB_PASS}"
  fi

  #Cleanup config
  rm -f ${REALPATH}/config/${EDIT_CONFIG}

  #install the proper config:
  if [ -d ../roundcube ]; then

    echo "Editing roundcube configuration..."
    cd ${REALPATH}/config || exit

    if [ -e "${ROUNDCUBE_CONFIG}" ]; then
      echo "Installing custom RoundCube Config: ${ROUNDCUBE_CONFIG}"
      cp -f "${ROUNDCUBE_CONFIG}" ${EDIT_CONFIG}
    fi

    if [ -e "${ROUNDCUBE_CONFIG_DB}" ]; then
      if [ ! -e ${EDIT_DB} ]; then
        /bin/cp -f "${ROUNDCUBE_CONFIG_DB}" ${EDIT_DB}
      fi
      if [ "${COUNT_MYSQL}" -eq 0 ]; then
        echo "\$config['db_dsnw'] = 'mysql://${ROUNDCUBE_DB_USER}:${ROUNDCUBE_DB_PASS}@${MYSQLHOST}/${ROUNDCUBE_DB}';" >> ${EDIT_DB}
      fi
    else
      if [ ! -e ${EDIT_DB} ]; then
        /bin/cp -f ${DB_DIST} ${EDIT_DB}
        /usr/local/bin/perl -pi -e "s|mysql://roundcube:pass\@localhost/roundcubemail|mysql://${ROUNDCUBE_DB_USER}:\\Q${ROUNDCUBE_DB_PASS}\\E\@${MYSQLHOST}/${ROUNDCUBE_DB}|" ${EDIT_DB} > /dev/null
        /usr/local/bin/perl -pi -e "s/\'mdb2\'/\'db\'/" ${EDIT_DB} > /dev/null
      fi
    fi

    SPAM_INBOX_PREFIX_OPT=$(getDA_Opt spam_inbox_prefix 1)
    SPAM_FOLDER="INBOX.spam"
    if [ "${SPAM_INBOX_PREFIX_OPT}" = "0" ]; then
      SPAM_FOLDER="Junk"
    fi

    /usr/local/bin/perl -pi -e "s|rcmail-\!24ByteDESkey\*Str|\\Q${ROUNDCUBE_DES_KEY}\\E|" ${EDIT_CONFIG}
    if [ ! -e "${ROUNDCUBE_CONFIG}" ]; then
      if [ "${ROUNDCUBE_MAJOR_VER}" -eq 0 ]; then
        /usr/local/bin/perl -pi -e "s|\['default_host'] = ''|\['default_host'] = 'localhost'|" ${EDIT_CONFIG} > /dev/null

        #IMAP folders
        if [ "${WEBAPPS_INBOX_PREFIX_OPT}" = "yes" ]; then
          /usr/local/bin/perl -pi -e "s|\['drafts_mbox'] = 'Drafts'|\['drafts_mbox'] = 'INBOX.Drafts'|" ${EDIT_CONFIG} > /dev/null
          /usr/local/bin/perl -pi -e "s|\['sent_mbox'] = 'Sent'|\['sent_mbox'] = 'INBOX.Sent'|" ${EDIT_CONFIG} > /dev/null
          /usr/local/bin/perl -pi -e "s|\['trash_mbox'] = 'Trash'|\['trash_mbox'] = 'INBOX.Trash'|" ${EDIT_CONFIG} > /dev/null
          /usr/local/bin/perl -pi -e "s|\['default_imap_folders'] = array\('INBOX', 'Drafts', 'Sent', 'Junk', 'Trash'\)|\['default_imap_folders'] = array\('INBOX', 'INBOX.Drafts', 'INBOX.Sent', '${SPAM_FOLDER}', 'INBOX.Trash'\)|" ${EDIT_CONFIG} > /dev/null
          /usr/local/bin/perl -pi -e "s|\['default_folders'] = array\('INBOX', 'Drafts', 'Sent', 'Junk', 'Trash'\)|\['default_folders'] = array\('INBOX', 'INBOX.Drafts', 'INBOX.Sent', '${SPAM_FOLDER}', 'INBOX.Trash'\)|" ${EDIT_CONFIG} > /dev/null
        else
          /usr/local/bin/perl -pi -e "s|\['default_imap_folders'] = array\('INBOX', 'Drafts', 'Sent', 'Junk', 'Trash'\)|\['default_imap_folders'] = array\('INBOX', 'Drafts', 'Sent', '${SPAM_FOLDER}', 'Trash'\)|" ${EDIT_CONFIG} > /dev/null
          /usr/local/bin/perl -pi -e "s|\['default_folders'] = array\('INBOX', 'Drafts', 'Sent', 'Junk', 'Trash'\)|\['default_folders'] = array\('INBOX', 'Drafts', 'Sent', '${SPAM_FOLDER}', 'Trash'\)|" ${EDIT_CONFIG} > /dev/null
        fi

        if [ "${SPAM_INBOX_PREFIX_OPT}" = "1" ]; then
          /usr/local/bin/perl -pi -e "s|\['junk_mbox'] = 'Junk'|\['junk_mbox'] = 'INBOX.spam'|" ${EDIT_CONFIG} > /dev/null
        fi

        #smtp stuff
        /usr/local/bin/perl -pi -e "s|\['smtp_port'] = 25|\['smtp_port'] = 587|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['smtp_server'] = ''|\['smtp_server'] = 'localhost'|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['smtp_user'] = ''|\['smtp_user'] = '%u'|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['smtp_pass'] = ''|\['smtp_pass'] = '%p'|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['smtp_auth_type'] = ''|\['smtp_auth_type'] = 'LOGIN'|" ${EDIT_CONFIG} > /dev/null

        /usr/local/bin/perl -pi -e "s|\['create_default_folders'] = .*;|\['create_default_folders'] = true;|" ${EDIT_CONFIG} > /dev/null

        /usr/local/bin/perl -pi -e "s|\['login_lc'] = 0;|\['login_lc'] = 2;|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['login_autocomplete'] = 0;|\['login_autocomplete'] = 2;|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['quota_zero_as_unlimited'] = false;|\['quota_zero_as_unlimited'] = true;|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['enable_spellcheck'] = true;|\['enable_spellcheck'] = false;|" ${EDIT_CONFIG} > /dev/null
      else
        #default_host is set to localhost by default in RC 1.0.0, so we don't echo it to the file

        #These ones are already in config.inc.php.sample file, so we just use perl-regex to change them
        /usr/local/bin/perl -pi -e "s|\['smtp_port'] = 25|\['smtp_port'] = 587|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['smtp_server'] = ''|\['smtp_server'] = 'localhost'|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['smtp_user'] = ''|\['smtp_user'] = '%u'|" ${EDIT_CONFIG} > /dev/null
        /usr/local/bin/perl -pi -e "s|\['smtp_pass'] = ''|\['smtp_pass'] = '%p'|" ${EDIT_CONFIG} > /dev/null

        #Changing default options, that are set in defaults.inc.php
        #IMAP folders

        if [ "${WEBAPPS_INBOX_PREFIX_OPT}" = "yes" ]; then
          {
            echo "\$config['drafts_mbox'] = 'INBOX.Drafts';";
            echo "\$config['junk_mbox'] = '${SPAM_FOLDER}';";
            echo "\$config['sent_mbox'] = 'INBOX.Sent';";
            echo "\$config['trash_mbox'] = 'INBOX.Trash';";
            echo "\$config['default_folders'] = array('INBOX', 'INBOX.Drafts', 'INBOX.Sent', '${SPAM_FOLDER}', 'INBOX.Trash');";
          } >> ${EDIT_CONFIG}
        else
          {
            echo "\$config['junk_mbox'] = '${SPAM_FOLDER}';";
            echo "\$config['default_folders'] = array('INBOX', 'Drafts', 'Sent', '${SPAM_FOLDER}', 'Trash');";
          } >> ${EDIT_CONFIG}
        fi

        HN_T=$(hostname)
        {
          echo "\$config['smtp_helo_host'] = '${HN_T}';";
          echo "\$config['smtp_auth_type'] = 'LOGIN';";
          echo "\$config['create_default_folders'] = true;";
          echo "\$config['protect_default_folders'] = true;";
          echo "\$config['login_autocomplete'] = 2;";
          echo "\$config['quota_zero_as_unlimited'] = true;";
          echo "\$config['enable_spellcheck'] = false;";
          echo "\$config['email_dns_check'] = true;";
        } >> ${EDIT_CONFIG}

        if grep -q '^recipients_max' /etc/exim.conf; then
          RECIPIENTS_MAX=$(grep -m1 '^recipients_max' /usr/local/etc/exim.conf | cut -d= -f2 | tr -d ' ')
          echo "\$config['max_recipients'] = ${RECIPIENTS_MAX};" >> ${EDIT_CONFIG}
          echo "\$config['max_group_members'] = ${RECIPIENTS_MAX};" >> ${EDIT_CONFIG}
        fi

        if [ ! -s mime.types ]; then
          if [ "${WEBSERVER_OPT}" = "apache" ] || [ "${WEBSERVER_OPT}" = "litespeed" ] || [ "${WEBSERVER_OPT}" = "nginx_apache" ]; then
            if [ -s /etc/httpd/conf/mime.types ]; then
              if grep -m1 -q 'application/java-archive' /etc/httpd/conf/mime.types; then
                cp -f /etc/httpd/conf/mime.types ./mime.types
              fi
            fi
          fi
        fi
        if [ ! -s mime.types ]; then
          wget "${WGET_CONNECT_OPTIONS}" -O mime.types http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types 2> /dev/null
        fi
        echo "\$config['mime_types'] = '${ALIASPATH}/config/mime.types';" >> ${EDIT_CONFIG}
      fi

      # Password plugin
      if [ -e ${REALPATH}/plugins/password ]; then
        if [ "${ROUNDCUBE_MAJOR_VER}" -eq 0 ]; then
          /usr/local/bin/perl -pi -e "s|\['plugins'] = array\(\);|\['plugins'] = array\('password'\);|" ${EDIT_CONFIG} > /dev/null
        else
          /usr/local/bin/perl -pi -e "s|\['plugins'] = array\(\n|\['plugins'] = array\(\n    'password',\n|" ${EDIT_CONFIG} > /dev/null
        fi

        cd ${REALPATH}/plugins/password || exit

        if [ ! -e config.inc.php ]; then
          cp config.inc.php.dist config.inc.php
        fi

        /usr/local/bin/perl -pi -e "s|\['password_driver'] = 'sql'|\['password_driver'] = 'directadmin'|" config.inc.php > /dev/null

        if [ -e /usr/local/directadmin/directadmin ]; then
          DAPORT=$(/usr/local/directadmin/directadmin c | grep -m1 -e '^port=' | cut -d= -f2)
          /usr/local/bin/perl -pi -e "s|\['password_directadmin_port'] = 2222|\['password_directadmin_port'] = $DAPORT|" config.inc.php > /dev/null

          DASSL=$(/usr/local/directadmin/directadmin c | grep -m1 -e '^ssl=' | cut -d= -f2)
          if [ "$DASSL" -eq 1 ]; then
            /usr/local/bin/perl -pi -e "s|\['password_directadmin_host'] = 'tcp://localhost'|\['password_directadmin_host'] = 'ssl://localhost'|" config.inc.php > /dev/null
          fi
        fi
        cd ${REALPATH}/config || exit
      fi

      # Pigeonhole plugin
      if [ "${PIGEONHOLE_OPT}" = "yes" ]; then
        if [ -d ${REALPATH}/plugins/managesieve ]; then
          if [ "${ROUNDCUBE_MAJOR_VER}" -eq 0 ]; then
            /usr/local/bin/perl -pi -e "s|\['plugins'] = array\('password'\);|\['plugins'] = array\('password','managesieve'\);|" ${EDIT_CONFIG} > /dev/null
          else
            if [ "$(grep -m1 -c "'managesieve'" ${EDIT_CONFIG})" -eq 0 ]; then
              /usr/local/bin/perl -pi -e "s|\['plugins'] = array\(\n|\['plugins'] = array\(\n    'managesieve',\n|" ${EDIT_CONFIG} > /dev/null
            fi
          fi

          cd ${REALPATH}/plugins/managesieve || exit
          if [ ! -e config.inc.php ]; then
            cp config.inc.php.dist config.inc.php
          fi
          /usr/local/bin/perl -pi -e "s|\['managesieve_port'] = null|\['managesieve_port'] = 4190|" config.inc.php > /dev/null
          cd ${REALPATH}/config || exit
        fi
      fi
    fi

    if [ -d "${ROUNDCUBE_PLUGINS}" ]; then
      echo "Copying files from ${ROUNDCUBE_PLUGINS} to ${REALPATH}/plugins"
      cp -Rp "${ROUNDCUBE_PLUGINS}/*" ${REALPATH}/plugins
    fi

    if [ -d "${ROUNDCUBE_SKINS}" ]; then
      echo "Copying files from ${ROUNDCUBE_SKINS} to ${REALPATH}/skins"
      cp -Rp "${ROUNDCUBE_SKINS}/*" ${REALPATH}/skins
    fi

    if [ -d "${ROUNDCUBE_PROGRAM}" ]; then
      echo "Copying files from ${ROUNDCUBE_PROGRAM} to ${REALPATH}/program"
      cp -Rp "${ROUNDCUBE_PROGRAM}/*" ${REALPATH}/program
    fi

    if [ -e "${ROUNDCUBE_HTACCESS}" ]; then
      echo "Copying .htaccess file from ${ROUNDCUBE_HTACCESS} to ${REALPATH}/.htaccess"
      cp -pf "${ROUNDCUBE_HTACCESS}" ${REALPATH}/.htaccess
    fi

    echo "Roundcube ${ROUNDCUBE_VER} has been installed successfully."
  fi

  # Systems with "system()" in disable_functions need to use no php.ini:
  if [ "$(have_php_system)" = "0" ]; then
    perl -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${REALPATH}/bin/update.sh
  fi

  #systems with suhosin cannot have PHP memory_limit set to -1, we need not to load suhosin for RoundCube .sh scripts
  if [ "${SUHOSIN_OPT}" = "yes" ]; then
    perl -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${REALPATH}/bin/msgimport.sh
    perl -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${REALPATH}/bin/indexcontacts.sh
    perl -pi -e 's#^\#\!/usr/bin/env php#\#\!/usr/local/bin/php \-n#' ${REALPATH}/bin/msgexport.sh
  fi

  #update if needed
  ${REALPATH}/bin/update.sh '--version=?'

  #cleanup
  rm -rf "${ALIASPATH}/installer"

  #set the permissions:
  chown -R "${APPUSER}:${APPUSER}" ${REALPATH}
  if [ "${APPGROUP}" = "apache" ]; then
    chown -R apache ${REALPATH}/temp ${REALPATH}/logs
    /bin/chmod -R 770 ${REALPATH}/temp
    /bin/chmod -R 770 ${REALPATH}/logs
  fi

  # Secure configuration file
  if [ -s ${EDIT_DB} ]; then
    chmod 440 ${EDIT_DB}
    if [ "${APPGROUP}" = "apache" ]; then
      echo "**********************************************************************"
      echo "* "
      echo "* SECURITY: ${REALPATH}/config/${EDIT_DB} is readable by apache."
      echo "* Recommended: use a php type that runs php scripts as the User, then re-install roundcube."
      echo "*"
      echo "**********************************************************************"
    fi

    chown "${APPUSER}:${APPGROUP}" ${EDIT_DB}

    if [ "${APPGROUP}" = "apache" ]; then
      ls -la ${REALPATH}/config/${EDIT_DB}
      sleep 5
    fi
  fi

  RC_HTACCESS=${REALPATH}/.htaccess
  if [ -s "${RC_HTACCESS}" ]; then
    if grep -m1 -q upload_max_filesize ${RC_HTACCESS}; then
      perl -pi -e 's/^php_value\supload_max_filesize/#php_value       upload_max_filesize/' ${RC_HTACCESS}
      perl -pi -e 's/^php_value\spost_max_size/#php_value       post_max_size/' ${RC_HTACCESS}
    fi
    perl -pi -e 's/FollowSymLinks/SymLinksIfOwnerMatch/' ${RC_HTACCESS}
  fi

  ensure_webapps_tmp

  cd "${CWD}" || exit
}
