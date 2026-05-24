#cloud-config
hostname: ${hostname}
fqdn: ${hostname}.${domain}
prefer_fqdn_over_hostname: true
preserve_hostname: false
create_hostname_file: true
package_update: true
package_upgrade: true
package_reboot_if_required: true
ssh_pwauth: false
users:
  - name: ${default_user}
    gecos: ansible automation account
    groups: users,admin,wheel
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - ${ssh_public_key}
packages:
  - qemu-guest-agent
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
