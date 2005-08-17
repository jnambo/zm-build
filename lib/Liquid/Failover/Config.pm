package Liquid::Failover::Config;

use strict;
use Liquid::Failover::Bootstrap;

my $LIQUID_HOME = $ENV{LIQUID_HOME} || $ENV{HOME} || '/opt/liquid';

my %HEARTBEAT_CONFIG = (
    ADMIN_SOAP_PORT => 7070,        # admin SOAP servlet port
    USER_SOAP_PORT => 7070,         # user SOAP servlet port
    CURRENT_ROLE => undef,          # 'master' or 'slave'
    SERIAL_ENABLED => 0,            # heartbeat over serial connection
    TCP_ENABLED => 0,               # heartbeat over TCP connection
    AUTO_FAILOVER => 0,             # automatic or manual failover
    SERIAL_DEVICE => '/dev/ttyS0',  # must be owned by liquid user
    HEARTBEAT_TCP_PORT => 7778,
    HEARTBEAT_INTERVAL => 10,       # in seconds
    HEARTBEAT_MAX_FAILURES => 6,    # failover trigger threshold
    LOCAL_IPADDR => undef,
    PEER_IPADDR => undef,
    SERVICE_INTERFACE => undef,
    SERVICE_IPADDR => undef,
    ROUTER_IPADDR => undef
);
my $CONFIG_READ = 0;

sub _singleton {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

my $SINGLETON = Liquid::Failover::Config->_singleton();

sub getConfig() {
    return $SINGLETON;
}

sub getLiquidHome {
    return $LIQUID_HOME;
}

sub getAdminSOAPPort() {
    _init();
    return $HEARTBEAT_CONFIG{ADMIN_SOAP_PORT};
}

sub getUserSOAPPort() {
    _init();
    return $HEARTBEAT_CONFIG{USER_SOAP_PORT};
}

sub getCurrentRole() {
    _init();
    return $HEARTBEAT_CONFIG{CURRENT_ROLE};
}

sub serialHeartbeatEnabled {
    _init();
    return $HEARTBEAT_CONFIG{SERIAL_ENABLED};
}

sub tcpHeartbeatEnabled {
    _init();
    return $HEARTBEAT_CONFIG{TCP_ENABLED};
}

sub autoFailoverEnabled {
    _init();
    return $HEARTBEAT_CONFIG{AUTO_FAILOVER};
}

sub getSerialDevice {
    _init();
    return $HEARTBEAT_CONFIG{SERIAL_DEVICE};
}

sub getPeerIP {
    _init();
    return $HEARTBEAT_CONFIG{PEER_IPADDR};
}

sub getHeartbeatTcpPort {
    _init();
    return $HEARTBEAT_CONFIG{HEARTBEAT_TCP_PORT};
}

sub getHeartbeatInterval {
    _init();
    return $HEARTBEAT_CONFIG{HEARTBEAT_INTERVAL};
}

sub getHeartbeatMaxFailures {
    _init();
    return $HEARTBEAT_CONFIG{HEARTBEAT_MAX_FAILURES};
}

sub getServiceInterface {
    _init();
    return $HEARTBEAT_CONFIG{SERVICE_INTERFACE};
}

sub getServiceIP {
    _init();
    return $HEARTBEAT_CONFIG{SERVICE_IPADDR};
}

sub getRouterIP {
    _init();
    return $HEARTBEAT_CONFIG{ROUTER_IPADDR};
}

sub getLocalIP {
    _init();
    return $HEARTBEAT_CONFIG{LOCAL_IPADDR};
}

sub refresh {
    my $localhost = Liquid::Failover::Bootstrap::getHostname();
    my $ldap = new Liquid::Failover::LDAP();
    $ldap->bind() or return;
    my $confref = $ldap->getServerByName($localhost);
    if (!defined($confref)) {
        $ldap->unbind();
        return;
    }


    # Convert LDAP attributes into our own hash values.

    $HEARTBEAT_CONFIG{CURRENT_ROLE} =
        lc($confref->{uc('liquidReplicationCurrentRole')} || 'standalone');

    my $method = $confref->{uc('liquidHeartbeatMethod')};
    if (defined($method)) {
        $method = lc($method);
        my ($serial, $tcp) = (0, 0);
        if ($method eq 'serial') {
            ($serial, $tcp) = (1, 0);
        } elsif ($method eq 'tcp') {
            ($serial, $tcp) = (0, 1);
        } elsif ($method eq 'both') {
            ($serial, $tcp) = (1, 1);
        }
        $HEARTBEAT_CONFIG{SERIAL_ENABLED} = $serial;
        $HEARTBEAT_CONFIG{TCP_ENABLED} = $tcp;
    }

    $HEARTBEAT_CONFIG{AUTO_FAILOVER} =
        $confref->{uc('liquidHeartbeatAutomaticFailoverEnabled')} ? 1 : 0;

    $HEARTBEAT_CONFIG{SERIAL_DEVICE} =
        $confref->{uc('liquidHeartbeatSerialDevice')} || '/dev/ttyS0';

    $HEARTBEAT_CONFIG{HEARTBEAT_TCP_PORT} =
        $confref->{uc('liquidHeartbeatTcpPort')} || 7778;

    $HEARTBEAT_CONFIG{HEARTBEAT_INTERVAL} =
        $confref->{uc('liquidHeartbeatIntervalSec')} || 10;

    $HEARTBEAT_CONFIG{HEARTBEAT_MAX_FAILURES} =
        $confref->{uc('liquidHeartbeatMaxFailures')} || 6;

    $HEARTBEAT_CONFIG{LOCAL_IPADDR} =
        $confref->{uc('liquidServerIP')};

    $HEARTBEAT_CONFIG{SERVICE_INTERFACE} =
        $confref->{uc('liquidServiceIPInterface')};

    $HEARTBEAT_CONFIG{SERVICE_IPADDR} =
        $confref->{uc('liquidServiceIP')};

    $HEARTBEAT_CONFIG{ROUTER_IPADDR} =
        $confref->{uc('liquidServiceIPRouterIP')};

    # Get peer IP.
    my $peerId = $confref->{uc('liquidReplicationPeerId')};
    if (!defined($peerId)) {
        print STDERR "No replication peer defined\n";
    } else {
        my $peerref = $ldap->getServerById($peerId);
        if (defined($peerref)) {
            $HEARTBEAT_CONFIG{PEER_IPADDR} = $peerref->{uc('liquidServerIP')};
        }
    }

    $CONFIG_READ = 1;
    $ldap->unbind();
}

sub _init() {
    if (!$CONFIG_READ) {
        refresh();
    }
}

sub _getConfiguredHostname() {
    return Liquid::Failover::Bootstrap::getHostname();
}

1;
