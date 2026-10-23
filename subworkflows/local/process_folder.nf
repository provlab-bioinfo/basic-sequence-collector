workflow PROCESS_FOLDER {
    take:
        folder // file: /path/to/samplesheet.csv

    main:
        
        println "Starting PROCESS_FOLDER"

        illumina_reads = Channel.empty()
        nanopore_reads = Channel.empty()

        // Get the Illumina reads
        illumina_search_path = makeFastqSearchPath( params.illumina_suffixes, params.fastq_exts )
        def illumina_files = { file -> file.name.lastIndexOf('_L001').with {it != -1 ? file.name[0..<it] : file.name} }
        Channel.fromFilePairs( illumina_search_path, flat: true, illumina_files) 
            | filter { pair -> !pair[0].startsWith('Undetermined') }
            | map { items ->
                    def sample_id = items.head()
                    def sample_barcode = (sample_id =~ /^(\d+)_/)[0][1]
                    return [[id: sample_id, barcode: sample_barcode]] + items.tail() + [""]}
            | set { illumina_reads }

        // Get the Nanopore reads
        nanopore_search_path = makeFastqSearchPath( params.nanopore_suffixes, params.fastq_exts )  
        def nanopore_files = { file -> file.name.lastIndexOf('_').with {it != -1 ? file.name[0..<it] : file.name} }
        Channel.fromFilePairs( nanopore_search_path, size: -1, nanopore_files) 
            | filter { pair -> !pair[0].startsWith('unclassified') }
            | map { items ->
                    def sample_id = items.head()
                    def sample_barcode = (sample_id =~ /_barcode(\d+)_/)[0][1]
                    return [[id: sample_id, barcode: sample_barcode], "",""] + items.tail() }
            | set { nanopore_reads }

        // Combine the reads
        illumina_reads
            | concat(nanopore_reads)//.map{ create_folder_read_channels(it) }
            | map { list -> list.collect { it ?: "" } }
            | map {items ->
                    def meta = items.head()
                    def new_meta = [meta + [id: [params.prefix, meta.id, params.suffix].findAll().join('_')]]
                    return new_meta + items.tail() }
            | set { reads }

        // Load the pipeline worksheet metadata, if it exists
        Channel.fromPath( "${params.input}/*PipelineWorksheet*" )
            | branch { f ->
                exists: f.exists()
                    return f
                missing: true
                    return f }
            | set { worksheet }

        // Join the reads and metadata, if worksheet exists
        GET_METADATA(worksheet.exists)
        GET_METADATA.out.csv
            | splitCsv(header: true)
            | map { row -> row as Map }
            | map { meta_pw -> [ meta_pw.barcode, meta_pw ] }
            | join( reads.map { meta_reads -> [ meta_reads[0].barcode ] + meta_reads } )
            | map { tuple ->
                def meta_pw = tuple[1]
                def meta_reads = tuple[2]
                def merged = (meta_reads + meta_pw).findAll { k, v -> k != 'barcode' }
                def files  = tuple.drop(3)          // everything after meta_b
                [ merged ] + files }
            | set { merged }

        // Default to reads if the pipeline worksheet does not exist
        merged
            | toList()             
            | concat( reads.toList() )         // Appends the backup channel (also collected)
            | first { !it.isEmpty() }               // Grabs the first list that isn't empty
            | flatMap()
            | set { data }
        
    emit:
        data // channel: [[id: id, ...],short1,short2,long]
}

def makeFastqSearchPath(fastqSuffixes, fastq_exts) {
    [fastqSuffixes, fastq_exts]
        .combinations()
        .collect { suffix, ext -> "${params.input}/**/${suffix}${ext}" }
}

process GET_METADATA {
    tag "$ws_path"
    label 'process_medium'
    debug true 

    input:
        path ws_path

    output:
        path '*.csv'       , emit: csv

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        #!/usr/bin/env python3

        import pipeline_worksheet_reader as pwr
        
        r = pwr.PipelineWorksheet("$ws_path").getSamples()
        r.columns = r.columns.str.lower()
        r.to_csv('metadata.csv', index=False)
        """
}