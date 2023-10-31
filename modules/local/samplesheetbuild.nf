process SAMPLESHEETBUILD {
    tag "$folder"
    label 'process_medium'

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
        tuple val(id), val(illumina1), val(illumina2), val(nanopore)

    output:
        path '*.csv'       , emit: csv
        path "versions.yml", emit: versions

    when:
        task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/rnaseq/bin/
        """
        touch ${id}_samplesheet.csv
        echo "ID,illumina1,illumina2,nanopore" >> ${id}_samplesheet.csv
        echo "${id},${illumina1},${illumina2},${nanopore}" >> ${id}_samplesheet.csv

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python --version | sed 's/Python //g')
        END_VERSIONS
        """
}