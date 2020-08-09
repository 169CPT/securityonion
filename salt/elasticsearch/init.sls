# Copyright 2014,2015,2016,2017,2018,2019,2020 Security Onion Solutions, LLC

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{% set FEATURES = salt['pillar.get']('elastic:features', False) %}

{% if FEATURES %}
  {% set FEATURES = "-features" %}
{% else %}
  {% set FEATURES = '' %}
{% endif %}

{% if grains['role'] in ['so-eval','so-managersearch', 'so-manager', 'so-standalone'] %}
  {% set esclustername = salt['pillar.get']('manager:esclustername', '') %}
  {% set esheap = salt['pillar.get']('manager:esheap', '') %}
  {% set ismanager = True %}
{% elif grains['role'] in ['so-node','so-heavynode'] %}
  {% set esclustername = salt['pillar.get']('elasticsearch:esclustername', '') %}
  {% set esheap = salt['pillar.get']('elasticsearch:esheap', '') %}
  {% set ismanager = False %}
{% endif %}

{% set TEMPLATES = salt['pillar.get']('elasticsearch:templates', {}) %}

vm.max_map_count:
  sysctl.present:
    - value: 262144

{% if ismanager %}
# We have to add the Manager CA to the CA list
cascriptsync:
  file.managed:
    - name: /usr/sbin/so-catrust
    - source: salt://elasticsearch/files/scripts/so-catrust
    - user: 939
    - group: 939
    - mode: 750
    - template: jinja

# Run the CA magic
cascriptfun:
  cmd.run:
    - name: /usr/sbin/so-catrust

{% endif %}

# Move our new CA over so Elastic and Logstash can use SSL with the internal CA
catrustdir:
  file.directory:
    - name: /opt/so/conf/ca
    - user: 939
    - group: 939
    - makedirs: True

cacertz:
  file.managed:
    - name: /opt/so/conf/ca/cacerts
    - source: salt://common/cacerts
    - user: 939
    - group: 939

capemz:
  file.managed:
    - name: /opt/so/conf/ca/tls-ca-bundle.pem
    - source: salt://common/tls-ca-bundle.pem
    - user: 939
    - group: 939

# Add ES Group
elasticsearchgroup:
  group.present:
    - name: elasticsearch
    - gid: 930

# Add ES user
elasticsearch:
  user.present:
    - uid: 930
    - gid: 930
    - home: /opt/so/conf/elasticsearch
    - createhome: False

esconfdir:
  file.directory:
    - name: /opt/so/conf/elasticsearch
    - user: 930
    - group: 939
    - makedirs: True

esingestdir:
  file.directory:
    - name: /opt/so/conf/elasticsearch/ingest
    - user: 930
    - group: 939
    - makedirs: True

estemplatedir:
  file.directory:
    - name: /opt/so/conf/elasticsearch/templates
    - user: 930
    - group: 939
    - makedirs: True

esingestconf:
  file.recurse:
    - name: /opt/so/conf/elasticsearch/ingest
    - source: salt://elasticsearch/files/ingest
    - user: 930
    - group: 939

eslog4jfile:
  file.managed:
    - name: /opt/so/conf/elasticsearch/log4j2.properties
    - source: salt://elasticsearch/files/log4j2.properties
    - user: 930
    - group: 939
    - template: jinja

esyml:
  file.managed:
    - name: /opt/so/conf/elasticsearch/elasticsearch.yml
    - source: salt://elasticsearch/files/elasticsearch.yml
    - user: 930
    - group: 939
    - template: jinja

#sync templates to /opt/so/conf/elasticsearch/templates
{% for TEMPLATE in TEMPLATES %}
es_template_{{TEMPLATE.split('.')[0] | replace("/","_") }}:
  file.managed:
    - source: salt://elasticsearch/templates/{{TEMPLATE}}
    {% if 'jinja' in TEMPLATE.split('.')[-1] %}
    - name: /opt/so/conf/elasticsearch/templates/{{TEMPLATE.split('/')[1] | replace(".jinja", "")}}
    - template: jinja
    {% else %}
    - name: /opt/so/conf/elasticsearch/templates/{{TEMPLATE.split('/')[1]}}
    {% endif %}
    - user: 930
    - group: 939
{% endfor %}

nsmesdir:
  file.directory:
    - name: /nsm/elasticsearch
    - user: 930
    - group: 939
    - makedirs: True

eslogdir:
  file.directory:
    - name: /opt/so/log/elasticsearch
    - user: 930
    - group: 939
    - makedirs: True

so-elasticsearch:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/so-elasticsearch:{{ VERSION }}{{ FEATURES }}
    - hostname: elasticsearch
    - name: so-elasticsearch
    - user: elasticsearch
    - environment:
      - discovery.type=single-node
      #- bootstrap.memory_lock=true
      #- cluster.name={{ esclustername }}
      - ES_JAVA_OPTS=-Xms{{ esheap }} -Xmx{{ esheap }}
      #- http.host=0.0.0.0
      #- transport.host=127.0.0.1
    - ulimits:
      - memlock=-1:-1
      - nofile=65536:65536
      - nproc=4096
    - port_bindings:
      - 0.0.0.0:9200:9200
      - 0.0.0.0:9300:9300
    - binds:
      - /opt/so/conf/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
      - /opt/so/conf/elasticsearch/log4j2.properties:/usr/share/elasticsearch/config/log4j2.properties:ro
      - /nsm/elasticsearch:/usr/share/elasticsearch/data:rw
      - /opt/so/log/elasticsearch:/var/log/elasticsearch:rw
      - /opt/so/conf/ca/cacerts:/etc/pki/ca-trust/extracted/java/cacerts:ro
    - watch:
      - file: cacertz

so-elasticsearch-pipelines-file:
  file.managed:
    - name: /opt/so/conf/elasticsearch/so-elasticsearch-pipelines
    - source: salt://elasticsearch/files/so-elasticsearch-pipelines
    - user: 930
    - group: 939
    - mode: 754

so-elasticsearch-pipelines:
 cmd.run:
   - name: /opt/so/conf/elasticsearch/so-elasticsearch-pipelines {{ esclustername }}
   - onchanges:
      - file: esingestconf
      - file: esyml
      - file: so-elasticsearch-pipelines-file

{% if grains['role'] in ['so-manager', 'so-eval', 'so-managersearch', 'so-standalone'] and TEMPLATES %}
so-elasticsearch-templates:
  cmd.run:
    - name: /usr/sbin/so-elasticsearch-templates
    - cwd: /opt/so
{% endif %}