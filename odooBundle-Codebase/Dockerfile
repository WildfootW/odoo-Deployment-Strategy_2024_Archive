# Base stage: Install dependencies
FROM ubuntu:jammy AS base

# The following Dockerfile installs dependencies in two phases:
#
# 1. In the first phase, we install the build-time dependencies and system-level
#    utilities required for the overall Docker setup, including dependencies for 
#    wkhtmltox, postgresql-client, and other essential tools.
#
# 2. In the second phase, we install the remaining dependencies for Odoo, gathered from:
#    a) Dependencies listed in the Odoo .deb package to ensure full coverage.
#    b) Dependencies mentioned in the debian/control file but missing from the .deb package
#       (e.g., python3-lxml-html-clean).
#
# We are temporarily not using Poetry for Python package management and instead
# using apt to install all dependencies, aiming for consistency and a simplified setup.


SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Set working directory inside the container
WORKDIR /opt/odoo

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG en_US.UTF-8

# Set environment variables to prevent Python from writing .pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Update package lists, install CA certificates, reconfigure them, and add the new mirror in one step
RUN apt-get update && apt-get install -y ca-certificates && \
    update-ca-certificates && \
    sed -i '1ideb https://mirror.twds.com.tw/ubuntu/ jammy main restricted universe multiverse' /etc/apt/sources.list && \
    sed -i '1ideb https://mirror.twds.com.tw/ubuntu/ jammy-updates main restricted universe multiverse' /etc/apt/sources.list && \
    sed -i '1ideb https://mirror.twds.com.tw/ubuntu/ jammy-backports main restricted universe multiverse' /etc/apt/sources.list && \
    sed -i '1ideb https://mirror.twds.com.tw/ubuntu/ jammy-security main restricted universe multiverse' /etc/apt/sources.list

# This section installs essential system utilities, Python libraries, and other packages required
# primarily for the installation of wkhtmltox.deb, which is used for converting HTML to PDF within Odoo.
# While some Python packages are installed here, they are dependencies for wkhtmltox or system tools,
# and NOT specifically for Odoo. Odoo dependencies will be handled separately later in the Dockerfile.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils && \
    if [ -z "${TARGETARCH}" ]; then \
        TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb \
    && echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

# Second phase: Install Odoo-specific dependencies
# These dependencies are gathered from:
# 1. The Odoo .deb package dependencies.
# 2. python3-lxml-html-clean, which is mentioned in the debian/control file but not in the final .deb package.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-babel \
    python3-chardet \
    python3-cryptography \
    python3-dateutil \
    python3-decorator \
    python3-docutils \
    python3-geoip2 \
    python3-gevent \
    python3-greenlet \
    python3-idna \
    python3-jinja2 \
    python3-libsass \
    python3-lxml \
    python3-markupsafe \
    python3-num2words \
    python3-ofxparse \
    python3-openssl \
    python3-passlib \
    python3-pil \
    python3-polib \
    python3-psutil \
    python3-psycopg2 \
    python3-pydot \
    python3-pypdf2 \
    python3-qrcode \
    python3-reportlab \
    python3-requests \
    python3-rjsmin \
    python3-serial \
    python3-stdnum \
    python3-tz \
    python3-urllib3 \
    python3-usb \
    python3-vobject \
    python3-werkzeug \
    python3-xlrd \
    python3-xlsxwriter \
    python3-xlwt \
    python3-zeep \
    adduser \
    fonts-dejavu-core \
    fonts-freefont-ttf \
    fonts-freefont-otf \
    fonts-noto-core \
    fonts-inconsolata \
    fonts-font-awesome \
    fonts-roboto-unhinted \
    gsfonts \
    libjs-underscore \
    lsb-base \
    postgresql-client \
    python3-freezegun \
    python3-renderpm \
#    python3-lxml-html-clean \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Final stage: Set up Odoo
FROM base AS final

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Copy local Odoo source code and addons to the image
# Copy entrypoint script and Odoo configuration file
COPY ./odoo /opt/odoo/core
COPY ./addons /opt/odoo/addons
COPY ./odoo.conf /etc/odoo/
COPY ./utils /usr/local/bin/
COPY ./entrypoint.sh /
#WORKDIR /opt/odoo/core

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
