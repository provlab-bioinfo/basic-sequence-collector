#!/usr/bin/env nextflow

 /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*\
|   basic-sequence-collector                                               |
|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
|   Github : https://github.com/provlab-bioinfo/basic-sequence-collector   |
 \*----------------------------------------------------------------------*/

nextflow.enable.dsl = 2
WorkflowMain.initialise(workflow, params, log)

include { SHEET_CHECK } from                 './subworkflows/local/input_check'
include { FOLDER_CHECK } from                './subworkflows/local/input_check'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions/main'

workflow {
    
    ch_versions = Channel.empty()

    // SUBWORKFLOW: Read in folder and create the sample sheet
    if (params.folder) {
        FOLDER_CHECK(Channel.fromPath(params.folder))
        sheet = FOLDER_CHECK.out.sheet
        ch_versions = ch_versions.mix(FOLDER_CHECK.out.versions)
    } else {
        sheet = file(params.sheet)
    }

    //SUBWORKFLOW: Read in samplesheet, validate, and stage input files
    SHEET_CHECK(sheet)
    reads = SHEET_CHECK.out.reads
    ch_versions = ch_versions.mix(SHEET_CHECK.out.versions)

    // SUBWORKFLOW: Get versioning
    CUSTOM_DUMPSOFTWAREVERSIONS (ch_versions.unique().collectFile(name: 'collated_versions.yml'))

    emit:
        reads
        versions = ch_versions
}