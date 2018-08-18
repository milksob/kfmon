#!/bin/sh
#
# Print the last ${LOG_LINES} lines of log on screen, with FBInk
#
##

# Pickup the FBInk binary we're shipping
FBINK_BIN="/usr/local/kfmon/bin/fbink"
# Where's our log?
KFMON_LOG="/usr/local/kfmon/kfmon.log"
# How many lines do we want to print?
# NOTE: Start high, we'll try to adjust it down to fit both the screen & the content later...
LOG_LINES="25"

# See how many lines we can actually print...
eval $(${FBINK_BIN} -qe)
# Try to account for linebreaks...
MAXCHARS="$(awk -v LOG_LINES=${LOG_LINES} -v MAXCOLS=${MAXCOLS} -v MAXROWS=${MAXROWS} 'BEGIN { print int(MAXCOLS * (MAXROWS - LOG_LINES)) }')"

# Check if we're logging to syslog instead...
KFMON_CFG="/mnt/onboard/.adds/kfmon/config/kfmon.ini"
if grep use_syslog "${KFMON_CFG}" | grep -q -i -e 1 -e "on" -e "true" -e "yes" ; then
	KFMON_USE_SYSLOG="true"
	# And see how many lines of that we can (roughly) print at most...
	while [ "$(logread | grep -e KFMon -e FBInk | tail -n ${LOG_LINES} | wc -c)" -gt "${MAXCHARS}" ] ; do
		let "LOG_LINES = ${LOG_LINES} - 1"
		# Amount of lines changed, update that!
		MAXCHARS="$(awk -v LOG_LINES=${LOG_LINES} -v MAXCOLS=${MAXCOLS} -v MAXROWS=${MAXROWS} 'BEGIN { print int(MAXCOLS * (MAXROWS - LOG_LINES)) }')"
	done
else
	KFMON_USE_SYSLOG="false"
	# And see how many lines of that we can (roughly) print at most...
	while [ "$(tail -n ${LOG_LINES} "${KFMON_LOG}" | wc -c)" -gt "${MAXCHARS}" ] ; do
		let "LOG_LINES = ${LOG_LINES} - 1"
		# Amount of lines changed, update that!
		MAXCHARS="$(awk -v LOG_LINES=${LOG_LINES} -v MAXCOLS=${MAXCOLS} -v MAXROWS=${MAXROWS} 'BEGIN { print int(MAXCOLS * (MAXROWS - LOG_LINES)) }')"
	done
fi

# Sleep for a bit, so we don't race with Nickel opening the "book"...
sleep 2

# And feed it to FBInk... (avoiding the first row because it's behind the bezel on my H2O ;p)
FBINK_ROW="1"
if [ "${KFMON_USE_SYSLOG}" == "true" ] ; then
	logread | grep -e KFMon -e FBInk | tail -n ${LOG_LINES} | ${FBINK_BIN} -q -y${FBINK_ROW}
else
	tail -n ${LOG_LINES} "${KFMON_LOG}" | ${FBINK_BIN} -q -y${FBINK_ROW}
fi

return 0
