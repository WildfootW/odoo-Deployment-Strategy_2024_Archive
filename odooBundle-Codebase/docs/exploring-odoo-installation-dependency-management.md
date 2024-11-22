# Exploring odoo Installation Dependency Management for Poetry Integration

In this document, I explore the different methods of installing Odoo—via source, package manager, and official Docker image—to gain a clear understanding of the required packages for each approach. My goal was to transition to a more flexible and customizable setup using Poetry to manage Odoo's dependencies. By leveraging Poetry, I aimed to streamline the integration of custom modules that may require additional or specific packages beyond the standard Odoo installation. This approach would provide greater control over dependency management, ensuring that my Odoo environment remains adaptable to evolving project needs.

However, through this exploration, the following conclusions were reached:

1. **Maintaining the Official Dockerfile's Structure**:  
   The `apt install` commands in the official Dockerfile are primarily used to install dependencies for `wkhtmltopdf`, not Odoo itself. Therefore, the upper section of the Dockerfile remains unchanged, with the only modification being the switch to a local mirror for faster package retrieval.

2. **Handling Odoo Dependencies**:  
   While Odoo's "install from source" method uses a shell script to parse `debian/control` and install dependencies, our comparison with the `.deb` file revealed that some dependencies, like `${python3:Depends}`, were missing in the source installation process. To ensure all necessary dependencies are installed, we decided to reference the `.deb` file directly and incorporate its dependency list into the Dockerfile for installation.

3. **Temporarily Abandoning Poetry for Package Management**:  
   Due to the complexity of both Python and non-Python dependencies required by Odoo, we have temporarily opted to forego using Poetry for managing these packages. Instead, we are using `apt install` in the Dockerfile to handle the installation of all necessary dependencies for simplicity and consistency.

The research process is documented at the end of this file as a record of the findings.

## Install from Source
```bash
git clone https://github.com/odoo/odoo.git
sudo apt install postgresql postgresql-client
sudo -u postgres createuser -d -R -S $USER
createdb $USER
cd odoo # CommunityPath
sudo ./setup/debinstall.sh
sudo npm install -g rtlcss # For languages using a right-to-left interface (such as Arabic or Hebrew)
```

### In debinstall.sh
When you run this script with the `-l` or `--list` option, the script will output the list of Debian packages required for installation, but it will not actually install them. Specifically, it extracts the required packages from the `Depends:` section of the `debian/control` file and displays them in the terminal.

1. **Set command to `echo`:**

    ```sh
    if [ "$1" = "-l" -o "$1" = "--list" ]; then
        cmd="echo"
    else
        # ... other code ...
    fi
    ```

    When you provide the `-l` or `--list` argument, the variable `cmd` is set to `echo`, meaning subsequent operations will just print the content rather than execute the installation.

2. **Locate the control file `debian/control`:**

    ```sh
    script_path=$(realpath "$0")
    script_dir=$(dirname "$script_path")
    control_path=$(realpath "$script_dir/../debian/control")
    ```

    This section of the code determines the path to the current script, the directory it's in, and then finds the absolute path to the `../debian/control` file relative to the script.

3. **Extract the list of dependencies:**

    ```sh
    sed -n '/^Depends:/,/^[A-Z]/p' "$control_path" \
    | awk '/^ [a-z]/ { gsub(/,/,"") ; gsub(" ", "") ; print $NF }' | sort -u \
    | DEBIAN_FRONTEND=noninteractive xargs $cmd
    ```

    - The `sed` command extracts the content from the line starting with `Depends:` until the next line starting with an uppercase letter, which contains all the dependencies.
    - The `awk` command processes these lines, removes commas and spaces, and extracts each package name.
    - The `sort -u` command sorts the package names and removes duplicates.
    - The `xargs $cmd` passes the package names to the previously set command, which is `echo`, causing them to be printed to the terminal.
    
4. If you run the script without the `-l` option, it will use `apt-get install -y --no-install-recommends` to install the following packages:

