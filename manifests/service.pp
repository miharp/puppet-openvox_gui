# @summary Manages the OpenVox GUI service
#
# The systemd unit itself is written by the installer (see
# openvox_gui::config); this class only manages its run state.
#
# @api private
class openvox_gui::service {
  assert_private()

  if $openvox_gui::service_manage {
    service { $openvox_gui::service_name:
      ensure => $openvox_gui::service_ensure,
      enable => $openvox_gui::service_enable,
    }
  }
}
