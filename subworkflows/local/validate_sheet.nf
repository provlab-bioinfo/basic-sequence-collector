workflow VALIDATE_SHEET {
    take:
        samplesheet // file: /path/to/samplesheet.csv, format of [ meta, illumina1, illumina2, nanopore ]

    main:

        log.debug "Checking sample sheet..."

        CHECK_SHEET ( samplesheet ).csv.collectFile(name: 'samplesheet.csv', keepHeader: true).map { it }.set { sheet }
            //.splitCsv ( header:true, sep:',' )        
            //.map { create_sheet_read_channels(it) }
            //.set { sheet }

        log.debug "Sample sheet is good ✅"

    emit:
        sheet      // channel: [ val(meta), [ illumina ], nanopore ]
        versions = CHECK_SHEET.out.versions // channel: [ versions.yml ]
}

process CHECK_SHEET {
    tag "$samplesheet"
    label 'process_medium'

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
        path samplesheet

    output:
        path '*.csv'       , emit: csv
        path '*.gz'        , emit: files
        path "versions.yml", emit: versions

    when:
        task.ext.when == null || task.ext.when  

    script: // This script is bundled with the pipeline, in nf-core/rnaseq/bin/
    """
    check_samplesheet.py \\
        $samplesheet \\
        samplesheet2.csv \\
        ${params.outdir}fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}


// Function to get list of [ meta, [ illumina1, illumina2 ], nanopore ]
def create_sheet_read_channels(LinkedHashMap row) {
    
    meta = row.id
    illumina1 = checkReads(row.illumina1)
    illumina2 = checkReads(row.illumina2)
    nanopore  = checkReads(row.nanopore)
    
    if (row.illumina1 == '' && row.illumina2 != '') {
        illumina1 = illumina2
        illumina2 = ''
    }

    return [ meta, illumina1, illumina2, nanopore ] 
}

def checkReads(List reads) {
    out = []
    if (reads.size()) {       
        for (read in reads) {
            if (read == 'NA' | read == '') continue
            if (!file(read).exists())    exit 1, "ERROR: Please check input samplesheet -> FASTQ file does not exist!\n   ${read}"        
            if (file(read).size() == 0)  exit 1, "ERROR: Please check input samplesheet -> FASTQ file is empty!\n   ${read}"
            out << file(read)
        }
    } else {
        out = [""]
    }

    return out
}

def checkRead(String read) {
    if (read == 'NA' | read == '') return 'NA'
    if (!file(read).exists())    exit 1, "ERROR: Please check input samplesheet -> FASTQ file does not exist!\n   ${read}"        
    if (file(read).size() == 0)  exit 1, "ERROR: Please check input samplesheet -> FASTQ file is empty!\n   ${read}"
    return file(read)
}