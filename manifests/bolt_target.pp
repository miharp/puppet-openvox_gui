# @summary Prepares a node as an OpenVox GUI orchestration target
#
# The GUI runs OpenBolt from the console as a dedicated `bolt` user over
# SSH, authenticating with the key its installer generates at
# `/etc/puppetlabs/bolt/id_bolt`, and expects the same user on every
# target: scripts are uploaded to `~/.bolt/tmp` (because `/tmp` is often
# mounted noexec) and privileged runs escalate with `sudo`. This class
# creates that user, its directories, and its authorized keys. Apply it to
# every node the GUI should orchestrate — the console included, if it is
# a target itself.
#
# Sudo is deliberately not managed here. Granting the bolt user
# passwordless root on every node is an operator decision that belongs
# with whatever already manages sudoers (e.g. saz/sudo, whose purge would
# otherwise remove a hand-written file). Without it, GUI runs still work
# unprivileged; "Run privileged" and file transfers do not.
#
# @example Authorize the console's key on an agent
#   class { 'openvox_gui::bolt_target':
#     authorized_keys => ['ssh-ed25519 AAAA... openvox-gui-bolt'],
#   }
#
# @example Collect the console's key from PuppetDB instead of copying it
#   $keys = puppetdb_query('facts[value] { name = "openvox_gui_bolt_pubkey" }').map |$f| { $f['value'] }
#   class { 'openvox_gui::bolt_target':
#     authorized_keys => $keys,
#   }
#
# @param authorized_keys
#   Public keys, as complete authorized_keys lines, allowed to log in as
#   the bolt user. Each console exposes its own key through the
#   `openvox_gui_bolt_pubkey` fact.
# @param user
#   Name of the orchestration user. Upstream expects 'bolt'.
# @param group
#   Primary group of the orchestration user.
# @param home
#   Home directory; Bolt's upload directory lives under it.
# @param shell
#   Login shell. Bolt needs a real shell on the target.
# @param manage_user
#   Whether to create the user and group. Disable if another module
#   manages them.
class openvox_gui::bolt_target (
  Array[String[1], 1] $authorized_keys,
  String[1] $user = 'bolt',
  String[1] $group = 'bolt',
  Stdlib::Absolutepath $home = '/home/bolt',
  Stdlib::Absolutepath $shell = '/bin/bash',
  Boolean $manage_user = true,
) {
  if $manage_user {
    group { $group:
      ensure => present,
      system => true,
    }

    user { $user:
      ensure     => present,
      system     => true,
      gid        => $group,
      home       => $home,
      shell      => $shell,
      managehome => true,
      require    => Group[$group],
    }
  }

  # File resources autorequire the user and group they are owned by.
  file { [$home, "${home}/.ssh", "${home}/.bolt", "${home}/.bolt/tmp"]:
    ensure => directory,
    owner  => $user,
    group  => $group,
    mode   => '0700',
  }

  file { "${home}/.ssh/authorized_keys":
    ensure  => file,
    owner   => $user,
    group   => $group,
    mode    => '0600',
    content => "# Managed by Puppet (openvox_gui::bolt_target).\n${authorized_keys.join("\n")}\n",
  }
}
