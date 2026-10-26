workflow EXPORT_SHEET {
    take:
        data    // format: [[id: id, ...],short1,short2,long]

    main:       
        //Create the CSV with metamap values as individual columns
        def csvQuote = { v ->
            def s = (v == null) ? '' : v.toString()
            s.find(/[",\n]/) ? '"' + s.replace('"', '""') + '"' : s
        }

        data
            | map { samples ->                
                def metaKeys = samples.collectMany { it[0].keySet() as List }.unique() // Union of all meta keys, in order of first appearance
                def fileCols = ['short1', 'short2', 'long']
                def nFiles = samples.collect { it.size() - 1 }.max()                
                def header = (metaKeys + fileCols).collect(csvQuote).join(',')
                def rows = samples.collect { sample ->
                    def meta  = sample[0]
                    def files = sample.size() > 1 ? sample[1..-1] : []
                    def metaVals = metaKeys.collect { k -> meta.containsKey(k) ? meta[k] : '' }
                    def fileVals = (0..<nFiles).collect { i -> i < files.size() ? files[i] : '' }
                    (metaVals + fileVals).collect(csvQuote).join(',') }
                ([header] + rows).join('\n') + '\n' }
            | collectFile(name: 'samplesheet.csv', storeDir: "${params.outdir}/${params.label}")
            | map { it }
            | set { samplesheet }

    emit:
        data            // format: [[id: id, ...],short1,short2,long]
        samplesheet     // format: /path/to/file
}

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
                [ meta, byType.R1 ?: [], byType.R2 ?: [], byType.R3 ?: [] ] }
            | set {data}

    emit:
        data
       // versions = CONCAT_FASTQ.out.versions
}

process CONCAT_FASTQ {
    tag "${meta.read_type}"
    publishDir "${params.outdir}/${params.label}", mode: 'copy'

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
