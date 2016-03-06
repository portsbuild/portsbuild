# Notes

### Todo for first release:
* Finalize defaults.conf and options.conf
* RoundCube
* Exception handling and friendlier error messages
* Implement additional validation controls
* Refactor certain functions
* Cleanup unused variables or forgotten strings
* Setup hosted WWW repo to download files needed by PB (like files.directadmin.com)
* Final shellcheck verification
* Create HOWTO or "Get Started" guide
* Ask DirectAdmin Staff and Martynas for their blessing


### Upcoming:
* Validate selected options by the user (set in options.conf)
* Create test units via shunit2
* Test on FreeBSD 10.3
* Test Perl 5.22
* Bash completion script

### Menu Overview:

    config
    
    help <command>
    
    install
    
    options
    
    outdated
    
    rewrite
    
    setup
    
    update
    
    upgrade
    
    version


### Research:
* Multiple PHP installations on the same server. Will have to prefix the target installation directory, e.g.

    /usr/local/php56
    /usr/local/php70

* Implement security/py-letsencrypt
* Multilingual support


### Initial Build Environment Requirements
* ports-mgmt/pkg
* ports-mgmt/portmaster
* ports-mgmt/portconf (removed?)
* shells/bash
* lang/perl5.20
* ftp/wget
* devel/autoconf
* devel/automake
* devel/libtool
* lang/pyton27
* lang/python
* ftp/curl
* devel/gettext
* lang/gcc (lang/gcc48)
* dns/bind910 (for 10.1/10.2)
* converters/libiconv
* graphics/gd
* graphics/png
* graphics/jpeg
* graphic/tiff
* textproc/libxslt
* devel/gmake
* security/cyrus-sasl2
* textproc/libxml2


    killall -USR1 dataskq
    tail -n 10 /var/log/directadmin/errortaskq.log
    ln -s /etc/rc.d/named /usr/local/etc/rc.d/named
    ln -s /etc/rc.d/sshd /usr/local/etc/rc.d/sshd
    ln -s /usr/local/etc/rc.d/php-fpm /usr/local/etc/rc.d/php-fpm56


UPPERCASE_SECTION=`echo $1 | tr "[a-z]" "[A-Z]"`


===> The following configuration options are available for phpMyAdmin-4.5.5:
     BZ2=on: PHP bzip2 library support
     GD=on: PHP GD library support (requires X11)
     MCRYPT=on: PHP MCrypt library support
     OPENSSL=on: PHP OpenSSL support
     PDF=off: PHP PDFlib support
     XML=on: PHP XML support (Export to OpenDoc)
     ZIP=on: PHP Zip compression support
     ZLIB=on: PHP ZLIB support


===> The following configuration options are available for php55-extensions-1.8:
     BCMATH=off: bc style precision math functions
     BZ2=off: bzip2 library support
     CALENDAR=off: calendar conversion support
     CTYPE=on: ctype functions
     CURL=off: CURL support
     DBA=off: dba support
     DOM=on: DOM support
     EXIF=off: EXIF support
     FILEINFO=off: fileinfo support
     FILTER=on: input filter support
     FTP=off: FTP support
     GD=off: GD library support
     GETTEXT=off: gettext library support
     GMP=off: GNU MP support
     HASH=on: HASH Message Digest Framework
     ICONV=on: iconv support
     IMAP=off: IMAP support
     INTERBASE=off: Interbase 6 database support (Firebird)
     JSON=on: JavaScript Object Serialization support
     LDAP=off: OpenLDAP support
     MBSTRING=off: multibyte string support
     MCRYPT=off: Encryption support
     MSSQL=off: MS-SQL database support
     MYSQL=off: MySQL database support
     MYSQLI=off: MySQLi database support
     ODBC=off: ODBC support
     OPCACHE=on: OPcache support
     OPENSSL=off: OpenSSL support
     PCNTL=off: pcntl support (CLI only)
     PDF=off: PDFlib support (implies GD)
     PDO=on: PHP Data Objects Interface (PDO)
     PDO_DBLIB=off: PDO DBLIB-DB driver
     PDO_FIREBIRD=off: PDO Firebird driver
     PDO_MYSQL=off: PDO MySQL driver
     PDO_ODBC=off: PDO ODBC driver
     PDO_PGSQL=off: PDO PostgreSQL driver
     PDO_SQLITE=on: PDO sqlite driver
     PGSQL=off: PostgreSQL database support
     PHAR=on: phar support
     POSIX=on: POSIX-like functions
     PSPELL=off: pspell support
     READLINE=off: readline support (CLI only)
     RECODE=off: recode support
     SESSION=on: session support
     SHMOP=off: shmop support
     SIMPLEXML=on: simplexml support
     SNMP=off: SNMP support
     SOAP=off: SOAP support
     SOCKETS=off: sockets support
     SQLITE3=on: sqlite3 support
     SYBASE_CT=off: Sybase database support
     SYSVMSG=off: System V message support
     SYSVSEM=off: System V semaphore support
     SYSVSHM=off: System V shared memory support
     TIDY=off: TIDY support
     TOKENIZER=on: tokenizer support
     WDDX=off: WDDX support (implies XML)
     XML=on: XML support
     XMLREADER=on: XMLReader support
     XMLRPC=off: XMLRPC-EPI support
     XMLWRITER=on: XMLWriter support
     XSL=off: XSL support (Implies DOM)
     ZIP=off: ZIP support
     ZLIB=off: ZLIB support

