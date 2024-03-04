#!/usr/bin/env python

import os, sys, errno, argparse

def parse_args(args=None):
    Description = "Move the files and update the samplesheet."
    Epilog = "Example usage: python stage_files.py <samplesheet> <output>"
    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("samplesheet", help="Input samplesheet file.")
    parser.add_argument("output", help="/path/to/output")
    return parser.parse_args(args)

def check_samplesheet(file_in, file_out):
    print("")

def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT)

if __name__ == "__main__":
    sys.exit(main())