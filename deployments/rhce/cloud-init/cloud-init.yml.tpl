#cloud-config
hostname: ${hostname}
fqdn: ${hostname}.${domain}
prefer_fqdn_over_hostname: true
preserve_hostname: false
create_hostname_file: true
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
  - lvm2
  - python3
  - python3-firewall
  - firewalld
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent