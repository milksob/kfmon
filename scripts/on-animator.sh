#!/bin/sh

# Launch KFMon if it isn't already running...
KFMON_LOG="/usr/local/kfmon/kfmon.log"
if ! pkill -0 kfmon ; then
	echo "[START] [$(date +'%Y-%m-%d @ %H:%M:%S')] [INFO] [PID: $$] Starting KFMon . . ." >> "${KFMON_LOG}"
	KFMON_BIN="/usr/local/kfmon/bin/kfmon"
	if [ -x "${KFMON_BIN}" ] ; then
		LIBC_FATAL_STDERR_=1 "${KFMON_BIN}" &
		# NOTE: The PID shown here is not terribly helpful, since the first thing KFMon will do will be to fork twice to daemonize...
		echo "[START] [$(date +'%Y-%m-%d @ %H:%M:%S')] [INFO] [PID: $$] Launched KFMon! (Initial PID: $!)" >> "${KFMON_LOG}"
	else
		echo "[START] [$(date +'%Y-%m-%d @ %H:%M:%S')] [ERR!] [PID: $$] KFMon binary '${KFMON_BIN}' cannot be executed!" >> "${KFMON_LOG}"
	fi
else
	# NOTE: I'm sometimes seeing wonky behavior after an update, where we trip the "already running" check when we actually *do* need to be launched...
	#       Possibly due to the specific timing at which on-animator runs around updates?
	echo "[START] [$(date +'%Y-%m-%d @ %H:%M:%S')] [WARN] [PID: $$] KFMon is already running (PID: $(pidof kfmon || echo 'N/A'))!" >> "${KFMON_LOG}"
fi

# Optionally, ditch the pickel progress bar for FBInk's, for shit'n giggles.
# (And also because eating > 50% CPU to draw a progress bar is ridiculous).
# NOTE: That CPU usage does have an impact on boot times.
#       As an example, on a H2O running FW 4.15, after a sync && reboot && exit over SSH:
#       It (roughly) takes: 10s to actually power cycle (the double screen flash), 25s to start showing the progress bar,
#                           37s for Nickel to show up.
#       Switching to FBInk shaves those timings down to 10s, 24s and 34s, which might seem small,
#       but relative to the amount of time on-animator actually runs, amounts to at least a 10% speedup...
#       And on a Forma (still on 4.15), it shaves those same timings from 7s, 14s, 28s down to 7s, 11s, 25s ;).
# NOTE: The new spinner introduced in FW 4.17 appears to be *slightly* more efficient, but is still far from optimal,
#       probably in part because of the overhead involved with zlib & piping all that data around.
#       I haven't bothered timing it again, though.

# NOTE: While this works as-is on current FW, this *may* be problematic on older FW,
#       where Nickel *might* have been relying on pickel to setup the fb...
#       This could probably be worked-around by shipping and using fbdepth like we do on KOReader,
#       (except only for the rotation, in order not to break old 16bpp only FW versions).
#       But other custom stuff that relies on the pickel setup would be left in the lurch regardless, though...
#       As that's a decision we'd be hard pressed to make on our own, leave this in the user's hands,
#       defaulting to a safe behavior (i.e., the vanilla progress bar).

# NOTE: Given when we're launched by rcS, we know onboard is mounted at that point
KFMON_BAR_FLAG="/mnt/onboard/.adds/kfmon/config/BAR"

if [ -f "${KFMON_BAR_FLAG}" ] ; then
	FBINK_SHIM_BIN="/usr/local/kfmon/bin/shim"

	# NOTE: There's a bit of trickery involved where we have to launch FBInk under the on-animator.sh process name,
	#       just so it gets killed when on-animator gets the axe,
	#       because that's done in a way we can't do anything about from here (SIGKILL, which isn't propagated, and isn't trappable).
	#       Ideally, we'd use exec -a, but busybox doesn't support that flag, so, instead,
	#       we exec a shim binary that just execs FBInk under a different process name,
	#       and with the relevant options for what we want to do...
	exec ${FBINK_SHIM_BIN}
else
	PRODUCT="$(/bin/sh /bin/kobo_config.sh)"
	[ "${PRODUCT}" != "trilogy" ] && PREFIX="${PRODUCT}-"

	i=0
	while true ; do
		i=$((((i + 1)) % 11))
		image="/etc/images/${PREFIX}on-${i}.raw.gz"
		if [ -s "${image}" ] ; then
			zcat "${image}" | /usr/local/Kobo/pickel showpic 1
			usleep 250000
		fi
	done
fi
