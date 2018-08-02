#
#
FROM phusion/baseimage:master

MAINTAINER Michael Fong <mcfong.open@gmail.com>
########################################################
# Make sure the basic folder is setup, with permission nukes
RUN mkdir /workspace && chmod -R 0777 /workspace ;
	
WORKDIR /workspace

ENV HOME /workspace

#######################################################
# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

#######################################################
# Grafana Installation

ARG GRAFANA_VERSION="5.2.2"
ARG GRAFANA_URL="https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-$GRAFANA_VERSION.linux-amd64.tar.gz"
ARG GF_UID="472"
ARG GF_GID="472"

ENV PATH=/usr/share/grafana/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
    GF_PATHS_DATA="/var/lib/grafana" \
    GF_PATHS_HOME="/usr/share/grafana" \
    GF_PATHS_LOGS="/var/log/grafana" \
    GF_PATHS_PLUGINS="/var/lib/grafana/plugins" \
    GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

RUN apt-get update && apt-get install -qq -y tar libfontconfig curl ca-certificates && \
    mkdir -p "$GF_PATHS_HOME/.aws" && \
    curl "$GRAFANA_URL" | tar xfvz - --strip-components=1 -C "$GF_PATHS_HOME" && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -r -g $GF_GID grafana && \
    useradd -r -u $GF_UID -g grafana grafana && \
    mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
             "$GF_PATHS_PROVISIONING/dashboards" \
             "$GF_PATHS_LOGS" \
             "$GF_PATHS_PLUGINS" \
             "$GF_PATHS_DATA" && \
    cp "$GF_PATHS_HOME/conf/sample.ini" "$GF_PATHS_CONFIG" && \
    cp "$GF_PATHS_HOME/conf/ldap.toml" /etc/grafana/ldap.toml && \
    chown -R grafana:grafana "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" && \
    chmod 777 "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS"

ADD grafana.ini /etc/grafana/grafana.ini 

EXPOSE 3000


USER root
WORKDIR /

########################################################
# Add Grafana shell daemon
RUN mkdir /etc/service/grafana
COPY run.sh /etc/service/grafana/run
RUN chmod +x /etc/service/grafana/run

########################################################
# SSH Setting
#
# Enable the SSH server from base image

RUN rm -f /etc/service/sshd/down

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# Enabling the insecure key permanently for demo purposes
RUN /usr/sbin/enable_insecure_key

RUN echo 'root:docker' | chpasswd

# XXX: Allow root login 
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

########################################################
# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
