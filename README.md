# CQRLOG to HamClock Bridge

A Perl daemon that monitors the CQRLOG MariaDB database for newly
logged amateur radio contacts and updates HamClock's DX marker.

The bridge sends the contacted station's Maidenhead grid square and
callsign to HamClock through its HTTP API.

## Features

- Detects newly logged QSOs without using CQRLOG's UDP export.
- Polls the database every two seconds by default.
- Validates callsigns and Maidenhead grid squares.
- Updates HamClock's DX marker and callsign.
- Preserves the last processed QSO ID across service restarts.
- Skips historical contacts on initial startup.
- Runs as a systemd user service.
- Restarts automatically after failures.

## Requirements

- Perl 5 with DBI and DBD::mysql
- Perl HTTP::Tiny and File::Path modules
- CQRLOG with its MariaDB database
- A reachable HamClock HTTP server
- HamClock with support for the `dxcall` parameter

The standard HamClock `/set_newdx` endpoint does not necessarily
support `dxcall`. The HamClock modification is separate from this
repository.

## Configuration

The following environment variables are supported:

| Variable | Default | Description |
|----------|---------|-------------|
| HAMCLOCK_URL | http://127.0.0.1:8080 | HamClock HTTP server |
| CQRLOG_SOCKET | ~/.config/cqrlog/database/sock | MariaDB Unix socket |
| CQRLOG_DATABASE | cqrlog001 | CQRLOG log database |
| CQRLOG_DB_USER | root | MariaDB username |
| POLL_INTERVAL | 2 | Polling interval in seconds |

The socket path is expanded from the user's HOME directory when
the environment variable is not supplied.

The current implementation connects to MariaDB as `root` using
the local Unix socket and an empty password. This matches the
tested CQRLOG embedded-database installation but may require
adaptation for other configurations.

## Installation

Copy the Perl script to:

    ~/bin/qso-db-listener.pl

Make it executable:

    chmod +x ~/bin/qso-db-listener.pl

Copy the systemd unit to:

    ~/.config/systemd/user/qso-db-listener.service

Configure the HamClock address using a systemd override:

    systemctl --user edit qso-db-listener.service

Add:

    [Service]
    Environment="HAMCLOCK_URL=http://192.168.0.89:8080"

Replace the example address with your HamClock server's address.

Enable and start the service:

    systemctl --user daemon-reload
    systemctl --user enable --now qso-db-listener.service

## Monitoring

    systemctl --user status qso-db-listener.service
    journalctl --user -u qso-db-listener.service -f

## Persistent state

The listener stores its last processed QSO ID in:

    ~/.local/state/qso-db-listener/last-id

On its first run, it initializes to the highest existing QSO ID,
preventing historical contacts from being replayed.

Afterward, it resumes from the saved ID following service restarts.

## Limitations

- Contacts without valid four- or six-character Maidenhead grids
  are skipped.
- The listener detects newly inserted records, not edits to
  existing records.
- It requires the CQRLOG MariaDB instance to be accessible.
- The current database connection is specific to the tested
  local CQRLOG configuration.
- HamClock must support the custom `dxcall` API parameter.

## Author

K0NEO

## HamClock source modifications

The bridge requires HamClock to support the custom `dxcall`
parameter in its `/set_newdx` HTTP endpoint.

The `patches/` directory contains:

- `0001-dx-callsign-marker.patch` — adds callsign handling and
  rendering beside the green DX marker.
- `0002-gpsd-tpv-parser-fix.patch` — fixes GPSD TPV parsing.
  This patch is independent of the callsign enhancement.

For the tested upstream source revision, patch application,
compilation, installation, and verification instructions, see
[Building HamClock with DX Callsign Support](docs/HAMCLOCK_BUILD.md).
