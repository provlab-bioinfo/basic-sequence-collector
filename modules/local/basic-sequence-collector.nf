workflow COLLECT {
    take:
        input // file: /path/to/samplesheet.csv
        outdir
        label
        prefix

    main:
        COLLECT_FILES(input, outdir, label, prefix)

    emit:
        samplesheet = COLLECT_FILES.out.samplesheet
        versions = COLLECT_FILES.out.versions

}

process COLLECT_FILES {
    tag "$folder"
    label 'process_medium'

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"

    input:
        tuple path(input), path(outdir), val(label), val(prefix)

    output:
        path '*.csv'       , emit: samplesheet
        path "versions.yml", emit: versions

    when:
        task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/rnaseq/bin/
        """
        nextflow run https://github.com/provlab-bioinfo/basic-sequence-collector \
        --input ${input} \
        --outdir ${outdir} \
        --label ${label} \
        -r main

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python --version | sed 's/Python //g')
        END_VERSIONS
        """
}
