{% set ENROLLSECRET = salt['cmd.run']('docker exec so-fleet fleetctl get enroll-secret') %}
{% set MAININT = salt['pillar.get']('host:mainint') %}
{% set MAINIP = salt['grains.get']('ip_interfaces').get(MAININT)[0] %}

so/fleet:
  event.send:
    - data:
        action: 'enablefleet'
        hostname: {{ grains.host }}
        mainip: {{ MAINIP }}
        role: {{ grains.role }}
        enroll-secret: {{ ENROLLSECRET }}