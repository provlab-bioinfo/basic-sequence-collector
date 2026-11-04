/**
* Converts metadata and reads to a CSV file.
*
* Reads will be assigned column names based on {params.outcols}, and is order-sensitive.
* Metadata will be expanded to individual columns.
* Missing values will be exported as an empty string.
*
* @take reads             Tuple of metadata and reads. E.g., [[id: id, ...],short1,short2,long].
* @emit reads             Identical to the @param reads, in case they are needed for downstream processes.
* @emit samplesheet       Path to the exported samplesheet.
*/
workflow EXPORT_SHEET {
    take:
        reads    // format: [[id: id, ...],short1,short2,long]

    main:       
        /**
        * Converts values to acceptable strings for CSV output
        *
        * Nulls become empty strings
        * Values with commas are wrapped with quotations marks.
        * Values with quotation marks have quotation marks doubled up and wrapped with quotation marks.
        *
        * @param v      A value to convert
        * @return       A acceptable string for CSV output
        */
        def csvQuote = { v ->
            def s = (v == null) ? '' : v.toString()
            s.find(/[",\n]/) ? '"' + s.replace('"', '""') + '"' : s
        }

        // Convert metadata to columns, add headers, export as CSV
        reads
            | map { samples ->                
                def metaKeys = samples.collectMany { it[0].keySet() as List }.unique()
                def fileCols = params.outcols.split(",") as List
                def nFiles = samples.collect { it.size() - 1 }.max()                
                def header = (metaKeys + fileCols).collect(csvQuote).join(',')
                def rows = samples.collect { sample ->
                    def meta  = sample[0]
                    def files = sample.size() > 1 ? sample[1..-1] : []
                    def metaVals = metaKeys.collect { k -> meta.containsKey(k) ? meta[k] : '' }
                    def fileVals = (0..<nFiles).collect { i -> i < files.size() ? files[i] : '' }
                    (metaVals + fileVals).collect(csvQuote).join(',') }
                ([header] + rows).join('\n') + '\n' }
            | collectFile(name: "samplesheet.${params.label}.csv", storeDir: "${params.outdir}/${params.label}")
            | map { it }
            | set { samplesheet }

    emit:
        reads        // format: [[id: id, ...],file1,file2,etc]
        samplesheet // format: /path/to/file
}

/**
* Converts a CSV file into metadata and reads
*
* Reads will be extracted based on {params.incols}, and must contain only a single file. The order of reads in the tuple will match 
*   the order of {params.incols}. Missing incols will be omitted from the reads output.
* Metadata will be created from all remaining columns.
* Empty strings will be assigned as null.
*
* TODO: Add check to make sure 'id' col is present
*
* @take samplesheet       Path to the samplesheet CSV. Must contain the column 'id'. E.g., /path/to/samplesheet.csv
* @emit reads             Tuple of metadata and reads. E.g., [[id: id, ...],short1,short2,long]
*/
workflow IMPORT_SHEET {
    take:
        samplesheet

    main:
        file_cols = params.incols.split(",") as List

        Channel.fromPath(samplesheet)
            | splitCsv(header: true, sep: ",")
            | map { row ->
                if (row.containsKey('id') == false) {
                    throw new Exception("Imported samplesheet does not contain the column 'id'. Import is aborted.") }
                return row }
            | map { row ->
                def meta = row.findAll { col, val -> !(col in file_cols) }
                def files = file_cols.collect { key -> row[key] ? file(row[key]) : null }
                return [ meta ] + files }
            | set { reads }

    emit: 
        reads
}