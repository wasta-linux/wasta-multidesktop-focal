#!/bin/bash

# ------------------------------------------------------------------------------
# For wasta-login.sh determine and export the following variables:
#   - display manager (CURR_DM)
#   - current user (CURR_USER)
#   - current session (CURR_SESSION)
#   - user's previous session (PREV_SESSION)
# ------------------------------------------------------------------------------

CURR_DM=''
CURR_USER=''
CURR_SESSION=''
PREV_SESSION_FILE=''
PREV_SESSION=''

LOGDIR="/var/log/wasta-multidesktop"
LOG="${LOGDIR}/$(basename ${0%.*}).txt"
SUPPORTED_DMS="gdm3 lightdm"

log_msg(){
    # Log "info" messages to the logfile and "debug" messages to systemd journal.
    title='WMD-session-info'
    type='info'
    if [[ $1 == 'debug' ]]; then
        type='debug'
        title='WMD-session-info-DEBUG'
        shift
    fi
    msg="${title}: $@"
    if [[ $type == 'debug' ]]; then
        echo "$msg"
    elif [[ $type == 'info' ]]; then
        echo "$msg" | tee -a "$LOG"
    fi
}

script_exit(){
    # Export variables.
    export CURR_DM
    export CURR_USER
    export CURR_SESSION
    export PREV_SESSION

    # Update PREV_SESSION_FILE.
    echo $CURR_SESSION > $PREV_SESSION_FILE

    # Log the output.
    log_msg "display manager: $CURR_DM"
    log_msg "current user: $CURR_USER"
    log_msg "current session: $CURR_SESSION"
    log_msg "PREV session for user: $PREV_SESSION"
    log_msg 'debug' "End of $0"
    return $1
}


# ------------------------------------------------------------------------------
# Main processing
# ------------------------------------------------------------------------------

mkdir -p '/var/log/wasta-multidesktop'
touch "$LOG"
log_msg 'debug' "Start of $0"

# Determine display manager.
curr_dm=$(systemctl status display-manager.service | grep 'Main PID:' | awk -F'(' '{print $2}')
# Get rid of 2nd parenthesis.
curr_dm="${curr_dm::-1}"
if [[ $(echo $SUPPORTED_DMS | grep -w $curr_dm) ]]; then
    CURR_DM=$curr_dm
else
    # Unsupported display manager!
    log_msg "$(date)"
    log_msg "Error: Display manager \"$curr_dm\" not supported."
    # Exit with code 0 so that login can continue.
    script_exit 0
fi

# Get current user and session name (can't depend on full env at login).
if [[ $CURR_DM == 'gdm3' ]]; then
    CURR_USER=$USERNAME
    # TODO: Need a different way to verify wayland session.
    session_cmd=$(journalctl | grep "GdmSessionWorker: Set PAM environment variable: 'DESKTOP_SESSION" | tail -n1)
    # X:
    # GdmSessionWorker: Set PAM environment variable: 'DESKTOP_SESSION=ubuntu'
    # GdmSessionWorker: start program: /usr/lib/gdm3/gdm-x-session --run-script \
    #   "env GNOME_SHELL_SESSION_MODE=ubuntu /usr/bin/gnome-session --systemd --session=ubuntu"
    # Wayland:
    # GdmSessionWorker: Set PAM environment variable: 'DESKTOP_SESSION=ubuntu-wayland'
    # GdmSessionWorker: start program: /usr/lib/gdm3/gdm-wayland-session --run-script \
    #   "env GNOME_SHELL_SESSION_MODE=ubuntu /usr/bin/gnome-session --systemd --session=ubuntu"
    pat="s/.*DESKTOP_SESSION=(.*)'/\1/"
    CURR_SESSION=$(echo $session_cmd | sed -r "$pat")
elif [[ $CURR_DM == 'lightdm' ]]; then
    #CURR_USER=$(grep -a "User .* authorized" /var/log/lightdm/lightdm.log | \
    #    tail -1 | sed 's@.*User \(.*\) authorized@\1@')
    CURR_USER=$USER
    CURR_SESSION=$(grep -a "Greeter requests session" /var/log/lightdm/lightdm.log | \
        tail -1 | sed 's@.*Greeter requests session \(.*\)@\1@')
fi

# Get the user's previous session.
PREV_SESSION_FILE="${LOGDIR}/$CURR_USER-prev-session"
PREV_SESSION=$(cat $PREV_SESSION_FILE)

script_exit 0
