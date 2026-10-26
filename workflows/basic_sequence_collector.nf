


include { SAVE_SHEET }                  from '../subworkflows/local/process_sheet'
include { PROCESS_SHEET }               from '../subworkflows/local/process_sheet'
include { PROCESS_FOLDER }              from '../subworkflows/local/process_folder'
include { EXPORT_SHEET }                from '../subworkflows/local/sheet_io'
include { CONCAT_READS }                from '../subworkflows/local/sheet_io'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
//include { softwareVersionsToYAML } from 'plugin/nf-core-utils'

workflow BASIC_SEQUENCE_COLLECTOR {
    
    //WorkflowMain.initialise(workflow, params, log)
    input = new File(params.input.toString()).getCanonicalPath()
    //versions = Channel.empty() //Channel.of([ "Workflow", [ "Pipeline": workflow.manifest.version ] ])

    PROCESS_FOLDER(input)
    //versions = versions.mix(PROCESS_FOLDER.out.versions)
    
    CONCAT_READS(PROCESS_FOLDER.out.data)
    //versions = versions.mix(CONCAT_READS.out.versions) //TODO: figure out why it outputs versions with quotation marks
    
    EXPORT_SHEET(CONCAT_READS.out.data.toList())

    // SUBWORKFLOW: Get versioning
    CUSTOM_DUMPSOFTWAREVERSIONS (versions.unique().collectFile(name: 'collated_versions.yml'))

    // PROCESS_SHEET.out.samplesheet.view{ "PROCESS_SHEET: ${it}"}

    //emit:
        // samplesheet = PROCESS_SHEET.out.samplesheet //PROCESS_SHEET.out.reads
      // versions
}

def toAbsPath(String path) {  
    return path ? new File(path.toString()).getCanonicalPath() : path  
}
