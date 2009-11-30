package HP::Proliant;

use strict;
use Nagios::Plugin;
use Data::Dumper;

our @ISA = qw(HP::Server);

sub init {
  my $self = shift;
  $self->{components} = {
      powersupply_subsystem => undef,
      fan_subsystem => undef,
      temperature_subsystem => undef,
      cpu_subsystem => undef,
      memory_subsystem => undef,
      disk_subsystem => undef,
  };
  $self->{serial} = 'unknown';
  $self->{product} = 'unknown';
  $self->{romversion} = 'unknown';
  $self->collect();
  if (! $self->{runtime}->{plugin}->check_messages() && 
      ! exists $self->{noinst_hint}) {
    $self->set_serial();
    $self->check_for_buggy_firmware();
    $self->analyze_cpus();
    $self->analyze_powersupplies();
    $self->analyze_fan_subsystem();
    $self->analyze_temperatures();
    $self->analyze_memory_subsystem();
    $self->analyze_disk_subsystem();
    $self->check_cpus();
    $self->check_powersupplies();
    $self->check_fan_subsystem();
    $self->check_temperatures();
    $self->check_memory_subsystem();
    $self->check_disk_subsystem();
  }
}

sub identify {
  my $self = shift;
  return sprintf "System: '%s', S/N: '%s', ROM: '%s'", 
      $self->{product}, $self->{serial}, $self->{romversion};
}

sub check_for_buggy_firmware {
  my $self = shift;
  my @buggyfirmwares = (
      "P24 12/11/2001",
      "P24 11/15/2002",
      "D13 06/03/2003",
      "D13 09/15/2004",
      "P20 12/17/2002"
  );
  $self->{runtime}->{options}->{buggy_firmware} =
      grep /^$self->{romversion}/, @buggyfirmwares;
}

sub dump {
  my $self = shift;
  printf STDERR "serial %s\n", $self->{serial};
  printf STDERR "product %s\n", $self->{product};
  printf STDERR "romversion %s\n", $self->{romversion};
  printf STDERR "%s\n", Data::Dumper::Dumper($self->{components});
}

