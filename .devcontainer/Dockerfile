FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install Oracle Instant Client and tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        python3-pip \
        python3-dev \
        build-essential \
        libaio1 \
        wget \
        unzip \
        curl \
        vim \
        less \
        git

# Install Oracle Instant Client 21
RUN mkdir -p /opt/oracle \
    && cd /opt/oracle \
    && wget https://download.oracle.com/otn_software/linux/instantclient/2113000/instantclient-basic-linux.x64-21.13.0.0.0dbru.zip \
    && wget https://download.oracle.com/otn_software/linux/instantclient/2113000/instantclient-sqlplus-linux.x64-21.13.0.0.0dbru.zip \
    && unzip instantclient-basic-linux.x64-21.13.0.0.0dbru.zip \
    && unzip instantclient-sqlplus-linux.x64-21.13.0.0.0dbru.zip \
    && rm -f *.zip \
    && cd instantclient_21_13 \
    && sh -c "echo /opt/oracle/instantclient_21_13 > /etc/ld.so.conf.d/oracle-instantclient.conf" \
    && ldconfig

# Set Oracle environment variables
ENV ORACLE_HOME=/opt/oracle/instantclient_21_13
ENV LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH
ENV PATH=$ORACLE_HOME:$PATH

# Install Python packages
RUN pip3 install --no-cache-dir \
    oracledb \
    jinja2 \
    jsonschema \
    ansible \
    pytest \
    black \
    pylint

# Create workspace directory
RUN mkdir -p /workspace
WORKDIR /workspace

# Default user
USER vscode
