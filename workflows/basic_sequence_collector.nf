include { PROCESS_FOLDER }              from '../subworkflows/local/process_folder'
include { EXPORT_SHEET }                from '../subworkflows/local/sheet_io'
include { IMPORT_SHEET }                from '../subworkflows/local/sheet_io'
include { CONCAT_READS }                from '../subworkflows/local/handle_reads'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

workflow BASIC_SEQUENCE_COLLECTOR {
    
    //WorkflowMain.initialise(workflow, params, log)

    PROCESS_FOLDER(params.input)
    CONCAT_READS(PROCESS_FOLDER.out.reads)
    EXPORT_SHEET(CONCAT_READS.out.reads.toList())
    
    //IMPORT_SHEET(EXPORT_SHEET.out.samplesheet)

    versions = Channel.topic('versions').unique{ it.text }.collectFile(name: 'collated_versions.yml')
    CUSTOM_DUMPSOFTWAREVERSIONS (versions)
}