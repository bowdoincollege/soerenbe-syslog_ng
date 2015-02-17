#
# This class manages a syslog-ng server. It can be uses for standard logging or complex client/server setups
#
# === Parameters
#
# See README.md for a detailed parameter description
#
# === Variables
#
# No variables required. See params.pp for options.
#
# === Examples
#
# Basic setup:
#
#  import syslog_ng
#
# Some special logging
#
#  syslog_ng::destination::file {'d_file':
#    file => '/var/log/myapp.log'
#  }
#  syslog_ng::filter {'f_mypp':
#    spec => 'program(myapp_name)
#  }
#  syslog_ng::filter {'f_app_server':
#    spec => 'host(appserver.example.org)'
#  }
#  syslog_ng::log {'l_my_app':
#    source      => 's_src',
#    filter      => ['f_myapp', 'f_app_server'],
#    destination => 'd_file'
#  }
#
# === Authors
#
# Sören Berger <soeren.berger@u1337.de>
#
# === Copyright
#
# Copyright 2015 Sören Berger.
#

class syslog_ng (
  $system_log_dir            = $syslog_ng::params::system_log_dir,
  $config_dir                = $syslog_ng::params::config_dir,
  $local_source              = $syslog_ng::params::local_source,
  $reminder_file             = $syslog_ng::params::reminder_file,
  $create_dirs               = $syslog_ng::params::create_dirs,
  $default_owner             = $syslog_ng::params::default_owner,
  $default_group             = $syslog_ng::params::default_group,
  $default_perm              = $syslog_ng::params::default_perm,
  $use_fqdn                  = $syslog_ng::params::use_fqdn,
  $use_dns                   = $syslog_ng::params::use_dns,
  $chain_hostnames           = $syslog_ng::params::chain_hostnames,
  $stats_freq                = $syslog_ng::params::stats_freq,
  $mark_freq                 = $syslog_ng::params::mark_freq,
  $threaded                  = $syslog_ng::params::threaded,
  $flush_lines               = $syslog_ng::params::flush_lines,
  $log_fifo_size             = $syslog_ng::params::log_fifo_size,
  $log_fifo_size_destination = $syslog_ng::params::log_fifo_size_destination,
) inherits ::syslog_ng::params {
  include syslog_ng::params
  $fragments = [
    $syslog_ng::params::config_file_sources,
    $syslog_ng::params::config_file_destination_files,
    $syslog_ng::params::config_file_destination_fallback,
    $syslog_ng::params::config_file_destination_remote,
    $syslog_ng::params::config_file_filter,
    $syslog_ng::params::config_file_parser,
    $syslog_ng::params::config_file_logging,
    $syslog_ng::params::config_file_fallback,
  ]
  concat {$fragments:
    force  => true,
    warn   => "# This file is generated by puppet",
    notify => Service[syslog_ng],
    owner => 'root',
    group => 'root',
    mode  => '0644'
  }
  include syslog_ng::install
  include syslog_ng::service
}

#
# Sources
#

define syslog_ng::source (
  $spec     = undef,
  $fallback = undef,
  ) {
  $entry_type = "source"
  concat::fragment{ "$name":
    target  => $::syslog_ng::config_file_sources,
    content => template('syslog_ng/entry.erb')
  }
  if $fallback {
    validate_string($fallback)
    syslog_ng::destination::file {"${name}_fallback":
      file   => $fallback,
      target => $::syslog_ng::config_file_destination_fallback,
    }
    $source      = $name
    $destination = "${name}_fallback"
    concat::fragment{ "${name}_fallback":
      target  => $::syslog_ng::config_file_fallback,
      content => template('syslog_ng/log.erb')
    }
  }
}

define syslog_ng::source::network(
  $ip       = undef,
  $port     = undef,
  $proto    = "udp",
  $fallback = undef,
  ) {
  case $proto {
    'UDP', 'udp': {
      syslog_ng::source { $name:
        spec     => "udp(ip('${ip}') port(${port}));",
        fallback => $fallback
      }
    }
    'TCP', 'tcp': {
      syslog_ng::source { $name:
        spec     => "tcp(ip('${ip}') port(${port}));",
        fallback => $fallback
      }
    }
    'ALL', 'all': {
      syslog_ng::source { $name:
        spec     => "\n  tcp(ip('${ip}') port(${port}));\n  udp(ip('${ip}') port(${port}));\n",
        fallback => $fallback
      }
    }
    default: {
      fail("$proto is not supported by syslog_ng::server")
    }
  }
}

