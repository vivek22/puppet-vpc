Exec {
  path      => ["/bin/", "/sbin/", "/usr/bin/", "/usr/sbin/", "/usr/local/bin/", "/usr/local/sbin/"],
  logoutput => true
}


node /^ctseed\d+/{
  include rjil::base
  include rjil::redis
  include rjil::cassandra
  include rjil::rabbitmq
  include rjil::zookeeper
  include rjil::contrail::server
  include rjil::neutron::contrail
}



node /^ct\d+/ {
  include rjil::base
  include rjil::redis
  include rjil::cassandra
  include rjil::rabbitmq
  include rjil::zookeeper
  include rjil::contrail::server
  include rjil::neutron::contrail
}


node /^cp\d+/ {
  include rjil::base
  include rjil::ceph
  include openstack_extras::client
  include rjil::contrail::vrouter
  include rjil::openstack_zeromq
  include rjil::nova::compute
}

#Adding St nodes for all testing the complete setup

node /^st\d+/ {
  include rjil::base
  include rjil::ceph
  include rjil::ceph::mon_config
  include rjil::ceph::osd
  ensure_resource('rjil::service_blocker', 'stmon', {})
  Class['rjil::base'] -> Rjil::Service_blocker['stmon'] ->
  Class['rjil::ceph::osd']
}

##
# single leader that will be used to ensure that all mons form a single cluster.
#
# The only difference in stmon and stmonleader is that stmonleader is the node
# which starts first in the ceph cluster initialization. After that, both
# those roles will serve the same purpose.
# All ceph servers and clients (st, stmon, cp, oc nodes) except stmonleader will wait for at least
# one "stmon" service node in consul.
#
# The leader will register the service in consul with name "stmon" (or
# any other name if overridden in hiera).
#
##

node /^stmonleader1/ {
  include rjil::base
  include rjil::ceph
  include rjil::ceph::mon
  include rjil::ceph::osd
  include rjil::ceph::radosgw

  rjil::jiocloud::consul::service { 'stmonleader':
    port          => 6789,
    check_command => '/usr/lib/jiocloud/tests/check_ceph_mon.sh'
  }
}

##
# setup ceph osd and mon configuration on ceph Mon nodes.
# All ceph mon nodes are registered in consul as service name "stmon" (or any
# other name if overridden)
#
# stmon nodes will wait at least one "stmon" service to be up in consul before
# initialize themselves
##

node /^stmon\d+/ {
  include rjil::base
  include rjil::ceph
  include rjil::ceph::mon
  include rjil::ceph::osd
  include rjil::ceph::radosgw
  ensure_resource('rjil::service_blocker', 'stmonleader', {
  }
  )
  Class[rjil::base] -> Rjil::Service_blocker['stmonleader']
  Rjil::Service_blocker['stmonleader'] -> Class['rjil::ceph::mon::mon_config']
}


node /^haproxy\d+/ {
  include rjil::base
  include rjil::haproxy
  include rjil::haproxy::contrail
  include rjil::haproxy::openstack
}

node /^keystone\d+/ {
  include rjil::base
  include rjil::keystone
  include rjil::memcached
  include openstack_extras::client
  include rjil::cinder
  include rjil::glance
  include rjil::nova::controller
  include rjil::openstack_zeromq
  include rjil::db
  include rjil::openstack_objects
}

node /^httpproxy\d+/ {
  include rjil::base
  include rjil::http_proxy
  dnsmasq::conf { 'google':
    ensure  => present,
    content => 'server=8.8.8.8',
  }
  include rjil::jiocloud::vagrant::dhcp
}



