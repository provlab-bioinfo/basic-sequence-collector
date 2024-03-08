#!/usr/bin/env nextflow

 /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*\
|   basic-sequence-collector                                               |
|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
|   Github : https://github.com/provlab-bioinfo/basic-sequence-collector   |
 \*----------------------------------------------------------------------*/

nextflow.enable.dsl = 2
WorkflowMain.initialise(workflow, params, log)

include { PROCESS_SHEET }              from './subworkflows/local/process_sheet'
include { PROCESS_FOLDER }             from './subworkflows/local/process_folder'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions/main'

workflow {
    
    versions = Channel.empty()

    folder = toAbsPath(params.folder)
    sheet = toAbsPath(params.sheet)
    output = toAbsPath(params.output)

    // SUBWORKFLOW: Read in folder and create the sample sheet
    if (folder) {
        PROCESS_FOLDER(Channel.fromPath(folder))
        samplesheet = PROCESS_FOLDER.out.samplesheet
        versions = versions.mix(PROCESS_FOLDER.out.versions)
        samplesheet.view{ "PROCESS_FOLDER | sheet: ${it}" };
    } else {
        samplesheet = Channel.fromPath(sheet)
        samplesheet.view{ "INPUT_SHEET | sheet: ${it}" };
    }

    //SUBWORKFLOW: Read in samplesheet, validate, and stage input files
    PROCESS_SHEET(samplesheet, output)
    versions = versions.mix(PROCESS_SHEET.out.versions)
    PROCESS_SHEET.out.samplesheet.view{ "PROCESS_SHEET | sheet: ${it}" };

    // SUBWORKFLOW: Get versioning
    CUSTOM_DUMPSOFTWAREVERSIONS (versions.unique().collectFile(name: 'collated_versions.yml'))

    //PROCESS_FILES.out.reads.view()

    emit:
        samplesheet = PROCESS_SHEET.out.samplesheet //PROCESS_SHEET.out.reads
        versions
}

def toAbsPath(String path) {  
    return path ? new File(path.toString()).getCanonicalPath() : path  
}