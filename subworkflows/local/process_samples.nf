// workflow PROCESS_SAMPLES {
//     take:
//         reads // channel: [ id, [ illumina1, illumina2 ], nanopore ]

//     main:
//         log.debug "Staging files...";
        
//         reads.view { "Reads: ${it}" };
//         // reads.map { id, illumina, nanopore -> id }.view();//.set { sampleID }
//         // reads.map { id, illumina, nanopore -> [ id, illumina[0], "_R1" ] } /*| PROCESS_READ */| set { illumina1 } | view
//         // reads.map { id, illumina, nanopore -> [ id, illumina[1], "_R2" ] } | PROCESS_READ | set { illumina2 }
//         reads.map { id, illumina, nanopore -> tuple( id, nanopore, "NA" ) } | PROCESS_READ | set { nanopore } 
   
//         nanopore.reads.view{ "Processed reads: ${it}" };

//         output = Channel.empty()//[ sampleID, [ illumina1.out.reads, illumina2.out.reads ], nanopore.out.reads ]

//         log.debug "Folder is good ✅";

//     emit:
//         reads = output // channel: [ id, [ illumina1, illumina2 ], nanopore ]
//         versions = Channel.empty()//illumina1.out.versions
// }

// process PROCESS_READ {
//     label 'process_medium'

//     input:
//         tuple val(id), val(files), val(append)

//     conda "conda-forge::python=3.9.5"
//     container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
//         'https://depot.galaxyproject.org/singularity/python:3.9--1' :
//         'biocontainers/python:3.9--1' }"

//     output:
//         path '*.fastq.gz' , emit: reads
//         path "versions.yml", emit: versions

//     when:
//         task.ext.when == null || task.ext.when  

//     script: 
//     """
//     process_files.py \\
//         --ID $id \\
//         --files $files \\
//         --append $append

//     cat <<-END_VERSIONS > versions.yml
//     "${task.process}":
//         python: \$(python --version | sed 's/Python //g')
//     END_VERSIONS
//     """
// }

// process GZIP_FASTQ {
//     label 'process_medium'

//     input:
//         path fileToCheck

//     output:
//         path "${fileToCheck}.gz" when: !fileToCheck.endsWith('.gz'), emit: file
//         path fileToCheck when: fileToCheck.endsWith('.gz'), emit: file
//         path "versions.yml", emit: versions

//     when:
//         task.ext.when == null || task.ext.when  

//     script: 
//     """
//     if [[ ${fileToCheck} == *.fastq || ${fileToCheck} == *.fq ]]
//     then
//         gzip -c ${fileToCheck} > ${fileToCheck}.gz
//     fi

//     cat <<-END_VERSIONS > versions.yml
//     "${task.process}":
//         python: \$(python --version | sed 's/Python //g')
//     END_VERSIONS
//     """
// }

// process MERGE_FASTQ {
//     label 'process_medium'

//     input:
//         tuple val(id), val(files)

//     output:
//         path '*.fastq.gz' , emit: reads
//         path "versions.yml", emit: versions

//     when:
//         task.ext.when == null || task.ext.when  

//     script: 
//     """
//     if [[ ${file} == *.fastq.gz || ${file} == *.fq.gz ]]
//     then
//         cat ${reads} > ${id}.fastq.gz
//     else
        
//     fi

//     cat <<-END_VERSIONS > versions.yml
//     "${task.process}":
//         python: \$(python --version | sed 's/Python //g')
//     END_VERSIONS
//     """
// }

// def stage_files(List row) {

//     meta = row[0]
//     id = meta[0]
//     illumina = row[1]
//     nanopore = row[2]

//     if (illumina.size) {
//         if (illumina.size == 1) {
//             illumina1 = MERGE_FASTQ(id,illumina[0]).out.reads
//             illumina2 = null
//         } else if (illumina.size == 2) {
//             illumina1 = MERGE_FASTQ(id+"_R1",illumina[0]).out.reads
//             illumina2 = MERGE_FASTQ(id+"_R2",illumina[1]).out.reads
//         }
//     } else {
//         illumina1 = illumina2 = null
//     }

//     if (nanopore.size) {
//         nanopore = MERGE_FASTQ(id,row)
//     } else {
//         nanopore = null
//     }

//     array = [ id, [illumina1, illumina2], nanopore ]
//     return array
// }