```
adduser, fonts-dejavu-core, fonts-freefont-ttf, fonts-freefont-otf, fonts-noto-core, fonts-font-awesome, fonts-inconsolata, fonts-roboto-unhinted, gsfonts, libjs-underscore, lsb-base, postgresql-client, python3-babel, python3-chardet, python3-dateutil, python3-decorator, python3-docutils, python3-freezegun, python3-geoip2, python3-jinja2, python3-libsass, python3-lxml-html-clean, python3-lxml, python3-num2words, python3-ofxparse, python3-openssl, python3-passlib, python3-pil, python3-polib, python3-psutil, python3-psycopg2, python3-pydot, python3-pypdf2, python3-qrcode, python3-renderpm, python3-reportlab, python3-requests, python3-rjsmin, python3-stdnum, python3-tz, python3-vobject, python3-werkzeug, python3-xlrd, python3-xlsxwriter, python3-zeep.
```
**This list does not seem to inlcude the dependencies that would be filled in by `${python3:Depends}`**

## Install from Package Manager
```
sudo apt install postgresql -y
wget -q -O - https://nightly.odoo.com/odoo.key | sudo gpg --dearmor -o /usr/share/keyrings/odoo-archive-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/17.0/nightly/deb/ ./' | sudo tee /etc/apt/sources.list.d/odoo.list
sudo apt-get update && sudo apt-get install odoo
```

We can extract and review the specific Python packages from the .deb file using a custom script. Here's an example of a script to extract Python dependencies from the Odoo .deb package and recursively list all of their dependencies:
```bash
#!/bin/bash
#
# extract_python_deps.sh
# © 2024 Andrew Shen <wildfootw@hoschoc.com>
#
# Distributed under the same license as odooBundle-Codebase.
#

# Check if a .deb file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_deb_file>"
    exit 1
fi

DEB_FILE="$1"

# Check if dpkg-deb is available
if ! command -v dpkg-deb &> /dev/null; then
    echo "Error: dpkg-deb is not installed. Please install the dpkg package."
    exit 1
fi

# Check if apt-rdepends is available
if ! command -v apt-rdepends &> /dev/null; then
    echo "Error: apt-rdepends is not installed. Please run: sudo apt-get install apt-rdepends"
    exit 1
fi

# Extract the Depends field from the .deb file
DEPENDS=$(dpkg-deb -I "$DEB_FILE" | grep -E '^ Depends:' | sed 's/^ Depends://' | tr ',' '\n' | sed 's/|.*//' | sed 's/(.*)//' | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')

# Extract packages that start with python3-
PYTHON_PACKAGES=$(echo "$DEPENDS" | grep '^python3-')

if [ -z "$PYTHON_PACKAGES" ]; then
    echo "No python3-related packages found in $DEB_FILE."
    exit 0
fi

echo "Found the following python3-related packages in $DEB_FILE:"
echo "$PYTHON_PACKAGES"
echo ""

# Run apt-rdepends for each package and collect all dependencies
ALL_DEPENDS=()

for pkg in $PYTHON_PACKAGES; do
    echo "Processing dependencies for package $pkg..."
    DEP_LIST=$(apt-rdepends "$pkg" 2>/dev/null | grep -E '^[a-zA-Z0-9-]+$')
    ALL_DEPENDS+=($DEP_LIST)
done

# Remove duplicate package names
UNIQUE_DEPENDS=($(echo "${ALL_DEPENDS[@]}" | tr ' ' '\n' | sort -u))

echo ""
echo "List of all recursive dependencies:"
for dep in "${UNIQUE_DEPENDS[@]}"; do
    echo "$dep"
done
```