define syslog_ng::source::system {
    syslog_ng::source {$name:
      spec  => "system(); internal();",
    }
}

#
# Parser
#

define syslog_ng::parser (
  $spec   = undef,
  $target = $::syslog_ng::config_file_parser,
  ) {
  $entry_type = "parser"
  concat::fragment{ "$name":
    target  => $target,
    content => template('syslog_ng/entry.erb')
  }
}

#
# rewrite
#

define syslog_ng::rewrite (
  $spec   = undef,
  $target = $::syslog_ng::config_file_rewrite,
  ) {
  $entry_type = "rewrite"
  concat::fragment{ "$name":
    target  => $target,
    content => template('syslog_ng/entry.erb')
  }
}


#
# Destinations
#

define syslog_ng::destination (
  $spec   = undef,
  $target = $::syslog_ng::config_file_destination_files,
  ) {
  validate_string($content)
  validate_string($target)
  $entry_type = "destination"
  concat::fragment{ "destination_${name}":
    target  => $target,
    content => template('syslog_ng/entry.erb')
  }
}

define syslog_ng::destination::file (
  $file      = undef,
  $owner     = undef,
  $group     = undef,
  $dir_owner = undef,
  $dir_group = undef,
  $perm      = undef,
  $target    = $::syslog_ng::config_file_destination_files,
  ){
  syslog_ng::destination {$name:
    spec   => inline_template("file('${file}' <%= scope.function_template(['syslog_ng/fileparams.erb']) %>);"),
    target => $target
  }
  file {"$file":
    ensure => file,
    owner  => $owner,
    group  => $group,
    mode   => $perm
  }
}

define syslog_ng::destination::network (
  $log_server = undef,
  $log_port   = undef,
  $proto      = "udp",
  ) {
  case $proto {
    'UDP', 'udp': {
      syslog_ng::destination {$name:
        spec   => "udp('${log_server}' port(${log_port}) log_fifo_size(${::syslog_ng::log_fifo_size_destination}));",
        target => $syslog_ng::params::config_file_destination_remote
      }
    }
    'TCP', 'tcp': {
      syslog_ng::destination {$name:
        spec   => "tcp('${log_server}' port(${log_port}) log_fifo_size(${::syslog_ng::log_fifo_size_destination}));",
        target => $syslog_ng::params::config_file_destination_remote
      }
    }
    default: {
      fail("$proto is not supported by syslog_ng::client")
    }
  }
}

#
# Filters
#

define syslog_ng::filter (
  $spec = undef,
  ) {
  validate_string($content)
  $entry_type = "filter"
  concat::fragment{ "${name}_fallback":
    target  => $::syslog_ng::config_file_filter,
    content => template('syslog_ng/entry.erb')
  }
}

#
# Logging
#

define syslog_ng::log (
  $source          = undef,
  $filter          = undef,
  $filter_spec     = undef,
  $parser          = undef,
  $rewrite         = undef,
  $destination     = undef,
  $file            = undef,
  $fallback        = undef,
  $owner           = undef,
  $group           = undef,
  $dir_owner       = undef,
  $dir_group       = undef,
  $perm            = undef,
  ) {
  validate_string($source)
  if $fallback {
    $target = $::syslog_ng::config_file_fallback
  }
  else {
    $target = $::syslog_ng::config_file_logging
  }
  if $file {
    syslog_ng::destination::file {"d_${name}":
      file      => $file,
      owner     => $owner,
      group     => $group,
      dir_owner => $dir_owner,
      dir_group => $dir_group,
      perm      => $perm
    }
  }
  if $filter_spec {
    syslog_ng::filter {"f_${name}":
      spec => $filter_spec
    }
  }
  concat::fragment{ "${name}_log":
    target  => $target,
    content => template('syslog_ng/log.erb'),
  }
}

