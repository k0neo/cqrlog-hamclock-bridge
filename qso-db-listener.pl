#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use HTTP::Tiny;
use File::Path qw(make_path);

$| = 1;

my $socket = $ENV{CQRLOG_SOCKET} // "$ENV{HOME}/.config/cqrlog/database/sock";
my $hamclock = $ENV{HAMCLOCK_URL} // 'http://127.0.0.1:8080';
my $poll_interval = $ENV{POLL_INTERVAL} // 2;
my $database = $ENV{CQRLOG_DATABASE} // 'cqrlog001';
my $db_user = $ENV{CQRLOG_DB_USER} // 'root';

my $state_dir = "$ENV{HOME}/.local/state/qso-db-listener";
my $state_file = "$state_dir/last-id";

make_path($state_dir);

sub save_state {
    my ($id) = @_;

    my $tmp = "$state_file.$$";

    open my $fh, '>', $tmp
        or die "Cannot write $tmp: $!\n";

    print {$fh} "$id\n"
        or die "Cannot write state: $!\n";

    close $fh
        or die "Cannot close state: $!\n";

    rename $tmp, $state_file
        or die "Cannot save state: $!\n";
}

my $dbh = DBI->connect(
    "DBI:mysql:database=$database;mysql_socket=$socket",
    $db_user,
    '',
    {
        RaiseError => 1,
        PrintError => 0,
        ReadOnly   => 1,
        AutoCommit => 1,
    }
) or die "Database connection failed: $DBI::errstr\n";

my $http = HTTP::Tiny->new(timeout => 5);

my $last_id;

if (-f $state_file) {
    open my $fh, '<', $state_file
        or die "Cannot read state: $!\n";

    $last_id = <$fh>;
    close $fh;

    chomp $last_id;

    die "Invalid state file\n"
        unless $last_id =~ /^\d+$/;

    print "Resuming after QSO ID $last_id\n";
}
else {
    ($last_id) = $dbh->selectrow_array(
        'SELECT COALESCE(MAX(id_cqrlog_main), 0) FROM cqrlog_main'
    );

    save_state($last_id);

    print "Initialized after QSO ID $last_id\n";
}

print "CQRLOG database connected\n";
print "Monitoring new contacts every $poll_interval seconds\n";

my $sth = $dbh->prepare(
    'SELECT id_cqrlog_main, callsign, loc
     FROM cqrlog_main
     WHERE id_cqrlog_main > ?
     ORDER BY id_cqrlog_main ASC'
);

while (1) {

    # A database or HTTP failure exits the process.
    # systemd will restart it and restore the saved ID.

    $sth->execute($last_id);

    while (my $row = $sth->fetchrow_hashref) {

        my $id   = $row->{id_cqrlog_main};
        my $call = uc($row->{callsign} // '');
        my $grid = uc($row->{loc} // '');

        $call =~ s/^\s+|\s+$//g;
        $grid =~ s/^\s+|\s+$//g;

        unless (
            $call =~ /^[A-Z0-9\/-]{3,20}$/
            &&
            $grid =~ /^[A-R]{2}[0-9]{2}(?:[A-X]{2})?$/
        ) {
            print "Skipping QSO $id: invalid or missing call/grid\n";

            save_state($id);
            $last_id = $id;
            next;
        }

        my $encoded_call = $call;
        $encoded_call =~ s{/}{%2F}g;

        my $url =
            "$hamclock/set_newdx?grid=$grid&dxcall=$encoded_call";

        my $response = $http->get($url);

        die "HamClock update failed for QSO $id: "
            . "$response->{status} $response->{reason}\n"
            unless $response->{success};

        save_state($id);
        $last_id = $id;

        print "QSO $id: $call ($grid) -> HamClock updated\n";
    }

    $sth->finish;

    sleep $poll_interval;
}
