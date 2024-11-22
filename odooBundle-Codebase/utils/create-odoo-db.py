#! /usr/bin/env python3
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyleft (ɔ) 2024 wildfootw <wildfootw@wildfoo.tw>
#
# Distributed under the same license as odooBundle-Codebase.

import argparse
import requests
import urllib3
from requests.packages.urllib3.exceptions import InsecureRequestWarning
import configparser
import os
import sys

def read_master_password_from_file(conf_file):
    """Reads the master password from the provided odoo.conf file."""
    if not os.path.exists(conf_file):
        raise FileNotFoundError(f"The file {conf_file} does not exist.")

    config = configparser.ConfigParser()
    with open(conf_file, 'r') as f:
        content = f.read()

    # Check if the file contains any section headers
    if not any(line.strip().startswith('[') and line.strip().endswith(']') for line in content.splitlines()):
        # No section headers found, add a dummy section
        content = '[dummy_section]\n' + content
        config.read_string(content)
        section = 'dummy_section'
    else:
        # Sections are present, read the file normally
        config.read_string(content)
        # Try to find the section containing 'admin_passwd'
        section = None
        for sect in config.sections():
            if config.has_option(sect, 'admin_passwd'):
                section = sect
                break
        if not section:
            raise ValueError(f"Master password (admin_passwd) not found in any section of {conf_file}.")

    try:
        master_pwd = config.get(section, 'admin_passwd')
        return master_pwd
    except configparser.NoOptionError:
        raise ValueError(f"Master password (admin_passwd) not found in section '{section}' of {conf_file}.")

def create_odoo_db(master_pwd, db_name, login, password, lang, country_code, phone, url, ignore_ssl):
    # Suppress only the InsecureRequestWarning if the user wants to ignore SSL verification
    if ignore_ssl:
        urllib3.disable_warnings(InsecureRequestWarning)

    # Ensure the URL ends with the correct path
    if not url.startswith('http'):
        # Default to http if protocol is not specified
        url = f'http://{url}'

    # Append the correct path to the URL
    if not url.endswith('/web/database/create'):
        url = f'{url.rstrip("/")}/web/database/create'

    # Prepare the payload for the POST request
    payload = {
        'master_pwd': master_pwd,
        'name': db_name,
        'login': login,
        'password': password,
        'lang': lang,
        'country_code': country_code,
        'phone': phone
    }

    # Send the POST request with SSL verification depending on the ignore_ssl argument
    try:
        response = requests.post(url, data=payload, verify=not ignore_ssl)

        # Check if the request was successful
        if response.status_code == 200:
            # Check for the specific error message in the response text
            if "Database creation error: Access Denied" in response.text:
                print("Database creation failed: Access Denied. The master password is incorrect.")
            else:
                print("Database created successfully!")
        else:
            print(f"Failed to create database. Status code: {response.status_code}")
            # Print the response content to see the error from the server
            print(f"Response: {response.text}")
    except requests.exceptions.SSLError as ssl_error:
        print(f"SSL error occurred: {ssl_error}")

if __name__ == '__main__':
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Create an Odoo database using curl.")

    # Remove default value for --mpwd
    parser.add_argument('-m', '--mpwd', help="Master Password for the Odoo instance. Cannot be used with --mpwd_file.")
    parser.add_argument('-f', '--mpwd_file', help="Path to the odoo.conf file containing the Master Password. Cannot be used with --mpwd.")
    parser.add_argument('--db_name', default='odoo', help="Database name to create (default: 'odoo')")
    parser.add_argument('--login', default='admin', help="Admin login for the new database (default: 'admin')")
    parser.add_argument('--password', default='admin', help="Admin Password for the new database (default: 'admin')")
    parser.add_argument('--lang', default='en_US', help="Language for the new database (default: 'en_US')")
    parser.add_argument('--country_code', default='tw', help="Country code for the new database (default: 'tw')")
    parser.add_argument('--phone', default='+886987654321', help="Phone number for the admin user (default: '+886987654321')")

    # Updated help for URL argument
    parser.add_argument('-u', '--url', default='localhost:8069',
                        help="Base URL for Odoo (default: 'localhost:8069'). You can provide the URL in the format 'localhost:8069' "
                             "and the script will convert it to 'http://localhost:8069/web/database/create'. If you want to use https, "
                             "provide the URL like 'https://localhost:443', and it will go to 'https://localhost:443/web/database/create'.")

    # New argument to ignore SSL certificate verification
    parser.add_argument('--ignore_ssl', action='store_true',
                        help="Ignore SSL certificate verification errors. Use this if you encounter certificate errors when using HTTPS.")

    args = parser.parse_args()

    # Ensure that --mpwd and --mpwd_file cannot be used at the same time
    if args.mpwd and args.mpwd_file:
        print("Error: --mpwd and --mpwd_file cannot be used at the same time.")
        sys.exit(1)

    # Determine the master password
    if args.mpwd:
        master_pwd = args.mpwd
    else:
        if not args.mpwd_file:
            args.mpwd_file = "/etc/odoo/odoo.conf" # Default odoo.conf location
        try:
            master_pwd = read_master_password_from_file(args.mpwd_file)
        except Exception as e:
            print(f"Error reading master password from file: {e}")
            sys.exit(1)

    # Call the function to create the Odoo database
    create_odoo_db(master_pwd, args.db_name, args.login, args.password, args.lang, args.country_code, args.phone, args.url, args.ignore_ssl)

