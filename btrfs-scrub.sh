#!/bin/bash
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.

umask 022
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

if [ -f /etc/sysconfig/btrfsmaintenance ] ; then
    . /etc/sysconfig/btrfsmaintenance
fi

if [ -f /etc/default/btrfsmaintenance ] ; then
    . /etc/default/btrfsmaintenance
fi

LOGIDENTIFIER='btrfs-scrub'
. $(dirname $(realpath "$0"))/btrfsmaintenance-functions

readonly=
if [ "$BTRFS_SCRUB_READ_ONLY" = "true" ]; then
	readonly=-r
fi

ioprio=
if [ "$BTRFS_SCRUB_PRIORITY" = "normal" ]; then
	# ionice(3) best-effort, level 4
	ioprio="-c 2 -n 4"
fi

{
BTRFS_SCRUB_MOUNTPOINTS=$(expand_auto_mountpoint "$BTRFS_SCRUB_MOUNTPOINTS")
OIFS="$IFS"
IFS=:
exec 2>&1 # redirect stderr to stdout to catch all output to log destination
for MNT in $BTRFS_SCRUB_MOUNTPOINTS; do
	IFS="$OIFS"
	echo "## Running scrub on $MNT"
	if ! is_btrfs "$MNT"; then
		echo "Path $MNT is not btrfs, skipping"
		continue
	fi
	for disk in $(btrfs filesystem show $MNT | awk '/path/ {print $NF}');do
	
  	echo -E "\n### For disk: $disk"
  	run_task btrfs scrub start -Bd $ioprio $readonly "$disk"
  done

	if [ "$?" != "0" ]; then
		echo "Scrub cancelled at $MNT"
		exit 1
	fi
done

} | \
case "$BTRFS_LOG_OUTPUT" in
	stdout) cat;;
	journal) systemd-cat -t "$LOGIDENTIFIER";;
	syslog) logger -t "$LOGIDENTIFIER";;
	none) cat >/dev/null;;
	*) cat;;
esac

exit 0
