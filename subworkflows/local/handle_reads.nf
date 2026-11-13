/**
* Concatenates list of reads into a single file.
*
* Will concatenate lists for each of Illumina R1 & R2 and ONT into a single file using the cat command.
* The read path will be to the published directory '${params.outdir}/${params.label}/'
*
* @take reads     tuple of metadata and reads to concatenate. Reads can be null, a single file, or list of files. E.g., [[id: id, ...],short1,short2,[long]].
* @emit data      tuple of metadata and cat'd reads. Each read is a single file with the path to the published directory. E.g., [[id: id, ...],short1,short2,long].
*/
workflow CONCAT_READS {
    take:
        reads

    main:

        read_pairs = reads.flatMap { meta, short1, short2, long1 ->
            [ R1: short1, R2: short2, ONT: long1 ]
                .findAll { type, files -> files }
                .collect { type, files -> [ meta + [read_type: type], files ] }
        }

        CONCAT_FASTQ(read_pairs)

        CONCAT_FASTQ.out.reads
            | map { meta, fastq ->  // Extract read_type and get publish dir
                def orig      = meta.findAll { k, v -> k != 'read_type' }
                def published = file("${params.outdir}/${params.label}/${fastq.name}")
                [ orig, meta.read_type, published ] }
            | groupTuple()
            | map { meta, types, files ->   // Re-assemble tuple based on read_type
                def byType = [types, files].transpose().collectEntries()
                [ meta, byType.R1 ?: null, byType.R2 ?: null, byType.ONT ?: null ] }
            | toSortedList  { a, b -> a[0].id <=> b[0].id }
            | flatMap
            | set { reads }

    emit:
        reads
}

/**
* Concatenates reads into a single file.
*
* Will concatenate reads into a single file using the cat command, and gzip if necessary.
* The read path will be to the work directory.
*
* @input reads      Tuple of metadata and reads to cat. Reads can be single files or list of files. Must contain at least one file. E.g., format: [[id: id, ...],short1,short2,long]
* @output reads     Tuple of metadata and cat'd reads. Each read is a single file and has the path to the work directory.
* @topic versions   Software versions used by the process.
*/
process CONCAT_FASTQ {
    tag "${meta.id}_${meta.read_type}.fastq.gz"
    publishDir "${params.outdir}/${params.label}", mode: 'copy', pattern: "*.fastq.gz"

    input:
        tuple val(meta), path(reads)

    output:
        tuple val(meta), path("*.fastq.gz"),    emit: reads
        path 'versions.yml',                    topic: versions

    script: 
        reads = reads instanceof List ? reads : [reads]
        reads = reads.sort().join(" ")
        suffix = params.suffix ? ".${params.suffix}" : ""
        output = "${meta.id}_${meta.read_type}" + suffix + ".fastq.gz"
        """
        for file in ${reads}; do
            if [[ "\$file" == *.gz || "\$file" == *.gzip ]]; then
                cat "\$file" >> "${output}"
            else                
                gzip -c "\$file" >> "${output}"
            fi
        done
        
        cat <<-END_VERSIONS > versions.yml
        ${task.process}:
            cat: \$(cat --version | sed -n '1s/.* //p')
            gzip: \$(gzip --version | sed -n '1s/.* //p')
        END_VERSIONS
        """
}