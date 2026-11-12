/**
* Searches for Illumina and ONT reads and adds metadata, if present.
*
* Will search for Illumina R1 & R2 and ONT reads in target folder, matching on barcode as determined by 
*   params.illumina_suffixes and params.nanopore_suffixes when RE'd with the filenames.
* Metadata will be parsed from the pipeline worksheet, if present, and merged based on barcode.
* ID will be generated from {params.prefix}_idx{barcode}_{params.suffix} and files will have the format {id}_[R1|R2|ONT].fastq.gz
*
* @input folder     Path to the target folder. E.g., /path/to/folder/
* @emit reads     Tuple of metadata and reads. Each read can be null, a single file, or a list of files. E.g., [[id: id, ...],short1,short2,long]
*/
workflow PROCESS_FOLDER {
    take:
        folder

    main:
        
        println "Starting PROCESS_FOLDER"

        illumina_reads = Channel.empty()
        nanopore_reads = Channel.empty()

       // folder = new File(folder).getCanonicalPath()

        if (!new File(folder).exists()) {error("ERROR ~ Cannot find input folder. No such file or directory: ${folder}")}

        // Get the Illumina reads
        illumina_search_path = makeFastqSearchPath("${folder}", params.illumina_suffixes, params.fastq_exts )
        def illumina_files = { file -> file.name.lastIndexOf('_L001').with {it != -1 ? file.name[0..<it] : file.name} }
        Channel.fromFilePairs( illumina_search_path, flat: true, illumina_files) 
            | filter { pair -> !pair[0].startsWith('Undetermined') }
            | map { items ->
                    def sample_id = items.head()
                    def sample_barcode = (sample_id =~ /^(\d+)_/)[0][1].replaceFirst(/^0+/, '')
                    return [[id: sample_id, barcode: sample_barcode]] + items.tail() + [null]}
            | set { illumina_reads }

        // Get the Nanopore reads
        nanopore_search_path = makeFastqSearchPath("${folder}", params.nanopore_suffixes, params.fastq_exts )  
        def nanopore_files = { file -> file.name.lastIndexOf('_').with {it != -1 ? file.name[0..<it] : file.name} }
        Channel.fromFilePairs( nanopore_search_path, size: -1, nanopore_files) 
            | filter { pair -> !pair[0].startsWith('unclassified') }
            | map { items ->
                    def sample_id = items.head()
                    def sample_barcode = (sample_id =~ /_barcode(\d+)_/)[0][1].replaceFirst(/^0+/, '')
                    return [[id: sample_id, barcode: sample_barcode]] + [null,null] + items.tail() }
            | set { nanopore_reads }

        // Combine the reads
        illumina_reads
            | concat(nanopore_reads)
            | map { list -> list.collect { it ?: "" } }
            | map { items ->
                    def meta = items.head()
                    def name = "idx" + meta.barcode
                    def new_meta = [meta + [id: [params.prefix, name].findAll().join('_')]] // Add the prefix/suffix
                    return new_meta + items.tail() }
            | ifEmpty { error("ERROR ~ No FASTQ files found in the input folder: ${folder}") }
            | set { all_reads }

        println("All read checked")

        // Load the pipeline worksheet metadata
        Channel.fromPath( params.ignore_metadata ? "${folder}/this/doesnt/exist" : "${folder}/*PipelineWorksheet*" )
            | branch { f ->
                exists: f.exists()
                    return f
                missing: true
                    return f }
            | set { worksheet }

        // Join the reads and metadata, if pipeline worksheet exists
        GET_METADATA(worksheet.exists)
        GET_METADATA.out.metadata
            | splitCsv(header: true)
            | map { row -> row as Map }
            | map { meta_pw -> [ meta_pw.barcode, meta_pw ] }
            | join( all_reads.map { meta_reads -> [ meta_reads[0].barcode ] + meta_reads } ) //  Merge on the barcode
            | map { tuple ->
                def meta_pw = tuple[1]
                def meta_reads = tuple[2]
                def merged = (meta_reads + meta_pw)
                def files  = tuple.drop(3)
                [ merged ] + files }
            | set { merged }

        // Default to reads if the pipeline worksheet does not exist
        merged
            | toList()             
            | concat( all_reads.toList() )
            | first { !it.isEmpty() }
            | flatMap()
            | map { tuple ->
                def meta = tuple[0]
                def strip = meta.findAll { k, v -> k != 'barcode' } // Remove the barcode column
                def files  = tuple.drop(1)          
                [ strip ] + files }
            | set { reads }

    emit:
        reads
}

/**
* Generates the search strings for reads
*
* Will concatenate lists for each of Illumina R1 & R2 and ONT FASTQ files into a single file using the cat command.
* The read path will be to the published directory '${params.outdir}/${params.label}/'
*
* @param dir                The target directory
* @param fastqSuffixes      Suffixes for the Illumina and ONT reads. Typically _R[1|2] and _barcode[1-9], respectively.
* @param fastqExtensions    Acceptable extensions for FASTQ files (e.g., .fastq, .fastq.gz, fq, fq.gz)
* @return                   All combinations of ${dir}/{**}/${fastqSuffixes}${fastqExtensions}              
*/
def makeFastqSearchPath(dir, fastqSuffixes, fastqExtensions) {
    [fastqSuffixes, fastqExtensions]
        .combinations()
        .collect { suffix, ext -> ["${dir}/${suffix}${ext}","${dir}/**/${suffix}${ext}"] }
        .flatten()
}

/**
* Gets metadata from the pipeline worksheet.
*
* Creates a .CSV containing metadata. Must contain the column 'barcode' to merge with the found reads.
*
* @input worksheet      Path to the pipeline worksheet. E.g., /path/to/*PipelineWorksheet*.xlsx.
* @emit metadata        Path to the metadata .CSV. E.g., /path/to/csv.
* @topic version        Software versions used by the process.
*/
process GET_METADATA {
    tag "$worksheet"
    label 'process_medium'

    input:
        path worksheet

    output:
        path 'metadata.csv',    emit: metadata
        path 'versions.yml',    topic: versions

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        #!/usr/bin/env python3

        import pipeline_worksheet_reader as pwr
        
        r = pwr.PipelineWorksheet("$worksheet").getMetaData()
        r.columns = r.columns.str.lower()
        r.to_csv('metadata.csv', index=False)

        from importlib.metadata import version
        import platform
        process = "${task.process}"
        with open("versions.yml", "w", encoding="utf-8") as file:
            file.write(f"{process}:\\n")
            file.write(f"    python: {platform.python_version()}\\n")
            file.write(f"    pipeline_worksheet_reader: {version('pipeline_worksheet_reader')}\\n")
        """
}