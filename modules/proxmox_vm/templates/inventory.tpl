[${group}]
%{ for idx, ip in node_ips ~}
${prefix}-${idx + offset} ansible_host=${ip}
%{ endfor ~}