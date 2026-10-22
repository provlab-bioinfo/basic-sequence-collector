#!/usr/bin/env nextflow

 /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*\
|   basic-sequence-collector                                               |
|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
|   Github : https://github.com/provlab-bioinfo/basic-sequence-collector   |
 \*----------------------------------------------------------------------*/

nextflow.enable.dsl = 2

include { BASIC_SEQUENCE_COLLECTOR }                  from './workflows/basic_sequence_collector.nf'

workflow {
    
    versions = Channel.empty()

    BASIC_SEQUENCE_COLLECTOR()

    

    //emit:
        // samplesheet = PROCESS_SHEET.out.samplesheet //PROCESS_SHEET.out.reads
        // versions
}
