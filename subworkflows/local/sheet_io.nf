workflow EXPORT_SHEET {
    take:
        data // format: [[id: id, ...],short1,short2,long]

    main:
        
        println "Starting PROCESS_FOLDER"
       
        //data.view()

        //Create the CSV with metamap values as individual columns
        def csvQuote = { v ->
            def s = (v == null) ? '' : v.toString()
            s.find(/[",\n]/) ? '"' + s.replace('"', '""') + '"' : s
        }

        data
            | map { samples ->
                // Union of all meta keys, in order of first appearance
                def metaKeys = samples.collectMany { it[0].keySet() as List }.unique()

                // Widest file count across rows
                def fileCols = ['short1', 'short2', 'long']
                def nFiles = samples.collect { it.size() - 1 }.max()
                
                def header = (metaKeys + fileCols).collect(csvQuote).join(',')

                def rows = samples.collect { sample ->
                    def meta  = sample[0]
                    def files = sample.size() > 1 ? sample[1..-1] : []

                    def metaVals = metaKeys.collect { k -> meta.containsKey(k) ? meta[k] : '' }
                    def fileVals = (0..<nFiles).collect { i -> i < files.size() ? files[i] : '' }

                    (metaVals + fileVals).collect(csvQuote).join(',')
                }

                ([header] + rows).join('\n') + '\n' }
            | collectFile(name: 'samplesheet.csv', storeDir: params.outdir)
            | map { it }
            | set { samplesheet }

    emit:
        data 
        samplesheet
}