===> The following configuration options are available for php56-extensions-1.0:
     BCMATH=off: bc style precision math functions
     BZ2=off: bzip2 library support
     CALENDAR=off: calendar conversion support
     CTYPE=on: ctype functions
     CURL=off: CURL support
     DBA=off: dba support
     DOM=on: DOM support
     EXIF=off: EXIF support
     FILEINFO=off: fileinfo support
     FILTER=on: input filter support
     FTP=off: FTP support
     GD=off: GD library support
     GETTEXT=off: gettext library support
     GMP=off: GNU MP support
     HASH=on: HASH Message Digest Framework
     ICONV=on: iconv support
     IMAP=off: IMAP support
     INTERBASE=off: Interbase 6 database support (Firebird)
     JSON=on: JavaScript Object Serialization support
     LDAP=off: OpenLDAP support
     MBSTRING=off: multibyte string support
     MCRYPT=off: Encryption support
     MSSQL=off: MS-SQL database support
     MYSQL=off: MySQL database support
     MYSQLI=off: MySQLi database support
     ODBC=off: ODBC support
     OPCACHE=on: OPcache support
     OPENSSL=off: OpenSSL support
     PCNTL=off: pcntl support (CLI only)
     PDF=off: PDFlib support (implies GD)
     PDO=on: PHP Data Objects Interface (PDO)
     PDO_DBLIB=off: PDO DBLIB-DB driver
     PDO_FIREBIRD=off: PDO Firebird driver
     PDO_MYSQL=off: PDO MySQL driver
     PDO_ODBC=off: PDO ODBC driver
     PDO_PGSQL=off: PDO PostgreSQL driver
     PDO_SQLITE=on: PDO sqlite driver
     PGSQL=off: PostgreSQL database support
     PHAR=on: phar support
     POSIX=on: POSIX-like functions
     PSPELL=off: pspell support
     READLINE=off: readline support (CLI only)
     RECODE=off: recode support
     SESSION=on: session support
     SHMOP=off: shmop support
     SIMPLEXML=on: simplexml support
     SNMP=off: SNMP support
     SOAP=off: SOAP support
     SOCKETS=off: sockets support
     SQLITE3=on: sqlite3 support
     SYBASE_CT=off: Sybase database support
     SYSVMSG=off: System V message support
     SYSVSEM=off: System V semaphore support
     SYSVSHM=off: System V shared memory support
     TIDY=off: TIDY support
     TOKENIZER=on: tokenizer support
     WDDX=off: WDDX support (implies XML)
     XML=on: XML support
     XMLREADER=on: XMLReader support
     XMLRPC=off: XMLRPC-EPI support
     XMLWRITER=on: XMLWriter support
     XSL=off: XSL support (Implies DOM)
     ZIP=off: ZIP support
     ZLIB=off: ZLIB support


===> The following configuration options are available for php70-extensions-1.1:
     BCMATH=off: bc style precision math functions
     BZ2=off: bzip2 library support
     CALENDAR=off: calendar conversion support
     CTYPE=on: ctype functions
     CURL=off: CURL support
     DBA=off: dba support
     DOM=on: DOM support
     EXIF=off: EXIF support
     FILEINFO=off: fileinfo support
     FILTER=on: input filter support
     FTP=off: FTP support
     GD=off: GD library support
     GETTEXT=off: gettext library support
     GMP=off: GNU MP support
     HASH=on: HASH Message Digest Framework
     ICONV=on: iconv support
     IMAP=off: IMAP support
     INTERBASE=off: Interbase 6 database support (Firebird)
     INTL=off: Internationalization(ICU)
     JSON=on: JavaScript Object Serialization support
     LDAP=off: OpenLDAP support
     MBSTRING=off: multibyte string support
     MCRYPT=off: Encryption support
     MYSQLI=off: MySQLi database support
     ODBC=off: ODBC support
     OPCACHE=on: OPcache support
     OPENSSL=off: OpenSSL support
     PCNTL=off: pcntl support (CLI only)
     PDF=off: PDFlib support (implies GD)
     PDO=on: PHP Data Objects Interface (PDO)
     PDO_DBLIB=off: PDO DBLIB-DB driver
     PDO_FIREBIRD=off: PDO Firebird driver
     PDO_MYSQL=off: PDO MySQL driver
     PDO_ODBC=off: PDO ODBC driver
     PDO_PGSQL=off: PDO PostgreSQL driver
     PDO_SQLITE=on: PDO sqlite driver
     PGSQL=off: PostgreSQL database support
     PHAR=on: phar support
     POSIX=on: POSIX-like functions
     PSPELL=off: pspell support
     READLINE=off: readline support (CLI only)
     RECODE=off: recode support
     SESSION=on: session support
     SHMOP=off: shmop support
     SIMPLEXML=on: simplexml support
     SNMP=off: SNMP support
     SOAP=off: SOAP support
     SOCKETS=off: sockets support
     SQLITE3=on: sqlite3 support
     SYBASE_CT=off: Sybase database support
     SYSVMSG=off: System V message support
     SYSVSEM=off: System V semaphore support
     SYSVSHM=off: System V shared memory support
     TIDY=off: TIDY support
     TOKENIZER=on: tokenizer support
     WDDX=off: WDDX support (implies XML)
     XML=on: XML support
     XMLREADER=on: XMLReader support
     XMLRPC=off: XMLRPC-EPI support
     XMLWRITER=on: XMLWriter support
     XSL=off: XSL support (Implies DOM)
     ZIP=off: ZIP support
     ZLIB=off: ZLIB support
