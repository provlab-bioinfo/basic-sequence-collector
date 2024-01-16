include { BUILD_SHEET } from '../../modules/local/build_sheet'

workflow VALIDATE_FOLDER {
    take:
        folder // file: /path/to/samplesheet.csv

    main:

        log.debug "Checking folder..."

        def illumina_files = { file -> file.name.lastIndexOf('_L001').with {it != -1 ? file.name[0..<it] : file.name} }
        Channel.fromFilePairs( params.illumina_search_path, flat: true, illumina).set{ illumina_reads }

        def nanopore_files = { file -> file.name.lastIndexOf('_').with {it != -1 ? file.name[0..<it] : file.name} }
        Channel.fromFilePairs( params.nanopore_search_path, flat: true , size: -1, nanopore_files).set{ nanopore_reads }

        reads = reads.map{ create_folder_read_channels(it) }
        BUILD_SHEET(reads).csv.collectFile(name: 'samplesheet.csv', keepHeader: true).map { it }.set { sheet }
        sheet.view()

        log.debug "Folder is good ✅"

    emit:
        sheet // channel: [ val(meta), [ illumina ], nanopore ]
        versions = BUILD_SHEET.out.versions

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

