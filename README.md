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

## Standalone QSO Globe operation

The listener supports portable operation without HamClock.

| Environment variable | Default |
|---|---|
| HAMCLOCK_ENABLED | 1 |
| QSO_GLOBE_ENABLED | 0 |
| QSO_GLOBE_PORT | 45832 |

Setting HAMCLOCK_ENABLED=0 disables HTTP initialization
and HamClock notifications while preserving database
monitoring, persistent state, and UDP notifications.

The default behavior remains backward compatible.

### System MariaDB configuration

Example systemd user service override:

    [Service]
    Environment=CQRLOG_SOCKET=/run/mysqld/mysqld.sock
    Environment=CQRLOG_DATABASE=cqrlog001
    Environment=CQRLOG_DB_USER=rbrown
    Environment=HAMCLOCK_ENABLED=0
    Environment=QSO_GLOBE_ENABLED=1
    Environment=QSO_GLOBE_PORT=45832
    Environment=POLL_INTERVAL=2

The database account must match the local installation.

UNIX socket authentication permits passwordless operation.
The listener requires SELECT privileges only on the
id_cqrlog_main, callsign, and loc columns of cqrlog_main.

### Verified deployment

Orion, Linux Mint 22.3, MariaDB 10.11.14,
QSO Globe 1.0.0.

Passwordless authentication, database query compatibility,
foreground execution, state persistence, and permanent
systemd user service startup have been verified.

Live contact processing is deferred until field operation.
HamClock-enabled runtime regression remains pending.

QSO Globe:
https://github.com/k0neo/qso-globe
