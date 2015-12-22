###
# Class: rjil::contrail::vrouter
#
# $discovery_address: ideally this should be resolved from
# lb.discovery.service.consul, but for this it need some more work to see the
# impact of moving haproxy to lb. This will be worked on with multi-node
# contrail setup.
###

class rjil::contrail::vrouter (
  $discovery_address = join(service_discover_dns('lb.neutron.service.consul','name')),
  $api_address       = undef,
  $dns_nameserver_list    = ['127.0.0.1']
) {


  ##
  # Vgw need floating IP pool to be created before it can successfully created.
  # Without floating IP vgw is just created, but the routes are not getting added in
  # the floating IP network VRF properly even after the pool has been added.
  # Fixing this issue by blocking contrail_vgw creation till a consul k/v
  # (neutron/floatingip_pool/status) is set. This is set by neutron deployment
  # code after successful addition of floatingip pool.
  ##

  ensure_resource( 'consul_kv_fail', 'neutron/floatingip_pool/status', {})
  Consul_kv_fail['neutron/floatingip_pool/status'] -> Contrail::Vgw<||>

  include nova::compute::libvirt

  Package['libvirt'] ->
  File_line['cgroup_device_acl']

  file_line {'cgroup_device_acl':
    path => '/etc/libvirt/qemu.conf',
    line => 'cgroup_device_acl = [ "/dev/null", "/dev/full", "/dev/zero", "/dev/random", "/dev/urandom", "/dev/ptmx", "/dev/kvm", "/dev/kqemu", "/dev/rtc", "/dev/hpet","/dev/net/tun", ]',
    notify => Service['libvirt'],
  }

  class {'::contrail::vrouter':
    discovery_address => $discovery_address,
    api_address       => $api_address,
    headless_mode     => true,
  }

  include rjil::contrail::logrotate::consolidate

# Vrouter is now honoring the filesize, so no need for consolidate here
  rjil::jiocloud::logrotate { 'contrail-vrouter':
    logdir       => '/var/log/contrail',
    copytruncate => true,
  }

  # overwrite the /etc/init/contrail-vrouter-agent.conf
  # so that the agent can have a private namespace mount point of
  # /etc/hosts and /etc/resolv.conf. This fix is done so that VM's 
  # cannot resolve internal IP's of the cloud

  file { '/etc/contrail-resolv.conf':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template('rjil/contrail-resolv.erb'),
    require => Package['contrail-vrouter-agent'],
    notify  => Service['contrail-vrouter-agent'],
  }

  file { '/etc/init/contrail-vrouter-agent.conf':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => "puppet:///modules/rjil/contrail-vrouter-agent.conf",
    require => Package['contrail-vrouter-agent'],
    notify  => Service['contrail-vrouter-agent'],
  }

  file {'/etc/contrail-hosts':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template('rjil/contrail-hosts.erb'),
    require => Package['contrail-vrouter-agent'],
    notify  => Service['contrail-vrouter-agent'],
  }
  
  ##
  # validation checks
  ##

  include rjil::test::contrail_vrouter

  ##
  # Temporary consul check to test and restart vrouter
  ##

  rjil::test {
    'contrail-vrouter-check.sh':
  }

  rjil::jiocloud::consul::service { 'contrail-vrouter-check':
    interval      => '10s',
    check_command => '/usr/lib/jiocloud/tests/contrail-vrouter-check.sh',
  }
}
