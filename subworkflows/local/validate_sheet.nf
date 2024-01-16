include { CHECK_SHEET } from '../../modules/local/check_sheet'

workflow VALIDATE_SHEET {
    take:
        samplesheet // file: /path/to/samplesheet.csv, format of [ meta, illumina1, illumina2, nanopore ]

    main:

        log.debug "Checking sample sheet..."

        CHECK_SHEET ( samplesheet ).csv.splitCsv ( header:true, sep:',' )        
            .map { create_sheet_read_channels(it) }
            .set { reads }

        log.debug "Sample sheet is good ✅"

    emit:
        reads      // channel: [ val(meta), [ illumina ], nanopore ]
        versions = CHECK_SHEET.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ illumina1, illumina2 ], nanopore ]
def create_sheet_read_channels(LinkedHashMap row) {
    
    def meta = [:]
    meta.id           = row.sample
    meta.single_end   = !(row.illumina1 == 'NA') && !(row.illumina2 == 'NA') ? false : true

    illumina1 = checkRead(row.illumina1)
    illumina2 = checkRead(row.illumina2)
    nanopore  = checkRead(row.nanopore)
    
    def array = []
    if ( meta.single_end ) {
        illumina = row.illumina1 == 'NA' ? illumina2 : illumina1
        array = [ meta, [ illumina ], nanopore]
    } else {
        array = [ meta, [ illumina1, illumina2 ], nanopore ]
    } 
    return array 
}

def checkRead(String read) {
    if (read == 'NA' | read == '') return 'NA'
    if (!file(read).exists())    exit 1, "ERROR: Please check input samplesheet -> FASTQ file does not exist!\n   ${read}"        
    if (file(read).size() == 0)  exit 1, "ERROR: Please check input samplesheet -> FASTQ file is empty!\n   ${read}"
    return file(read)
}