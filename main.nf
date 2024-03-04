#!/usr/bin/env nextflow

 /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*\
|   basic-sequence-collector                                               |
|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
|   Github : https://github.com/provlab-bioinfo/basic-sequence-collector   |
 \*----------------------------------------------------------------------*/

nextflow.enable.dsl = 2
WorkflowMain.initialise(workflow, params, log)

include { VALIDATE_SHEET }              from './subworkflows/local/validate_sheet'
include { VALIDATE_FOLDER }             from './subworkflows/local/validate_folder'
include { PROCESS_SAMPLES }               from './subworkflows/local/process_samples'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions/main'

workflow {
    
    versions = Channel.empty()

    // SUBWORKFLOW: Read in folder and create the sample sheet
    if (params.folder) {
        VALIDATE_FOLDER(Channel.fromPath(params.folder))
        samplesheet = VALIDATE_FOLDER.out.samplesheet
        versions = versions.mix(VALIDATE_FOLDER.out.versions)
    } else {
        samplesheet = file(params.sheet)
    }

    samplesheet.view{ "VALIDATE_FOLDER | sheet: ${it}" };

    //SUBWORKFLOW: Read in samplesheet, validate, and stage input files
    VALIDATE_SHEET(samplesheet)
    versions = versions.mix(VALIDATE_SHEET.out.versions)

    VALIDATE_SHEET.out.sheet.view{ "VALIDATE_SHEET | sheet: ${it}" };

    // PROCESS_SAMPLES(VALIDATE_SHEET.out.reads)
    // versions = versions.mix(PROCESS_SAMPLES.out.versions)

    // SUBWORKFLOW: Get versioning
    CUSTOM_DUMPSOFTWAREVERSIONS (versions.unique().collectFile(name: 'collated_versions.yml'))

    //PROCESS_FILES.out.reads.view()

    emit:
        reads = VALIDATE_FOLDER.out.reads //VALIDATE_SHEET.out.reads
        versions
}