sub analyze_powersupplies {
  my $self = shift;
  $self->{components}->{powersupply_subsystem} =
      HP::Proliant::Component::PowersupplySubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_fan_subsystem {
  my $self = shift;
  $self->{components}->{fan_subsystem} = 
      HP::Proliant::Component::FanSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_temperatures {
  my $self = shift;
  $self->{components}->{temperature_subsystem} = 
      HP::Proliant::Component::TemperatureSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_cpus {
  my $self = shift;
  $self->{components}->{cpu_subsystem} =
      HP::Proliant::Component::CpuSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_memory_subsystem {
  my $self = shift;
  $self->{components}->{memory_subsystem} = 
      HP::Proliant::Component::MemorySubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_disk_subsystem {
  my $self = shift;
  $self->{components}->{disk_subsystem} =
      HP::Proliant::Component::DiskSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub check_cpus {
  my $self = shift;
  $self->{components}->{cpu_subsystem}->check();
  $self->{components}->{cpu_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_powersupplies {
  my $self = shift;
  $self->{components}->{powersupply_subsystem}->check();
  $self->{components}->{powersupply_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_fan_subsystem {
  my $self = shift;
  $self->{components}->{fan_subsystem}->check();
  $self->{components}->{fan_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_temperatures {
  my $self = shift;
  $self->{components}->{temperature_subsystem}->check();
  $self->{components}->{temperature_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_memory_subsystem {
  my $self = shift;
  $self->{components}->{memory_subsystem}->check();
  $self->{components}->{memory_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_disk_subsystem {
  my $self = shift;
  $self->{components}->{disk_subsystem}->check();
  $self->{components}->{disk_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
  # zum anhaengen an die normale ausgabe... da: 2 logical drives, 5 physical...
  $self->{runtime}->{plugin}->add_message(OK,
      $self->{components}->{disk_subsystem}->{summary})
      if $self->{components}->{disk_subsystem}->{summary};
}


package HP::Proliant::CLI;

use strict;
use Nagios::Plugin;

our @ISA = qw(HP::Proliant);

sub collect {
  my $self = shift;
  my $hpasmcli = undef;
  if (($self->{runtime}->{plugin}->opts->hpasmcli) &&
      (-f $self->{runtime}->{plugin}->opts->hpasmcli) &&
      (! -x $self->{runtime}->{plugin}->opts->hpasmcli)) {
    no strict 'refs';
    open(BIRK, $self->{runtime}->{plugin}->opts->hpasmcli);
    # all output in one file prefixed with server|powersupply|fans|temp|dimm
    while(<BIRK>) {
      chomp;
      $self->{rawdata} .= $_."\n";
    }
    close BIRK;
    my $diag = <<'EOEO';
    hpasmcli=$(which hpasmcli)
    hpacucli=$(which hpacucli)
    for i in server powersupply fans temp dimm
    do
      $hpasmcli -s "show $i" | while read line
      do
        printf "%s %s\n" $i "$line"
      done
    done 
    if [ -x "$hpacucli" ]; then
      for i in config status
      do
        $hpacucli ctrl all show $i | while read line
        do
          printf "%s %s\n" $i "$line"
        done
      done
    fi
EOEO
  } else {
    #die "exec hpasmcli";
    # alles einsammeln und in rawdata stecken
    my $hpasmcli = undef;
    if  (($self->{runtime}->{plugin}->opts->hpasmcli) &&
        (-x $self->{runtime}->{plugin}->opts->hpasmcli)) {
      $hpasmcli = $self->{runtime}->{plugin}->opts->hpasmcli;
    } elsif (-x '/sbin/hpasmcli') {
        $hpasmcli = '/sbin/hpasmcli';
    }
    if ($hpasmcli) {
      if ($< != 0) {
        $hpasmcli = "sudo ".$hpasmcli;
      }
      $self->check_daemon();
      if (! $self->{runtime}->{plugin}->check_messages()) {
        $self->check_hpasm_client($hpasmcli);
        if (! $self->{runtime}->{plugin}->check_messages()) {
          foreach my $component (qw(server fans temp dimm)) {
            if (open HPASMCLI, "$hpasmcli -s \"show $component\"|") {
              my @output = <HPASMCLI>;
              close HPASMCLI;
              $self->{rawdata} .= join("\n", map {
                  $component.' '.$_;
              } @output);
            }
          }
          if ($self->{runtime}->{options}->{hpacucli}) { 
            #1 oder 0. pfad selber finden
            my $hpacucli = undef;
            if (-x '/usr/sbin/hpacucli') {
              $hpacucli = '/usr/sbin/hpacucli';
            } elsif (-x '/usr/local/sbin/hpacucli') {
              $hpacucli = '/usr/local/sbin/hpacucli';
            } else {
              $hpacucli = $hpasmcli;
              $hpacucli =~ s/^sudo\s*//;
              $hpacucli =~ s/hpasmcli/hpacucli/;
              $hpacucli = $hpacucli if -x $hpacucli;
            }
            if ($hpacucli) {
              if ($< != 0) {
                $hpacucli = "sudo ".$hpacucli;
              }
              $self->check_hpacu_client($hpacucli);
              if (! $self->{runtime}->{plugin}->check_messages()) {
                if (open HPACUCLI, "$hpacucli ctrl all show config 2>&1|") {
                  my @output = <HPACUCLI>;
                  close HPACUCLI;
                  $self->{rawdata} .= join("\n", map {
                      'config '.$_;
                  } @output);
                }
                if (open HPACUCLI, "$hpacucli ctrl all show status 2>&1|") {
                  my @output = <HPACUCLI>;
                  close HPACUCLI;
                  $self->{rawdata} .= join("\n", map {
                      'status '.$_;
                  } @output);
                }
              }
            } else {
              if ($self->{runtime}->{options}->{noinstlevel} eq 'ok') {
                $self->add_message(OK,
                    'hpacucli is not installed. let\'s hope the best...');
              } else {
                $self->add_message(
                    uc $self->{runtime}->{options}->{noinstlevel},
                    'hpasm is not installed.');
              }
            }
          }
        }
      }
    } else {
      if ($self->{runtime}->{options}->{noinstlevel} eq 'ok') {
        $self->add_message(OK,
            'hpasm is not installed. let\'s hope the best...');
        $self->{noinst_hint} = 1;
      } else {
        $self->add_message(uc $self->{runtime}->{options}->{noinstlevel},
            'hpasm is not installed.');
      }
    }
  }
}

sub check_daemon {
  my $self = shift;
  my $multiproc_os_signatures_files = {
      '/etc/SuSE-release' => 'VERSION\s*=\s*8',
      '/etc/trustix-release' => '.*',
      '/etc/redhat-release' => '.*Pensacola.*',
      '/etc/debian_version' => '3\.1',
      '/etc/issue' => '.*Kernel 2\.4\.9-vmnix2.*', # VMware ESX Server 2.5.4
  };
  if (open PS, "/bin/ps -e -ocmd|") {
    my $numprocs = 0;
    my $numcliprocs = 0;
    my @procs = <PS>;
    close PS;
    $numprocs = grep /hpasm.*d$/, map { (split /\s+/, $_)[0] } @procs;
    $numcliprocs = grep /hpasmcli/, grep !/check_hpasm/, @procs;
    if (! $numprocs ) {
      $self->add_message(CRITICAL, 'hpasmd needs to be restarted');
    } elsif ($numprocs > 1) {
      my $known = 0;
      foreach my $osfile (keys %{$multiproc_os_signatures_files}) {
        if (-f $osfile) {
          open OSSIG, $osfile;
          if (grep /$multiproc_os_signatures_files->{$osfile}/, <OSSIG>) {
            $known = 1;
          }
          close OSSIG;
        }
      }
      if (! $known) {
        $self->add_message(UNKNOWN, 'multiple hpasmd procs');
      }
    }
    if ($numcliprocs == 1) {
      $self->add_message(UNKNOWN, 'another hpasmdcli is running');
    } elsif ($numcliprocs > 1) {
      $self->add_message(UNKNOWN, 'hanging hpasmdcli processes');
    }
  }
}

sub check_hpasm_client {
  my $self = shift;
  my $hpasmcli = shift;
  if (open HPASMCLI, "$hpasmcli -s help 2>&1 |") {
    my @output = <HPASMCLI>;
    close HPASMCLI;
    if (grep /Could not communicate with hpasmd/, @output) {
      $self->add_message(CRITICAL, 'hpasmd needs to be restarted');
    } elsif (grep /(asswor[dt]:)|(You must be root)/, @output) {
      $self->add_message(UNKNOWN,
          sprintf "insufficient rights to call %s", $hpasmcli);
    } elsif (grep /must have a tty/, @output) {
      $self->add_message(CRITICAL,
          'sudo must be configured with requiretty=no (man sudo)');
    } elsif (! grep /CLEAR/, @output) {
      $self->add_message(UNKNOWN,
          sprintf "insufficient rights to call %s", $hpasmcli);
    }
  } else {
    $self->add_message(UNKNOWN,
        sprintf "insufficient rights to call %s", $hpasmcli);
  }
}

sub check_hpacu_client {
  my $self = shift;
  my $hpacucli = shift;
  if (open HPACUCLI, "$hpacucli help 2>&1 |") {
    my @output = <HPACUCLI>;
    close HPACUCLI;
    if (grep /Another instance of hpacucli is running/, @output) {
      $self->add_message(UNKNOWN, 'another hpacucli is running');
    } elsif (grep /You need to have administrator rights/, @output) {
      $self->add_message(UNKNOWN,
          sprintf "insufficient rights to call %s", $hpacucli);
    } elsif (grep /(asswor[dt]:)|(You must be root)/, @output) {
      $self->add_message(UNKNOWN,
          sprintf "insufficient rights to call %s", $hpacucli);
    } elsif (! grep /CLI Syntax/, @output) {
      $self->add_message(UNKNOWN,
          sprintf "insufficient rights to call %s", $hpacucli);
    }
  } else {
    $self->add_message(UNKNOWN,
        sprintf "insufficient rights to call %s", $hpacucli);
  }
}

sub set_serial {
  my $self = shift;
  foreach (grep(/^server/, split(/\n/, $self->{rawdata}))) {
    if (/System\s+:\s+(.*[^\s])/) {
      $self->{product} = lc $1;
    } elsif (/Serial No\.\s+:\s+(\w+)/) {
      $self->{serial} = $1;
    } elsif (/ROM version\s+:\s+(.*[^\s])/) {
      $self->{romversion} = $1;
    }
  }
  $self->{serial} = $self->{serial};
  $self->{product} = lc $self->{product};
  $self->{romversion} = $self->{romversion};
}


package HP::Proliant::SNMP;

use strict;
use Nagios::Plugin;

our @ISA = qw(HP::Proliant);

sub collect {
  my $self = shift;
  if ($self->{runtime}->{plugin}->opts->snmpwalk) {
    my $cpqSeMibCondition = '1.3.6.1.4.1.232.1.1.3.0'; # 2=ok
    my $cpqHeMibCondition = '1.3.6.1.4.1.232.6.1.3.0'; # hat nicht jeder
    if ($self->{productname} =~ /4LEE/) {
      # rindsarsch!
      $self->{rawdata}->{$cpqHeMibCondition} = 0;
    }
    if (! exists $self->{rawdata}->{$cpqHeMibCondition} &&
        ! exists $self->{rawdata}->{$cpqSeMibCondition}) { # vlt. geht doch was
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cpqhlth-mib)');
    }
  } else {
    my $net_snmp_version = Net::SNMP->VERSION(); # 5.002000 or 6.000000
    #$params{'-translate'} = [
    #  -all => 0x0
    #];
    my ($session, $error) = 
        Net::SNMP->session(%{$self->{runtime}->{snmpparams}});
    if (! defined $session) {
      $self->{plugin}->add_message(CRITICAL, 'cannot create session object');
      $self->trace(1, Data::Dumper::Dumper($self->{runtime}->{snmpparams}));
    } else {
      # revMajor is often used for discovery of hp devices
      my $cpqHeMibRev = '1.3.6.1.4.1.232.6.1';
      my $cpqHeMibRevMajor = '1.3.6.1.4.1.232.6.1.1.0';
      my $cpqHeMibCondition = '1.3.6.1.4.1.232.6.1.3.0';
      my $result = $session->get_request(
          -varbindlist => [$cpqHeMibCondition]
      );
      if ($self->{productname} =~ /4LEE/) {
        # rindsarsch!
        $result->{$cpqHeMibCondition} = 0;
      }
      if (!defined($result) || 
          $result->{$cpqHeMibCondition} eq 'noSuchInstance' ||
          $result->{$cpqHeMibCondition} eq 'noSuchObject' ||
          $result->{$cpqHeMibCondition} eq 'endOfMibView') {
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cpqhlth-mib)');
        $session->close;
      } else {
        # this is not reliable. many agents return 4=failed
        #if ($result->{$cpqHeMibCondition} != 2) {
        #  $obstacle = "cmapeerstart";
        #}
      }
    }
    if (! $self->{runtime}->{plugin}->check_messages()) {
      # snmp peer is alive
      $self->trace(2, sprintf "Protocol is %s", 
          $self->{runtime}->{snmpparams}->{'-version'});
      my $cpqStdEquipment = "1.3.6.1.4.1.232";
      my $cpqSeProcessor =  "1.3.6.1.4.1.232.1.2.2";
      my $cpqSeRom =        "1.3.6.1.4.1.232.1.2.6";
      my $cpqHeComponent =  "1.3.6.1.4.1.232.6.2";
      my $cpqHePComponent = "1.3.6.1.4.1.232.6.2.9";
      my $cpqHeFComponent = "1.3.6.1.4.1.232.6.2.6.7";
      my $cpqHeTComponent = "1.3.6.1.4.1.232.6.2.6.8";
      my $cpqHeMComponent = "1.3.6.1.4.1.232.6.2.14";
      my $cpqDaComponent =  "1.3.6.1.4.1.232.3.2";
      my $cpqSasComponent =  "1.3.6.1.4.1.232.5";
      my $cpqIdeComponent =  "1.3.6.1.4.1.232.14";
      my $cpqFcaComponent =  "1.3.6.1.4.1.232.16.2";
      my $cpqSiComponent =  "1.3.6.1.4.1.232.2.2";
      $session->translate;
      my $response = {}; #break the walk up in smaller pieces
      my $tic = time; my $tac = $tic;
      my $response1 = $session->get_table(
          -baseoid => $cpqSeProcessor);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqSeProcessor (%d oids)",
          $tac - $tic, scalar(keys %{$response1}));
      # Walk for PowerSupply
      $tic = time;
      my $response2p = $session->get_table(
          -maxrepetitions => 1,
          -baseoid => $cpqHePComponent);
      if (scalar (keys %{$response2p}) == 0) {
        $self->trace(2, sprintf "maxrepetitions failed. fallback");
        $response2p = $session->get_table(
            -baseoid => $cpqHePComponent);
      }
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqHePComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response2p}));
      # Walk for Fans
      $tic = time;
      my $response2f = $session->get_table(
          -maxrepetitions => 1,
          -baseoid => $cpqHeFComponent);
      if (scalar (keys %{$response2f}) == 0) {
        $self->trace(2, sprintf "maxrepetitions failed. fallback");
        $response2f = $session->get_table(
            -baseoid => $cpqHeFComponent);
      }
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqHeFComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response2f}));
      # Walk for Temp
      $tic = time;
      my $response2t = $session->get_table(
          -maxrepetitions => 1,
          -baseoid => $cpqHeTComponent);
      if (scalar (keys %{$response2t}) == 0) {
        $self->trace(2, sprintf "maxrepetitions failed. fallback");
        $response2t = $session->get_table(
            -baseoid => $cpqHeTComponent);
      }
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqHeTComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response2t}));
      # Walk for Mem
      $tic = time;
      my $response2m = $session->get_table(
          -maxrepetitions => 1,
          -baseoid => $cpqHeMComponent);
      if (scalar (keys %{$response2m}) == 0) {
        $self->trace(2, sprintf "maxrepetitions failed. fallback");
        $response2m = $session->get_table(
            -baseoid => $cpqHeMComponent);
      }
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqHeMComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response2m}));
      #
      $tic = time;
      my $response3 = $session->get_table(
          -baseoid => $cpqDaComponent);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqDaComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response3}));
      $tic = time;
      my $response4 = $session->get_table(
          -baseoid => $cpqSiComponent);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqSiComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response4}));
      $tic = time;
      my $response5 = $session->get_table(
          -baseoid => $cpqSeRom);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqSeRom (%d oids)",
          $tac - $tic, scalar(keys %{$response5}));
      $tic = time;
      my $response6 = $session->get_table(
          -baseoid => $cpqSasComponent);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqSasComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response6}));
      $tic = time;
      my $response7 = $session->get_table(
          -baseoid => $cpqIdeComponent);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqIdeComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response7}));
      $tic = time;
      my $response8 = $session->get_table(
          -baseoid => $cpqFcaComponent);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqFcaComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response8}));
      $tic = time;
      $session->close;
      map { $response->{$_} = $response1->{$_} } keys %{$response1};
      map { $response->{$_} = $response2p->{$_} } keys %{$response2p};
      map { $response->{$_} = $response2f->{$_} } keys %{$response2f};
      map { $response->{$_} = $response2t->{$_} } keys %{$response2t};
      map { $response->{$_} = $response2m->{$_} } keys %{$response2m};
      map { $response->{$_} = $response3->{$_} } keys %{$response3};
      map { $response->{$_} = $response4->{$_} } keys %{$response4};
      map { $response->{$_} = $response5->{$_} } keys %{$response5};
      map { $response->{$_} = $response6->{$_} } keys %{$response6};
      map { $response->{$_} = $response7->{$_} } keys %{$response7};
      map { $response->{$_} = $response8->{$_} } keys %{$response8};
      map { $response->{$_} =~ s/^\s+//; $response->{$_} =~ s/\s+$//; }
          keys %$response;
      $self->{rawdata} = $response;
    }
  }
  return $self->{runtime}->{plugin}->check_messages();
}