```
./extract_python_deps.sh odoo_17.0.latest_all.deb
Found the following python3-related packages in odoo_17.0.latest_all.deb: python3-babel python3-chardet python3-cryptography python3-dateutil python3-decorator python3-docutils python3-geoip2 python3-gevent python3-greenlet python3-idna python3-jinja2 python3-libsass python3-lxml python3-markupsafe python3-num2words python3-ofxparse python3-openssl python3-passlib python3-pil python3-polib python3-psutil python3-psycopg2 python3-pydot python3-pypdf2 python3-qrcode python3-reportlab python3-requests python3-rjsmin python3-serial python3-stdnum python3-tz python3-urllib3 python3-usb python3-vobject python3-werkzeug python3-xlrd python3-xlsxwriter python3-xlwt python3-zeep python3-freezegun python3-renderpm
```
The list also includes many non-Python dependencies, so they are not included here for brevity.

## Install from Official Docker
### Sections Installing Python Packages:

#### 1. Installing System Dependencies and Python Packages

    RUN apt-get update && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends \
            # ... other system packages ...
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
            # ... other packages ...

- **Explanation:** This section installs several Python packages using `apt-get`. These are system-level installations of Python libraries required by Odoo.
- **Action:** You can remove these packages from the `apt-get install` command and instead add them to your `pyproject.toml` file to be managed by Poetry.

#### 2. Installing Odoo

    RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
        && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
        && apt-get update \
        && apt-get -y install --no-install-recommends ./odoo.deb \
        && rm -rf /var/lib/apt/lists/* odoo.deb

- **Explanation:** Here, Odoo is installed via a pre-built `.deb` package, which includes the Odoo application and its Python dependencies bundled together.
- **Action:** To manage Odoo's Python dependencies with Poetry, you should install Odoo from source rather than using the `.deb` package. This way, you can define all Python dependencies in `pyproject.toml`.


### Sections Not Directly Related to Python Packages:

#### 1. Installing `wkhtmltopdf`

```
curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb && echo "967390a759707337b46d1c02452e2bb6b2dc6d59 wkhtmltox.deb" | sha1sum -c - && apt-get install -y --no-install-recommends ./wkhtmltox.deb && rm -rf /var/lib/apt/lists/* wkhtmltox.deb
```

- **Explanation:** `wkhtmltopdf` is a standalone tool for rendering HTML to PDF and is not a Python package.
- **Action:** No changes needed regarding Python package management.

I checked the `.deb` file for `wkhtmltox`, and it does not contain any Python packages in its dependencies:

    dpkg --info wkhtmltox.deb
    Package: wkhtmltox
    Version: 1:0.12.6.1-3.jammy
    Architecture: amd64
    Depends: ca-certificates, fontconfig, libc6, libfreetype6, libjpeg-turbo8, libpng16-16, libssl3, libstdc++6, libx11-6, libxcb1, libxext6, libxrender1, xfonts-75dpi, xfonts-base, zlib1g

#### 2. Installing the Latest PostgreSQL Client

```
echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list && GNUPGHOME="$(mktemp -d)" && export GNUPGHOME && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc && gpgconf --kill all && rm -rf "$GNUPGHOME" && apt-get update && apt-get install --no-install-recommends -y postgresql-client && rm -f /etc/apt/sources.list.d/pgdg.list && rm -rf /var/lib/apt/lists/*
```

- **Explanation:** Installs the PostgreSQL client, which is a system package, not a Python package.
- **Action:** No changes needed regarding Python package management.

I checked the `.deb` file for `postgresql-client-16`, and it does not contain any Python packages in its dependencies:

    dpkg --info postgresql-client-16_16.4-1.pgdg22.04+1_amd64.deb
    Package: postgresql-client-16
    Version: 16.4-1.pgdg22.04+1
    Architecture: amd64
    Depends: libpq5 (>= 16.4), postgresql-client-common (>= 182~), sensible-utils, libc6 (>= 2.34), liblz4-1 (>= 0.0~r127), libreadline8 (>= 6.0), libssl3 (>= 3.0.0~~alpha1), libzstd1 (>= 1.4.0), zlib1g (>= 1:1.1.4)
    