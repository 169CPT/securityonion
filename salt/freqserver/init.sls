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

{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}

# Create the user
fservergroup:
  group.present:
    - name: freqserver
    - gid: 935

# Add ES user
freqserver:
  user.present:
    - uid: 935
    - gid: 935
    - home: /opt/so/conf/freqserver
    - createhome: False

# Create the log directory
freqlogdir:
  file.directory:
    - name: /opt/so/log/freq_server
    - user: 935
    - group: 935
    - makedirs: True

so-freqimage:
 cmd.run:
   - name: docker pull --disable-content-trust=false docker.io/{{ IMAGEREPO }}/so-freqserver:HH1.0.3

so-freq:
  docker_container.running:
    - require:
      - so-freqimage
    - image: docker.io/{{ IMAGEREPO }}/so-freqserver:HH1.0.3
    - hostname: freqserver
    - name: so-freqserver
    - user: freqserver
    - binds:
      - /opt/so/log/freq_server:/var/log/freq_server:rw

