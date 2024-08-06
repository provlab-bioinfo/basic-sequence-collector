#!/usr/bin/env nextflow

 /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*\
|   basic-sequence-collector                                               |
|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
|   Github : https://github.com/provlab-bioinfo/basic-sequence-collector   |
 \*----------------------------------------------------------------------*/

nextflow.enable.dsl = 2
WorkflowMain.initialise(workflow, params, log)

include { SAVE_SHEET }               from './subworkflows/local/process_sheet'
include { PROCESS_SHEET }               from './subworkflows/local/process_sheet'
include { PROCESS_FOLDER }              from './subworkflows/local/process_folder'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './modules/nf-core/custom/dumpsoftwareversions/main'

workflow {
    
    versions = Channel.empty()

    input = toAbsPath(params.input)
    inputPath = new File(input);
    outdir = toAbsPath(params.outdir) + "/" + params.label
    prefix = params.prefix ? params.prefix + "_" : ""     
    suffix = params.suffix ? "_" + params.suffix : ""

    // SUBWORKFLOW: Read in folder and create the sample sheet
    if (inputPath.isDirectory()) {
        PROCESS_FOLDER(Channel.fromPath(input))
        samplesheet = PROCESS_FOLDER.out.samplesheet
        versions = versions.mix(PROCESS_FOLDER.out.versions)
        //samplesheet.view{ "PROCESS_FOLDER | sheet: ${it}" };
    } else if (inputPath.isFile()) {
        samplesheet = Channel.fromPath(input)
        //samplesheet.view{ "INPUT_SHEET | sheet: ${it}" };
    }

    //SUBWORKFLOW: Read in samplesheet, validate, and stage input files
    SAVE_SHEET(samplesheet)
    versions = versions.mix(SAVE_SHEET.out.versions)
    //SAVE_SHEET.out.samplesheet.view{ "SAVE_SHEET | sheet: ${it}" };

    println outdir

    PROCESS_SHEET(SAVE_SHEET.out.samplesheet, outdir, prefix, suffix)
    versions = versions.mix(PROCESS_SHEET.out.versions)

    //PROCESS_SHEET.out.samplesheet.view{ "PROCESS_SHEET | sheet: ${it}" };

    // SUBWORKFLOW: Get versioning
    CUSTOM_DUMPSOFTWAREVERSIONS (versions.unique().collectFile(name: 'collated_versions.yml'))

    PROCESS_SHEET.out.samplesheet.view{ "PROCESS_SHEET: ${it}"}

    emit:
        samplesheet = PROCESS_SHEET.out.samplesheet //PROCESS_SHEET.out.reads
        versions
}

def toAbsPath(String path) {  
    return path ? new File(path.toString()).getCanonicalPath() : path  
}