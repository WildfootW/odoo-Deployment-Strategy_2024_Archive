#! /usr/bin/env python3
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyleft (ɔ) 2024 wildfootw <wildfootw@wildfoo.tw>
#
# Distributed under the same license as odooBundle-Codebase.

import argparse
import psycopg2
import sys
import time

def check_db_online(args):
    """
    Check if the database server is online and reachable.
    """
    try:
        conn = psycopg2.connect(user=args.db_user, host=args.db_host, port=args.db_port, password=args.db_password, dbname="postgres")
        conn.close()
        return True
    except psycopg2.OperationalError as e:
        print("Database connection failure: %s" % e, file=sys.stderr)
        return False

def check_db_initialized(conn):
    """
    Check if the specified database is initialized (contains data).
    """
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM ir_model LIMIT 1;")
        return True
    except psycopg2.Error:
        return False

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('--db_host', required=True)
    arg_parser.add_argument('--db_port', required=True)
    arg_parser.add_argument('--db_user', required=True)
    arg_parser.add_argument('--db_password', required=True)
    arg_parser.add_argument('--database', required=False)  # Only required when checking initialization
    arg_parser.add_argument('--timeout', type=int, default=5)
    arg_parser.add_argument('--check-init', action='store_true', help="Check if the database is initialized")

    args = arg_parser.parse_args()

    start_time = time.time()
    connected = False  # Flag to indicate if connection was successful
    db_initialized = False
    error = ''

    while (time.time() - start_time) < args.timeout:
        if not args.check_init:
            if check_db_online(args):
                connected = True
                break
            else:
                time.sleep(1)
        else:
            # Check if the database is initialized
            if not args.database:
                print("Error: --database is required when using --check-init", file=sys.stderr)
                sys.exit(1)

            try:
                conn = psycopg2.connect(user=args.db_user, host=args.db_host, port=args.db_port, password=args.db_password, dbname=args.database)
                connected = True
                db_initialized = check_db_initialized(conn)
                conn.close()
                break
            except psycopg2.OperationalError as e:
                error = e
                time.sleep(1)

    # After the loop, check if we were able to connect
    if not connected:
        if error:
            print("Database connection failure: %s" % error, file=sys.stderr)
        else:
            print("Failed to connect to the database within the timeout period.", file=sys.stderr)
        sys.exit(1)

    # If we are checking initialization and the database is not initialized
    if args.check_init and not db_initialized:
        sys.exit(1)  # Exit code 1 to indicate uninitialized database

    # If everything is okay
    sys.exit(0)

