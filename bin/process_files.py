#!/usr/bin/env python

import os, sys, errno, argparse, gzip, shutil

def parse_args(args=None):
    Description = "Move the files and update the samplesheet."
    Epilog = "Example usage: python stage_files.py <samplesheet> <output>"
    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument('-i', '--ID', help="The ID of the output file.")
    parser.add_argument('-f', '--files', help="The list of files", nargs='*')
    parser.add_argument('-a', '--append', help='Suffix to append. Should be "", "_R1", or "_R2"', default = "NA", required = False)
    return parser.parse_args(args)

def isGZIP(filepath):
    with open(filepath, 'rb') as test_f:
        return test_f.read(2) == b'\x1f\x8b'

def main(args=None):
    args = parse_args(args)
    tempFiles = []
    
    append = "" if args.append == "NA" else args.append
    outFile = open(args.ID + append + ".fastq.gz", 'wb')

    for file in args.files:
        # print(f"Processing {file}")

        if not os.path.isfile(file):
            raise FileNotFoundError
        
        # Convert to GZIP, if necessary
        if not isGZIP(file):
            gzipFile = file + ".gz"
            with open(file, 'rb') as src, gzip.open(file + ".gz", 'wb') as dst:
                dst.writelines(src)
                tempFiles.append(dst.name)
            file = gzipFile

        # Concat to out file
        with open(file, 'rb') as inFile:
            shutil.copyfileobj(inFile, outFile)
        
    # Remove the newly converted GZIP files
    for file in tempFiles:
        os.remove(file)

    outPath = os.path.abspath(outFile.name)
    outFile.close()

    return outPath

if __name__ == "__main__":
    sys.exit(main())