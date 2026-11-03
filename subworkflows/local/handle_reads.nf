workflow CONCAT_READS {
    take:
        reads    // format: [[id: id, ...],short1,short2,long]

    main:

        read_pairs = reads.flatMap { meta, short1, short2, long1 ->
            [ R1: short1, R2: short2, ONT: long1 ]
                .findAll { type, files -> files }
                .collect { type, files -> [ meta + [read_type: type], files ] }
        }

        CONCAT_FASTQ(read_pairs)

        CONCAT_FASTQ.out.reads
            | map { meta, fastq ->
                def orig      = meta.findAll { k, v -> k != 'read_type' }
                def published = file("${params.outdir}/${params.label}/${fastq.name}")
                [ orig, meta.read_type, published ] }
            | groupTuple()
            | map { meta, types, files ->
                def byType = [types, files].transpose().collectEntries()
                [ meta, byType.R1 ?: null, byType.R2 ?: null, byType.ONT ?: null ] }
            | set {data}

    emit:
        data
}

process CONCAT_FASTQ {
    tag "${meta.id}.${meta.read_type}"
    publishDir "${params.outdir}/${params.label}", mode: 'copy', pattern: "*.fastq.gz"

    input:
        tuple val(meta), path(reads)

    output:
        tuple val(meta), path("*.fastq.gz"),    emit: reads
        path 'versions.yml',                    topic: versions
        //tuple val("${task.process}"), val('cat'), eval('cat --version | sed -n "1s/.*) //p"'), topic: versions

    script: 
        reads = reads instanceof List ? reads : [reads]
        reads = reads.sort().join(" ")
        """
        cat ${reads} > "${meta.id}_${meta.read_type}.fastq.gz"

        cat <<-END_VERSIONS > versions.yml
        ${task.process}:
            cat: \$(cat --version | sed -n '1s/.*) //p')
        END_VERSIONS
        """
}
