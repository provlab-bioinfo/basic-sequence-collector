//
// Check input samplesheet and get read channels
//

include { SAMPLESHEETCHECK } from '../../modules/local/samplesheetcheck'
include { SAMPLESHEETBUILD } from '../../modules/local/samplesheetbuild'

workflow SHEET_CHECK {
    take:
        samplesheet // file: /path/to/samplesheet.csv

    main:

        log.debug "Checking sample sheet..."

        SAMPLESHEETCHECK ( samplesheet ).csv.splitCsv ( header:true, sep:',' )        
            .map { create_sheet_read_channels(it) }
            .set { reads }

        log.debug "Sample sheet is good ✅"

    emit:
        reads      // channel: [ val(meta), [ illumina ], nanopore ]
        versions = SAMPLESHEETCHECK.out.versions // channel: [ versions.yml ]
}

workflow FOLDER_CHECK {
    take:
        folder // file: /path/to/samplesheet.csv

    main:

        log.debug "Checking folder..."

        if (params.platform.equalsIgnoreCase('illumina')) {
            def grouping = { file -> file.name.lastIndexOf('_L001').with {it != -1 ? file.name[0..<it] : file.name} }
            Channel.fromFilePairs( params.illumina_search_path, flat: true, grouping).set{ reads }
        } else if (params.platform.equalsIgnoreCase("nanopore")) {
            def grouping = { file -> file.name.lastIndexOf('_').with {it != -1 ? file.name[0..<it] : file.name} }
            Channel.fromFilePairs( params.nanopore_search_path, flat: true , size: -1, grouping).set{ reads }
        } else {
            exit 1, "Platform must be either 'illumina' or 'nanopore'!" 
        }

        reads = reads.map{ create_folder_read_channels(it) }

        SAMPLESHEETBUILD(reads).csv.collectFile(name: 'samplesheet.csv', keepHeader: true).map { it }.set { sheet }

        sheet.view()

        log.debug "Folder is good ✅"

    emit:
        sheet // channel: [ val(meta), [ illumina ], nanopore ]
        versions = SAMPLESHEETBUILD.out.versions

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

// Function to get list of [ meta, illumina1, illumina2, nanopore ]
def create_folder_read_channels(List row) {
    
    def meta = [:]
    id = row[0]
   
    illumina1 = illumina2 = nanopore = ''

    if (params.platform.equalsIgnoreCase('illumina')) {   
        illumina1 = checkRead(row[1].toString())
        if (row.size() > 2) illumina2 = checkRead(row[2].toString())
    } else if (params.platform.equalsIgnoreCase('nanopore')) {
        nanopore = checkRead(row[1].toString())
    }
    
    array = [ id, illumina1, illumina2, nanopore ]
    return array
}

// def createSampleSheet(fileName) {
//     import org.apache.commons.csv.CSVPrinter
//     def FILE_HEADER = ['ID','illumina1','illumina2','nanopore']    
//     def csvFilePrinter = new CSVPrinter(fileWriter, CSVFormat.DEFAULT)
//     csvFilePrinter.printRecord(FILE_HEADER)
//     reads.each{ read -> csvFilePrinter.printRecord(read)}
//     return
// }

def checkRead(String read) {
    if (read == 'NA' | read == '') return 'NA'
    if (!file(read).exists())    exit 1, "ERROR: Please check input samplesheet -> FASTQ file does not exist!\n   ${read}"        
    if (file(read).size() == 0)  exit 1, "ERROR: Please check input samplesheet -> FASTQ file is empty!\n   ${read}"
    return file(read)
}