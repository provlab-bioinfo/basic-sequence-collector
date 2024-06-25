workflow SAVE_SHEET {
    take:
        samplesheet // file: /path/to/samplesheet.csv

    main:
        log.debug "Saving original sample sheet..."
        COPY_SHEET(samplesheet)
        
    emit:
        samplesheet = COPY_SHEET.out.csv // file: /path/to/samplesheet.csv
        versions = COPY_SHEET.out.versions // channel: [ versions.yml ]
}

process COPY_SHEET {
    tag "$samplesheet"
    label 'process_medium'

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
        path samplesheet // file: /path/to/samplesheet.csv

    output:
        path '*.csv'       , emit: csv
        path "versions.yml", emit: versions

    when:
        task.ext.when == null || task.ext.when  

    script:
    """
    cp $samplesheet \\
        samplesheet.old.csv
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
} 

workflow PROCESS_SHEET {
    take:
        samplesheet // file: /path/to/samplesheet.csv
        output //path: //path/to/output

    main:
        CHECK_SHEET ( samplesheet , output )

    emit:
        samplesheet = CHECK_SHEET.out.samplesheet// file: /path/to/samplesheet.csv
        versions = CHECK_SHEET.out.versions // channel: [ versions.yml ]
}

process CHECK_SHEET {
    tag "$samplesheet"
    label 'process_medium'

    //conda "conda-forge::python=3.9.5"
    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/python:3.9--1' :
    //    'biocontainers/python:3.9--1' }"

    input:
        path samplesheet // file: /path/to/samplesheet.csv
        val output //path: //path/to/output

    output:
        path '*.csv'          , emit: samplesheet
        path '*.gz'           , emit: files
        path "versions.yml"   , emit: versions

    when:
        task.ext.when == null || task.ext.when  

    script:
    """
    check_samplesheet.py \\
        samplesheet.old.csv \\
        samplesheet."${params.label}".csv \\
        $output/fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}