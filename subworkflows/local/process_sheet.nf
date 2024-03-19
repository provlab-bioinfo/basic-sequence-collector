workflow PROCESS_SHEET {
    take:
        samplesheet // file: /path/to/samplesheet.csv
        output //path: //path/to/output

    main:
        log.debug "Checking sample sheet..."
        CHECK_SHEET ( samplesheet , output ).csv.collectFile(name: 'samplesheet.csv', keepHeader: true).map { it }.set { samplesheet }
        log.debug "Sample sheet is good ✅"

    emit:
        samplesheet // file: /path/to/samplesheet.csv
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
        path samplesheet // file: /path/to/samplesheet.csv
        val output //path: //path/to/output

    output:
        path '*.csv'       , emit: csv
        path '*.gz'        , emit: files
        path "versions.yml", emit: versions

    when:
        task.ext.when == null || task.ext.when  

    script:
    """
    check_samplesheet.py \\
        $samplesheet \\
        samplesheet2.csv \\
        $output/fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}