sub set_serial {
  my $self = shift;

  my $cpqSiSysSerialNum = "1.3.6.1.4.1.232.2.2.2.1.0";
  my $cpqSiProductName = "1.3.6.1.4.1.232.2.2.4.2.0";
  my $cpqSeSysRomVer = "1.3.6.1.4.1.232.1.2.6.1.0";

  $self->{serial} = 
      SNMP::Utils::get_object($self->{rawdata}, $cpqSiSysSerialNum);
  $self->{product} =
      SNMP::Utils::get_object($self->{rawdata}, $cpqSiProductName);
  $self->{romversion} =
      SNMP::Utils::get_object($self->{rawdata}, $cpqSeSysRomVer);
  if ($self->{romversion} && $self->{romversion} =~
      #/(\d{2}\/\d{2}\/\d{4}).*?([ADP]{1}\d{2}).*/) {
      /(\d{2}\/\d{2}\/\d{4}).*?Family.*?([A-Z]{1})(\d+).*/) {
    $self->{romversion} = sprintf("%s%02d %s", $2, $3, $1);
  } elsif ($self->{romversion} && $self->{romversion} =~
      /([ADP]{1}\d{2})\-(\d{2}\/\d{2}\/\d{4})/) {
    $self->{romversion} = sprintf("%s %s", $1, $2);
  }
  if (!$self->{serial} && $self->{romversion}) {
    # this probably is a very, very old server.
    $self->{serial} = "METHUSALEM";
    $self->{runtime}->{scrapiron} = 1;
  }
  $self->{serial} = $self->{serial};
  $self->{product} = lc $self->{product};
  $self->{romversion} = $self->{romversion};
  $self->{runtime}->{product} = $self->{product};
}


1;
