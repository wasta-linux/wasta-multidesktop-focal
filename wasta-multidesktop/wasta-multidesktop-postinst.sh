#!/bin/bash

# ==============================================================================
# wasta-multidesktop: wasta-multidesktop-postinst.sh
#
# This script is automatically run by the postinst configure step on
#   installation of wasta-multidesktop-setup.  It can be manually re-run, but is
#   only intended to be run at package installation.
#
# 2015-06-18 rik: initial script
# 2016-11-14 rik: enabling wasta-multidesktop systemd service
# 2017-03-18 rik: disabling wasta-logout systemd service: we now use
#   wasta-login lightdm script to record user session and retrieve it to
#   compare session to previous session and sync if any change.
# 2017-12-20 rik: adding wasta-linux theming items (previously was at the
#   wasta-core level).
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [ $(id -u) -ne 0 ]
then
    echo
    echo "You must run this script with sudo." >&2
    echo "Exiting...."
    sleep 5s
    exit 1
fi

# ------------------------------------------------------------------------------
# Main Processing
# ------------------------------------------------------------------------------
# Setup Directory for later reference
DIR=/usr/share/wasta-multidesktop

#WASTA_SYSTEMD=$(systemctl is-enabled wasta-logout || true);

#if [ "$WASTA_SYSTEMD" == "enabled" ];
#then
#    echo
#    echo "*** DISabling wasta-logout systemd service"
#    echo
#    # check status this way: journalctl | grep wasta-logout
#    systemctl disable wasta-logout || true
#fi

# ------------------------------------------------------------------------------
# set slick-greeter as lightdm greeter
# ------------------------------------------------------------------------------
# Priority of 90 will override lightdm-gtk-greeter IF it is installed
update-alternatives --install /usr/share/xgreeters/lightdm-greeter.desktop \
    lightdm-greeter /usr/share/xgreeters/slick-greeter.desktop 90

# ------------------------------------------------------------------------------
# set wasta-logo as Plymouth Theme
# ------------------------------------------------------------------------------
# only do if wasta-logo not current default.plymouth
# below will return *something* if wasta-logo found in default.plymouth
#   '|| true; needed so won't return error=1 if nothing found
WASTA_PLY_THEME=$(cat /etc/alternatives/default.plymouth | \
    grep ImageDir=/usr/share/plymouth/themes/wasta-logo || true;)
# if variable is still "", then need to set default.plymouth
if [ -z "$WASTA_PLY_THEME" ];
then
    echo
    echo "*** Setting Plymouth Theme to wasta-logo"
    echo
    # add wasta-logo to default.plymouth theme list
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
        /usr/share/plymouth/themes/wasta-logo/wasta-logo.plymouth 100

    # set wasta-logo as default.plymouth
    update-alternatives --set default.plymouth \
        /usr/share/plymouth/themes/wasta-logo/wasta-logo.plymouth

    # update
    update-initramfs -u
    
    # update grub (to get rid of purple grub boot screen)
    update-grub
else
    echo
    echo "*** Plymouth Theme already set to wasta-logo.  No update needed."
    echo
fi

WASTA_PLY_TEXT=$(cat /etc/alternatives/text.plymouth | \
    grep title=Wasta-Linux || true;)
# if variable is not Wasta-Linux, then need to set text.plymouth
if [ -z "$WASTA_PLY_TEXT" ];
then
    echo
    echo "*** Setting Plymouth TEXT Theme to wasta-text"
    echo

    # add wasta-text to text.plymouth theme list
    update-alternatives --install /usr/share/plymouth/themes/text.plymouth text.plymouth \
        /usr/share/plymouth/themes/wasta-text/wasta-text.plymouth 100

    # set wasta-text as text.plymouth
    update-alternatives --set text.plymouth \
        /usr/share/plymouth/themes/wasta-text/wasta-text.plymouth

    # update
    update-initramfs -u
else
    echo
    echo "*** Plymouth TEXT Theme already set to wasta-text. No update needed."
    echo
fi

# ------------------------------------------------------------------------------
# Fix scrollbars to go "one page at a time" with click
# ------------------------------------------------------------------------------
# global gtk-3.0 setting location:
sed -i -e '$a gtk-primary-button-warps-slider = false' \
    -i -e '\#gtk-primary-button-warps-slider#d' \
    /etc/gtk-3.0/settings.ini

# per-theme settings done in app-adjustments since could be reverted

# ------------------------------------------------------------------------------
# app-adjustments
# ------------------------------------------------------------------------------
# run app-adjustments.sh
bash $DIR/scripts/app-adjustments.sh || true;

# ------------------------------------------------------------------------------
# Dconf / Gsettings Default Value adjustments
# ------------------------------------------------------------------------------
# Values in /usr/share/glib-2.0/schemas/z_11_wasta-multidesktop.gschema.override
#   will override Ubuntu defaults.
# Below command compiles them to be the defaults
echo
echo "*** wasta-multidesktop: updating dconf / gsettings default values"
echo

# MAIN System schemas: we have placed our override file in this directory
# Sending any "error" to null (if key not found don't want to worry user)
glib-compile-schemas /usr/share/glib-2.0/schemas/ # > /dev/null 2>&1 || true;

echo
echo "*** Enabling wasta-multidesktop@.service"
echo
# 20.04: doesn't create /etc/systemd symlink when enabling this templated unit
#   so for now am just manually enabling
# systemctl enable wasta-multidesktop@.service
mkdir -p /etc/systemd/system/user@.service.wants/
ln -sf /lib/systemd/system/wasta-multidesktop@.service /etc/systemd/system/user@.service.wants/

echo
echo "*** Enabling 'KillUserProcesses' to ensure wasta-logout runs on logout"
echo

# lightdm does NOT close user sessions on logout, meaning wasta-logout and
# other systemd items expecting the session to close are not running
# correctly. Setting "KillUserProcesses=yes" in logind config works around
# this.
sed -i -e "s@.*\(KillUserProcesses\).*@\1=yes@" /etc/systemd/logind.conf

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------
echo
echo "*** Finished with wasta-multidesktop-postinst.sh"
echo

exit 0
