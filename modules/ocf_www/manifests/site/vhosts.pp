# TODO: document this
class ocf_www::site::vhosts {
  file {
    '/usr/local/bin/parse-vhosts':
      source  => 'puppet:///modules/ocf_www/parse-vhosts',
      mode    => '0755',
      require => Package['python3-ocflib'];

    '/etc/ssl/private/vhosts':
      ensure  => directory,
      source  => 'puppet:///private/ssl/vhosts',
      recurse => true,
      owner   => root,
      mode    => '0600';
  }
  ocf_www::site::vhost { $ocf_vhosts:; }
}
