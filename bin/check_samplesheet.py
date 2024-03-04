#!/usr/bin/env python

# TODO nf-core: Update the script to check the samplesheet
# This script is based on the example at: https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv

import os, sys, errno, argparse, pathlib, gzip, shutil

def parse_args(args=None):
    Description = "Reformat nf-core/pathogen samplesheet file and check its contents."
    Epilog = "Example usage: python check_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")
    parser.add_argument("PATH_OUT", help="Path to FASTQ output.")
    return parser.parse_args(args)

def print_error(error, context="", context_str=""):
    # error_str = f"ERROR: Please check samplesheet -> {error}"
    # if context != "" and context_str != "":
    error_str = f"ERROR: Please check samplesheet -> {error}\n   {context.strip()}: '{context_str.strip()}'"
    print(error_str)
    sys.exit(1)

def process_samples(ID, files, path_out, append = "NA"):

    if len(files) == 0:
        return ""

    def isGZIP(filepath):
        with open(filepath, 'rb') as test_f:
            return test_f.read(2) == b'\x1f\x8b'

    tempFiles = []
    append = "" if append == "NA" else append
    outFile = open(ID + append + ".fastq.gz", 'wb')

    for file in files.split(";"):
        # Check if proper extension
        if file.upper() == 'NA':
            continue
        elif file.find(" ") != -1:
            print_error("FastQ file must not contain spaces!", "File", file)
        elif not file.endswith((".fastq.gz",".fq.gz",".fq",".gz")):
            print_error("FastQ file does not have extension '.fastq.gz', '.fq.gz', '.fastq', or '.fq'!", "File", file)

        # Check if exists
        if not os.path.isfile(file):
            print_error("FastQ file does not exist!", "File", file)
        
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

    outPath = os.path.join(path_out, outFile.name)
    outFile.close()

    return outPath

# TODO nf-core: Update the check_samplesheet function
def check_samplesheet(file_in, file_out, path_out):
    """
    This function checks that the samplesheet follows the following structure:
    sample,illumina1,illumina2,nanopore
    SAMEA6451102,read_1.fastq.gz,read_2.fastq.gz,longread.fastq.gz

    For an example see:
    https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv
    """

    sample_mapping_dict = {}
    with open(file_in, "r") as fin:
        import re
        regex=re.compile('^#')
        
        ## Check header
        MIN_COLS = 2
        # TODO nf-core: Update the column names for the input samplesheet
        HEADER = ["ID", "illumina1", "illumina2", "nanopore"]
        header = [x.strip('"') for x in fin.readline().strip().split(",")]
        if header[: len(HEADER)] != HEADER:
            print("ERROR: Please check samplesheet header -> {} != {}".format(",".join(header), ",".join(HEADER)))
            sys.exit(1)
        
        ## Check sample entries
        for line in fin:
            if re.match(regex, line):
                continue
            lspl = [x.strip().strip('"') for x in line.strip().split(",")]

            # Check valid number of columns per row
            if len(lspl) < len(HEADER):
                print_error(
                    "Invalid number of columns (minimum = {})!".format(len(HEADER)),
                    "Line",
                    line
                )
            num_cols = len([x for x in lspl if x])
            if num_cols < MIN_COLS:
                print_error(
                    "Invalid number of populated columns (minimum = {})!".format(MIN_COLS),
                    "Line",
                    line,
                )
            
            ## Check sample name entries
            id, illumina1, illumina2, nanopore = lspl[: len(HEADER)]
            id = id.replace(" ", "_")
            if not id:
                print_error("Sample entry has not been specified!", "Line", line)
            
            illumina1 = process_samples(id, illumina1, path_out, "_R1")
            illumina2 = process_samples(id, illumina2, path_out, "_R2")
            nanopore = process_samples(id, nanopore, path_out, "")
                       
            ## Create sample mapping dictionary = { sample: [ single_end, illumina1, illumina2 ] }
            sample_info = [illumina1, illumina2, nanopore]
            if id not in sample_mapping_dict:
                sample_mapping_dict[id] = [sample_info]
            else:
                if sample_info in sample_mapping_dict[id]:
                    print_error("Samplesheet contains duplicate rows!", "Line", line)
                else:
                    sample_mapping_dict[id].append(sample_info)

    ## Write validated samplesheet with appropriate columns
    if len(sample_mapping_dict) > 0:
        out_dir = os.path.dirname(file_out)
        pathlib.Path(out_dir).mkdir(parents = True, exist_ok = True)
        with open(file_out, "w") as fout:
            fout.write(",".join(["id", "illumina1", "illumina2", "nanopore"]) + "\n")
            for sample in sorted(sample_mapping_dict.keys()):

                ## Check that multiple runs of the same sample are of the same datatype
                if not all(x[0] == sample_mapping_dict[sample][0][0] for x in sample_mapping_dict[sample]):
                    print_error("Multiple runs of a sample must be of the same datatype!", "Sample: {}".format(sample))

                for idx, val in enumerate(sample_mapping_dict[sample]):
                    fout.write(",".join(["{}_T{}".format(sample, idx + 1)] + val) + "\n")
    else:
        print_error("No entries to process!", "Samplesheet: {}".format(file_in))

def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT, args.PATH_OUT)

if __name__ == "__main__":
    sys.exit(main())