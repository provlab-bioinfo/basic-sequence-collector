include { PROCESS_FOLDER }              from '../subworkflows/local/process_folder'
include { EXPORT_SHEET }                from '../subworkflows/local/sheet_io'
include { CONCAT_READS }                from '../subworkflows/local/sheet_io'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

workflow BASIC_SEQUENCE_COLLECTOR {
    
    //WorkflowMain.initialise(workflow, params, log)
    input = new File(params.input.toString()).getCanonicalPath()

    PROCESS_FOLDER(input)    
    CONCAT_READS(PROCESS_FOLDER.out.data)
    EXPORT_SHEET(CONCAT_READS.out.data.toList())

    versions = Channel.topic('versions').unique{ it.text }.collectFile(name: 'collated_versions.yml')
    CUSTOM_DUMPSOFTWAREVERSIONS (versions)
    
    // emit:
    //     samplesheet = EXPORT_SHEET.out.samplesheet //PROCESS_SHEET.out.reads
}
