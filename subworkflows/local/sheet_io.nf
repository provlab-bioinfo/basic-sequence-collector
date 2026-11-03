workflow EXPORT_SHEET {
    take:
        data    // format: [[id: id, ...],short1,short2,long]

    main:       
        def csvQuote = { v ->
            def s = (v == null) ? '' : v.toString()
            s.find(/[",\n]/) ? '"' + s.replace('"', '""') + '"' : s
        }

        data
            | map { samples ->                
                def metaKeys = samples.collectMany { it[0].keySet() as List }.unique() // Union of all meta keys, in order of first appearance
                def fileCols = params.output_cols.split(",") as List //['short1', 'short2', 'long']
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
        data        // format: [[id: id, ...],file1,file2,etc]
        samplesheet // format: /path/to/file
}

workflow IMPORT_SHEET {
    take:
        sheet   // format: /path/to/file

    main:
        file_cols = params.input_cols.split(",") as List

        Channel.fromPath(sheet)
            | splitCsv(header: true, sep: ",")
            | map { row ->
                def meta = row.findAll { col, val -> !(col in file_cols) }
                def files = file_cols.collect { key -> row[key] ? file(row[key]) : null }
                return [ meta ] + files }
            | set { data }

        data.view()

    emit: 
        data // format: [[id: id, ...],file1,file2,etc]
}