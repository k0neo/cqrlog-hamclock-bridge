# Building HamClock with DX Callsign Support

The CQRLOG-to-HamClock bridge requires a modified HamClock
that accepts the `dxcall` parameter in `/set_newdx` and displays
the contacted callsign beside the green DX marker.

Two source patches are provided:

- `0001-dx-callsign-marker.patch` adds the callsign API and rendering.
- `0002-gpsd-tpv-parser-fix.patch` corrects GPSD TPV parsing.

The GPSD patch is independent of the callsign enhancement.

## Tested source revision

Upstream repository:

https://github.com/openhamclock/hamclock

Commit:

    cefe16e7bce471279f9519f09e1bc4ad606bf2e0

The patches were generated against this revision.

## Obtain the source

    git clone https://github.com/openhamclock/hamclock.git
    cd hamclock

    git checkout cefe16e7bce471279f9519f09e1bc4ad606bf2e0

## Apply the patches

From the root of the HamClock source repository:

    git apply /path/to/0001-dx-callsign-marker.patch

For installations requiring the GPSD correction:

    git apply /path/to/0002-gpsd-tpv-parser-fix.patch

Verify the changes:

    git diff --check
    git diff --stat

## Compile

On the tested Raspberry Pi installation:

    cd ESPHamClock

    make -j4 B=hamclock.com:80 hamclock-1600x960

This builds the 1600x960 X11 executable using the specified
HamClock backend.

Other display resolutions and platforms may require different
build targets or dependencies.

## Install

Close the running HamClock application before replacing its
production executable.

For an existing installation at /usr/local/bin/hamclock:

    sudo cp -p /usr/local/bin/hamclock \
        /usr/local/bin/hamclock.pre-dxcall

Install the newly compiled executable while preserving the
ownership and permission requirements of the local installation.

For the tested installation, which already used root ownership
and mode 4755:

    sudo install -o root -g root -m 4755 \
        hamclock-1600x960 /usr/local/bin/hamclock

Mode 4755 grants setuid-root execution privileges. Do not use
it on installations that do not require those privileges.

## Verify the DX callsign endpoint

Launch the installed HamClock application, then run:

    curl -fsS -G \
      --data-urlencode 'grid=FN31pr' \
      --data-urlencode 'dxcall=W1AW' \
      'http://HAMCLOCK_HOST:8080/set_newdx'

Replace HAMCLOCK_HOST with the address of your HamClock server.

The DX marker should move to FN31 and display W1AW beside
the green marker.

## GPSD correction

The optional GPSD patch corrects handling of GPSD response
lines in gpsd.cpp.

It was tested using a Raspberry Pi HamClock installation
connected to a remote GPSD server.

The fix prevents stale buffer contents from interfering
with the detection of GPSD TPV messages.

## Notes

The source modifications are based on openhamclock/hamclock.
Review the upstream project's license when redistributing
modified HamClock source or binaries.
