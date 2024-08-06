# basic-sequence-collector
 [![Lifecycle: WIP](https://img.shields.io/badge/lifecycle-WIP-yellow.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental) [![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/provlab-bioinfo/basic-sequence-collector/issues) [![License: GPL3](https://img.shields.io/badge/license-GPL3-lightgrey.svg)](https://www.gnu.org/licenses/gpl-3.0.en.html) [![minimal Python version: 3.0](https://img.shields.io/badge/Python-3.10-6666ff.svg)](https://www.python.org/) [![Package Version = 0.0.1](https://img.shields.io/badge/Package%20version-0.0.1-orange.svg?style=flat-square)](https://github.com/provlab-bioinfo/basic-sequence-collector/blob/main/NEWS) [![Last-changedate](https://img.shields.io/badge/last%20change-2023--10--31-yellowgreen.svg)](https://github.com/provlab-bioinfo/basic-sequence-collector/blob/main/NEWS)

A collector for FASTQ files from Illumina (single- and paired-end short reads) or Nanopore (long read) NGS for downstream processing. Built upon previous work at [ProvLab](https://github.com/provlab-bioinfo/pathogenseq)<sup>[1](#references)</sup>.

## Table of Contents

- [Quick-Start Guide](#quick-start%guide)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Arguments](#arguments)
- [Input](#input)
- [Output](#output)
- [Pipeline Usage](#pipeline%usage)
- [References](#references)

## Quick-Start Guide

```bash
conda activate basic-sequence-collector
nextflow run pipelines/basic-sequence-collector \
  --folder </path/to/inputdir> | --samplesheet </path/to/samplesheet> \
  --outdir </path/to/output> \
  --label <>
```

## Dependencies

[Conda](https://conda.io/projects/conda/en/latest/user-guide/install/index.html) is required to build the [basic-sequence-collector](/environments/environment.yml) environment with the necessary workflow dependencies. To create the environment:
```
conda env create -f ./environments/environment.yml
```

## Arguments
**`--input`**: Either a folder containing FASTQ files, or a sample sheet specifying FASTQ files/directories corresponding to a sample. See [Input](#input).
<br>
**`--outdir`**: The output directory. See [Output](#output).
<br>
**`--label`**: The label to output directory. See [Output](#output). Default is 'raw'.
<br>
**`--prefix`**: A prefix to attach to the FASTQ file. Default is ''.
<br>
**`--suffix`**: A suffix to attach to the FASTQ file. Default is ''.
<br>

## Input:
Formats for **folders** and **sample sheets** in `--input` must be as follows:

<table border="0"><tr><td style="vertical-align:top"><b>Folder</b></td><td>

For a typical sequencing run, only the run folder needs to be specified as the FASTQ files will be searched for automatically. The file format must be as follows:
    
- Illumina: Paired reads are assumed and must use the default [Illumina nomenclature](https://support.illumina.com/help/BaseSpace_OLH_009008/Content/Source/Informatics/BS/NamingConvention_FASTQ-files-swBS.htm#) of `{SampleName}_S#_L001_R#_001.fastq.gz`. The script will search for `R1` and `R2`, and assign sample names as `SampleName_S1`.
- Nanopore: Accepts single or split FASTQ files, and must use the default Nanopore nomenclature of `{FlowCellID}_pass_barcode##_{random}[_#].fastq.gz`. Files containing the same barcode and terminated with `_#` will be automatically concatenated. Sample name will be assigned as `barcode##`.

</td></tr>
<tr><td style="vertical-align:top"><b>Sample&nbsp;sheet</b></td><td>

For more complicated runs, such as samples with both Illumina and Nanopore reads, a CSV file can specify an `ID` and list of `reads`. Each read must be in `.fastq` or `.fastq.gz` format, and paired reads are accepted for Illumina runs in `illumina1` and `illumina2`. Multiple files or directories can be specified in each field. If directories, the search criteria specified in `--folder` will be used.  These files will be concatenated and converted to `fastq.gz` if necessary. 

For example:

```
ID,         illumina1,                  illumina2,                  nanopore
SAMPLE-01   ,/path/to/SAMPLE-01.fq      ,                           ,
SAMPLE-02   ,/path/to/SAMPLE-02_R1.fq   ,/path/to/SAMPLE-02_R2.fq   , 
SAMPLE-03   ,                           ,                           ,/path/to/SAMPLE-03.fq/
```

</td></tr></table>


## Output

The output file structure is determined by the `outdir`:

```
<outdir>
   ├── pipeline_info
   │      ├── samplesheet.csv
   │      └── software_versions.yml
   └── <label>
          ├── samplesheet.csv
          └── fastq
                 └── [prefix_]<ID>[_suffix]_{R1|R2|ONT}.fastq[.gz]
```

## Pipeline Usage

To use this module in a Nextflow pipeline, copy  `\modules\local\basic-sequence-collector.nf` into the same directory of a Nextflow project. It can be called by:

```groovy
include { BASIC_SEQUENCE_COLLECTOR as COLLECT } from './modules/local/basic-sequence-collector.nf'

COLLECT(params.input, params.outdir, "raw")

samplesheet = COLLECT.out.samplesheet // a path() channel
```

## References
1. Provlab-Bioinfo/pathogenseq: Pathogen whole genome sequence (WGS) data analysis pipeline. https://github.com/provlab-bioinfo/pathogenseq 



