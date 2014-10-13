class ocf_www {
  include ocf_ssl

  package {
    [ 'apache2', 'libapache-mod-security', 'apache2-threaded-dev', 'libapache2-mod-fastcgi']:
      before => Package['libapache2-mod-php5'];

    # php
    ['php5', 'php5-mysql', 'php5-sqlite', 'libapache2-mod-suphp', 'php5-gd', 'php5-curl', 'php5-mcrypt']:
      before => Package['libapache2-mod-php5'];

    # mod-php interferes with suphp and fcgid but is pulled in as recommended dependency
    'libapache2-mod-php5':
      ensure => purged;

    # python and django
    ['python-django', 'python-mysqldb', 'python-flup', 'python-flask', 'python-sqlalchemy']:;

    # perl
    ['libdbi-perl']:;

    # ruby and rails
    ['rails3', 'libfcgi-ruby1.8', 'libmysql-ruby', 'ruby-sqlite3']:;

    # misc dev packages
    ['libfcgi-dev', 'sqlite3', 'libsqlite3-dev', 'libtidy-dev', 'nodejs']:;

    # nfs
    'nfs-kernel-server':;
  }

  file { '/etc/apache2/conf.d':
    ensure  => directory,
    recurse => true,
    source  => 'puppet:///modules/ocf_www/apache/conf.d',
    require => Package['apache2'],
    notify  => Service['apache2'],
  }

  file { '/etc/apache2/sites-available':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    recurse => true,
    require => Package['apache2'],
  }

  file { '/etc/apache2/sites-available/01-www.conf':
    content => template('ocf_www/vhosts/www.conf.erb'),
    notify  => Service['apache2'],
    require => Package['apache2'],
  }

  file { '/etc/apache2/sites-available/02-shorturl.conf':
    content => template('ocf_www/vhosts/shorturl.conf.erb'),
    notify  => Service['apache2'],
    require => Package['apache2'],
  }

  file { '/etc/apache2/sites-available/03-pma.conf':
    content => template('ocf_www/vhosts/pma.conf.erb'),
    notify  => Service['apache2'],
    require => Package['apache2'],
  }

  file { '/etc/apache2/sites-available/04-hello.conf':
    content => template('ocf_www/vhosts/hello.conf.erb'),
    notify  => Service['apache2'],
    require => Package['apache2'],
  }

  file { '/etc/apache2/sites-common.conf':
    source  => 'puppet:///modules/ocf_www/apache/sites-common.conf',
    notify  => Service['apache2'],
    require => Package['apache2'],
  }

  file { '/etc/apache2/mods-available':
    ensure  => directory,
    require => Package['apache2'],
  }

  file { '/etc/apache2/mods-available/mod_ocfdir.c':
    ensure => file,
    source => 'puppet:///modules/ocf_www/apache/mods/mod_ocfdir.c',
  }

  file { '/etc/apache2/mods-available/fastcgi.conf':
    ensure => file,
    source => 'puppet:///modules/ocf_www/apache/mods/fastcgi.conf',
  }

  file { '/usr/lib/apache2':
    ensure  => directory,
    require => Package['apache2'],
  }

  file { '/usr/lib/apache2/suexec':
    ensure  => file,
    source  => 'puppet:///contrib/local/ocf_www/suexec',
    backup  => false, # it's a binary file
    mode    => '4750',
    owner   => 'root',
    group   => 'www-data',
    require => Package['apache2'],
  }

  file {
    '/opt/suexec':
      ensure => directory;

    '/opt/suexec/php5-fcgi-wrapper.c':
      source => 'puppet:///modules/ocf_www/apache/php5-fcgi-wrapper.c',
      mode   => 644;
  }

  exec { '/usr/bin/apxs2 -i -c -a -n ocfdir /etc/apache2/mods-available/mod_ocfdir.c':
    require => [ Package['apache2-threaded-dev'], File['/etc/apache2/mods-available/mod_ocfdir.c'] ],
    notify  => Service['apache2'],
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/ocfdir.load',
  }

  # enable apache modules
  exec { '/usr/sbin/a2enmod rewrite':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/rewrite.load',
    notify  => Service['apache2'],
    require => Package['apache2'],
  }
  exec { '/usr/sbin/a2enmod fastcgi':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/fastcgi.load',
    notify  => Service['apache2'],
    require => [Package['apache2'], Package['libapache2-mod-fastcgi']],
  }
  exec { '/usr/sbin/a2enmod headers':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/headers.load',
    notify  => Service['apache2'],
    require => Package['apache2'],
  }
  exec { '/usr/sbin/a2enmod include':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/include.load',
    notify  => Service['apache2'],
    require => Package['apache2'],
  }
  exec { '/usr/sbin/a2enmod suexec':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/suexec.load',
    notify  => Service['apache2'],
    require => [Package['apache2'], File['/usr/lib/apache2/suexec']],
  }
  exec { '/usr/sbin/a2enmod suphp':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/suphp.load',
    notify  => Service['apache2'],
    require => [Package['apache2'], Package['libapache2-mod-suphp']],
  }
  exec { '/usr/sbin/a2enmod ssl':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/ssl.load',
    notify  => Service['apache2'],
    require => [File["/etc/ssl/private/${::fqdn}.crt"], Package['apache2']],
  }
  exec { '/usr/sbin/a2enmod userdir':
    unless  => '/bin/readlink -e /etc/apache2/mods-enabled/userdir.load',
    notify  => Service['apache2'],
    require => Package['apache2'],
  }

  # disable default site
  exec { '/usr/sbin/a2dissite 000-default':
    onlyif  => '/bin/readlink -e /etc/apache2/sites-enabled/000-default',
    require => Package['apache2'],
    notify  => Service['apache2'],
  }

  # disable the php5 module because it conflicts with suphp
  exec { '/usr/sbin/a2dismod php5':
    onlyif  => '/bin/readlink -e /etc/apache2/mods-enabled/php5.load',
    require => Package['apache2', 'php5'],
    notify  => Service['apache2'],
  }

  # enable sites
  exec { '/usr/sbin/a2ensite 01-www.conf':
    unless  => '/bin/readlink -e /etc/apache2/sites-enabled/01-www.conf',
    notify  => Service['apache2'],
    require => [Exec['/usr/sbin/a2enmod rewrite'], Exec['/usr/sbin/a2enmod include'], File['/etc/apache2/sites-available/01-www.conf']],
  }
  exec { '/usr/sbin/a2ensite 02-shorturl.conf':
    unless  => '/bin/readlink -e /etc/apache2/sites-enabled/02-shorturl.conf',
    notify  => Service['apache2'],
    require => File['/etc/apache2/sites-available/02-shorturl.conf'],
  }
  exec { '/usr/sbin/a2ensite 03-pma.conf':
    unless  => '/bin/readlink -e /etc/apache2/sites-enabled/03-pma.conf',
    notify  => Service['apache2'],
    require => File['/etc/apache2/sites-available/03-pma.conf'],
  }
  exec { '/usr/sbin/a2ensite 04-hello.conf':
    unless  => '/bin/readlink -e /etc/apache2/sites-enabled/04-hello.conf',
    notify  => Service['apache2'],
    require => File['/etc/apache2/sites-available/04-hello.conf'],
  }

  # dpkg-divert
  exec { '/usr/bin/dpkg-divert --divert /usr/lib/apache2/suexec.dist --rename /usr/lib/apache2/suexec':
    unless  => '/usr/bin/dpkg-divert --list | grep suexec',
    require => File['/usr/lib/apache2/suexec'],
  }

  # suphp is separated from apache
  file {
    '/etc/suphp/suphp.conf':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => 'puppet:///modules/ocf_www/apache/mods/suphp.config.ocf',
      require => Package['libapache2-mod-suphp'];

    '/etc/php5/cgi/php.ini':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => 'puppet:///modules/ocf_www/apache/mods/php.ini',
      require => Package['php5'],
  }

  # apache must subscribe to all conf files
  service { 'apache2':; }

  # nfs export of apache logs
  file {
    '/etc/exports':
      ensure  => file,
      source  => 'puppet:///modules/ocf_www/exports',
      require => Package['nfs-kernel-server', 'apache2'],
      notify  => Service['nfs-kernel-server'],
  }

  # make sure logratate changes the permissions so that it is viewable when exported
  file {
    '/etc/logrotate.d/apache2':
      ensure => file,
      source => 'puppet:///modules/ocf_www/logrotate/apache2',
  }

  service { 'nfs-kernel-server': }
}
