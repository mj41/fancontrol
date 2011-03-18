#!perl

use strict;

use Getopt::Long;
use Pod::Usage;
use Daemon::Daemonize qw/:all/;

my $help = 0;
my $ver = 2;
my $daemon_start = 0;
my $daemon_stop = 0;
my $pidfile = '/var/run/fancontrol-perl.pid';
my $options_ok = GetOptions(
    'daemon-start' => \$daemon_start,
    'daemon-stop' => \$daemon_stop,
    'pidfile=s' => \$pidfile,
    'help|h|?' => \$help,
    'ver|v=i' => \$ver,
);

pod2usage(1) if $help || !$options_ok;



use Data::Dumper;
use Carp qw(verbose carp croak);

sub get_file_content {
    my ( $fpath ) = @_;
    my $fh = undef;
    unless ( open($fh,'<',$fpath) ) {
        croak "Can't open '$fh' for read.'"; 
    }
    local $/ = undef;
    my $content = <$fh>;
    close $fh;
    print $content if $ver >= 8;
    return $content;
}


sub write_file_content {
    my ( $fpath, $content ) = @_;
    my $fh = undef;
    unless ( open($fh,'>',$fpath) ) {
        croak "Can't open '$fh' for write.'"; 
    }
    print $content if $ver >= 8;
    print $fh $content;
    close $fh or croak "$!";
    return 1;
}


sub parse_acpi_file {
    my ( $proc_fpath ) = @_;
    my $content = get_file_content( $proc_fpath );
    my @lines = split("\n", $content);
    my $data = {};
    foreach my $line ( @lines ) {
        my ( $id, $info_str, $desc_str ) = $line =~ /^([^\:]+)\:[\s\t]+([^\(]+)(.*)$/;
        print "||$id|| ||$info_str|| ||$desc_str|| ('$line')\n" if $ver >= 5;
        $info_str =~ s/^\s+//;
        $info_str =~ s/\s+$//;
        if ( exists $data->{$id} ) {
            if ( ref $data->{$id} ne 'HASH' ) {
                my $prev = $data->{$id};
                $data->{$id} = {};
                $data->{$id}->{ $prev } = 1;
            }
            $data->{$id}{$info_str} = 1;
        } else {
            $data->{$id} = $info_str;
        }
    }
    return $data;
}


sub set_fan_level {
    my ( $fan_proc_fpath, $level_str ) = @_;
    
    my $content = 'level ' . $level_str;
    return write_file_content( $fan_proc_fpath, $content );
}


# Main code.
my $main_sub = sub {
    my ( $conf ) = @_;

    my $fan_proc_fpath = '/proc/acpi/ibm/fan';
    my $temper_proc_fpath = '/proc/acpi/thermal_zone/THM0/temperature';

    my $do_loop = 1;
    my $rnum = 1;
    my $prev_tcpu = undef;
    my $prev_level = undef;
    while ( $do_loop ) {
        print "Run number: $rnum\n" if $ver >= 4;
        
        my $fan_data = parse_acpi_file( $fan_proc_fpath );
        print Dumper( $fan_data ) if $ver >= 4;
        unless ( exists $fan_data->{commands} ) {
            croak "Can't find any commands inside '$fan_proc_fpath'. Did you set 'modprobe thinkpad-acpi experimental=1 fan_control=1'?";
        }
        unless ( exists $fan_data->{commands}->{'level <level>'} ) {
            croak "Can't find command 'level <level>' inside '$fan_proc_fpath'.";
        }

        my $temper_data = parse_acpi_file( $temper_proc_fpath );
        print Dumper( $temper_data ) if $ver >= 4;
        unless ( exists $temper_data->{temperature} ) {
            croak "Can't find temperature key inside '$temper_proc_fpath'.";
        }
        my $temper_str = $temper_data->{temperature};
        my ( $tcpu, $suffix ) = $temper_str =~ /^(\d+)\s+(C)$/;
        unless ( $tcpu ) {
            croak "Can't parse temperature value '$temper_str'.";
        }
        print "CPU temperature: $tcpu (degree Celsia)\n" if $ver >= 4;
        $prev_tcpu = $tcpu unless defined $prev_tcpu;
        
        my $trend = 'same';
        if ( $tcpu > $prev_tcpu ) {
            $trend = 'up'; # rising
        } elsif ( $tcpu < $prev_tcpu ) {
            $trend = 'down'; # failing
        }
        
        #    up     level    down (or first run)
        #  <=48       0   - <=46 down 
        #   >49 up -  1   - <=48 down
        #   >53 up -  2   - <=52 down
        #   >56 up - auto - >=53 down
        
        my $new_level = 'auto';

        # rising
        if ( $trend eq 'up' ) {
            if ( $tcpu > 56 ) {
                $new_level = 'auto';
            } elsif ( $tcpu > 53 ) {
                $new_level = '2';
            } elsif ( $tcpu > 49 ) {
                $new_level = '1';
            } else {
                $new_level = '0';
            }

        # failing or first run 
        } elsif ( $trend eq 'down' || $rnum == 1 ) {
            if ( $tcpu <= 46 ) {
                $new_level = '0';
            } elsif ( $tcpu <= 48 ) {
                $new_level = '1';
            } elsif ( $tcpu <= 52 ) {
                $new_level = '2';
            } else {
                $new_level = 'auto';
            }
        
        # same - not changed
        } else {
            $new_level = $fan_data->{level};
        }
        
        print "trend: $trend\n" if $ver >= 4;
        if ( $rnum == 1 ) {
            print "Actual temperature $tcpu, level $fan_data->{level}.\n" if $ver >= 3;
        }
        if ( $new_level ne $fan_data->{level} ) {
            print "Setting level to '$new_level' ($tcpu C), previous level was '$fan_data->{level}' ($prev_tcpu C). Trend is '$trend'.\n" if $ver >= 2;
            set_fan_level( $fan_proc_fpath, $new_level );
        
        } elsif ( $tcpu ne $prev_tcpu ) {
            print "New CPU temperature $tcpu.\n" if $ver >= 3;
        }
        
        sleep 30;
        $rnum++;
        $prev_tcpu = $tcpu;
    }

};



if ( !$daemon_start && !$daemon_stop ) {
    $main_sub->();
    exit;
}


# Return the pid from $pidfile if it contains a pid AND
# the process is running (even if you don't own it), 0 otherwise
my $pid = check_pidfile( $pidfile );

if ( $daemon_stop ) {
    my $ok = kill 1, $pid;
    if ( $ok ) {
        print "Fancontrol daemon stopped.\n" if $ver >= 2;
    } else {
        print "Can't kill process $pid. Try command\nkill -9 $pid\nfrom your console.\n" if $ver >= 1;
    }
    exit;
}


print "Setting verbose level to 0.\n" if $ver > 0;
$ver = 0;

if ( $pid ) {
    print "Can't start. Already running as daemon (pid $pid, pidfile '$pidfile').\n";

} else {
    daemonize(
        run => sub {
            write_pidfile( $pidfile );
            $SIG{INT} = sub { delete_pidfile( $pidfile ) };
            $main_sub->();
        }
    );
	print "Daemon starter (cat '$pidfile').\n";
}


=head1 NAME

fancontrol - Controlling fan speed by CPU temperature.

=head1 SYNOPSIS

perl daemonize.pl [options]

 Options:
   --daemon-start .. Run fancontrol as daemon.
   --daemon-stop .. Stop fancontrol daemon.
   --pidfile .. Path to pid file.
   --help
   --ver=$NUM .. Verbosity level. Default 2.

=head1 DESCRIPTION

B<This program> will ...

=cut
