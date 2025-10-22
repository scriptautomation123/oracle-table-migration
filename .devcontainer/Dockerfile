FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install Oracle Instant Client and tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    python3-pip \
    python3-dev \
    build-essential \
    libaio1t64 \
    libaio1 \
    wget \
    unzip \
    curl \
    vim \
    less \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

# Install Python packages and create workspace directory
# Using --break-system-packages is safe in a container environment
RUN pip3 install --no-cache-dir --break-system-packages \
    oracledb==2.0.1 \
    jinja2==3.1.4 \
    jsonschema==4.23.0 \
    ansible==10.4.0 \
    pytest==8.3.3 \
    black==24.8.0 \
    pylint==3.2.7 \
    && mkdir -p /workspace

WORKDIR /workspace

# Add healthcheck to verify Oracle client and Python environment
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import oracledb; print('Oracle client OK')" || exit 1

# Default user
USER vscode
