{% set show_top = salt['state.show_top']() %}
{% set top_states = show_top.values() | join(', ') %}

{% if 'motd' in top_states %}

so_motd:
  file.managed:
    - name: /etc/motd
    - source: salt://motd/files/so_motd.jinja
    - template: jinja

{% endif %}