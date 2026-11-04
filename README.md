# basic-sequence-collector

 [![Lifecycle:Stable](https://img.shields.io/badge/Lifecycle-Stable-97ca00)](https://lifecycle.r-lib.org/articles/stages.html#stable) [![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/provlab-bioinfo/basic-sequence-collector/issues) [![License: GPL3](https://img.shields.io/badge/license-GPL3-lightgrey.svg)](https://www.gnu.org/licenses/gpl-3.0.en.html) [![minimal Python version: 3.11](https://img.shields.io/badge/Python-3.11-6666ff.svg)](https://www.python.org/) [![Package Version = 1.0.0](<https://img.shields.io/badge/Package%20version-1.0.0-orange.svg?style=flat-square>)](https://github.com/provlab-bioinfo/basic-sequence-collector/blob/main/NEWS) [![Last-changedate](<https://img.shields.io/badge/last%20change-2026--11--03-yellowgreen.svg>)](https://github.com/provlab-bioinfo/basic-sequence-collector/blob/main/NEWS)

A collector for FASTQ files from Illumina (single- and paired-end short reads) or Nanopore (long read) NGS for downstream processing.

## Table of Contents

- [Quick-Start Guide](#quick-start%guide)
- [Dependencies](#dependencies)
- [Arguments](#arguments)
- [Input](#input)
- [Output](#output)
- [References](#references)

<!-- 
- [Installation](#installation)
- [Pipeline Usage](#pipeline%usage) 
-->

## Quick-Start Guide

```bash
conda activate basic-sequence-collector
nextflow run provlab-bioinfo/basic-sequence-collector \
  --input </path/to/inputdir> \
  --outdir </path/to/output> \
```

## Dependencies

[Conda](https://conda.io/projects/conda/en/latest/user-guide/install/index.html) is required to build the [basic-sequence-collector](/environments/environment.yml) environment with the necessary workflow dependencies. To create the environment:

```
conda env create -f ./environments/environment.yml
```

## Arguments

**`--input`**: A folder containing FASTQ files. Must follow the naming scheme for Illumina and Nanopore sequencer output. See [Input](#input) for requirements.

**`--outdir`**: The output directory. See [Output](#output) for structure.

**`--outcols`**: The output columns, comma-delimited. Must contain 3 unique column names for paired Illumina reads and Naopore reads. Default is `short1,short2,long`.

**`--label`**: The name for the output subdirectory containing the reads. Default is `fastq`.

**`--prefix`**: A prefix to attach to the FASTQ file. Default is `null`.

**`--suffix`**: A suffix to attach to the FASTQ file. Default is `null`.

## Input:

##### FASTQ:

Formats for FASTQ files in the `--input` directory must be as follows:

- Illumina: Paired reads are assumed and must use the default [Illumina nomenclature](https://help.basespace.illumina.com/files-used-by-basespace/fastq-files) of `{Sample_ID}_S#_L001_R#_001.fastq.gz`. `{Sample_ID}` must be a number representing the barcode of the sample.
- Nanopore: Accepts single or split FASTQ files, and must use the default [Nanopore nomenclature](https://software-docs.nanoporetech.com/output-specifications/26.01/minknow/output_structure/) of `{FlowCellID}_pass_barcode##_{random}[_#].fastq.gz`. Files containing the same barcode and terminated with `_#` will be automatically concatenated.

##### Metadata:

Metadata can be derived from pipeline launcher worksheets used as input for the [ngs-pipeline-launcher](https://github.com/provlab-bioinfo/ngs-pipeline-launcher). Any columns present in the `[Samples]` section, except for `Plate_pos` and `Sample_group`, will be extracted and added to the metamap for each sample.

## Output

##### Files:

From each file, a `barcode` will be parsed to use as an identifier. For Illumina, this is the `{Sample_ID}`, and for Nanopore, this derived from `barcode##`. This will be used to track Illumina paired reads and concatenate split Nanopore files. The additional data added by the sequencer will be stripped, and along with `prefix`, an `ID` is generated: `[prefix_]idx<barcode>`.

Outputted FASTQ files will use this `ID`, along with `suffix` and the type of read to generate a file name: `<ID>_{R1|R2|ONT}[.suffix].fastq.gz`.

The output samplesheet will contain columns for each file and metadata value. If no pipeline worksheet is present, the output will be:

```metadata.csv
id,   short1,            short2,            long
idx1, idx_1_R1.fastq.gz, idx_1_R2.fastq.gz,
idx2, idx_2_R1.fastq.gz, idx_2_R2.fastq.gz,
idx3, idx_3_R1.fastq.gz, idx_3_R2.fastq.gz,
```

If a pipeline worksheet is present, and has metadata columns for `accession` and `organism`, the output will be:

```metadata.csv
id,   accession,    organism, short1,            short2,            long
idx1, 11-111-11111, ecoli,    idx_1_R1.fastq.gz, idx_1_R2.fastq.gz,
idx2, 22-222-22222, shigella, idx_2_R1.fastq.gz, idx_2_R2.fastq.gz,
idx3, 33-333-33333, plague,   idx_3_R1.fastq.gz, idx_3_R2.fastq.gz,
```

##### Folders:

The output folder structure is determined by the `outdir` and `label`:

```bash
$ nextflow run provlab-bioinfo/basic-sequence-collector --input </path/to/dir> \
--outdir <OUTDIR> --label <LABEL> --prefix [PREFIX] --suffix [SUFFIX]

<OUTDIR>
   ├── pipeline_info
   │      ├── metadata.csv (if present)
   │      └── software_versions.yml
   └── <LABEL>
          ├── samplesheet.<LABEL>.csv
          └── fastq
                 └── [PREFIX_]idx<barcode>_{R1|R2|ONT}[.SUFFIX].fastq.gz
```

For example, with Illumina sequencing run, the output structure would be as follows:

```bash
$ ls /nfs/seq/run
1_S1_L001_R1_001.fastq.gz 
1_S1_L001_R2_001.fastq.gz 
2_S2_L001_R1_001.fastq.gz
2_S2_L001_R2_001.fastq.gz
3_S3_L001_R1_001.fastq.gz
3_S3_L001_R2_001.fastq.gz
run_PipelineWorksheet.xlsx

$ nextflow run provlab-bioinfo/basic-sequence-collector --input /nfs/seq/run \
--outdir /nfs/data/run --label fastq --prefix 261103

/nfs/data/run
   ├── pipeline_info
   │      ├── metadata.csv
   │      └── software_versions.yml
   └── fastq
          ├── samplesheet.fastq.csv
          └── fastq
                 ├── 261103_idx1_R1.fastq.gz
                 ├── 261103_idx1_R2.fastq.gz
                 ├── 261103_idx2_R1.fastq.gz
                 ├── 261103_idx2_R2.fastq.gz
                 ├── 261103_idx3_R1.fastq.gz
                 └── 261103_idx3_R2.fastq.gz
```

<!--
## Pipeline Usage

To use this module in a Nextflow pipeline, copy  `\modules\local\basic-sequence-collector.nf` into the same directory of a Nextflow project. It can be called by:

```groovy
include { BASIC_SEQUENCE_COLLECTOR as COLLECT } from './modules/local/basic-sequence-collector.nf'

COLLECT(params.input, params.outdir, "raw"[, prefix, suffix])

samplesheet = COLLECT.out.samplesheet // a path() channel
```
-->

## References

1. **Provlab-Bioinfo/ngs-pipeline-launcher:** A launcher tool for sorting sequencing runs and automatic initialization of their downstream pipelines. [https://github.com/provlab-bioinfo/ngs-pipeline-launcher](https://github.com/provlab-bioinfo/ngs-pipeline-launcher)
2. **Illumina/FastQ Files:** Description of Illumina FASTQ naming conventions. [https://help.basespace.illumina.com/files-used-by-basespace/fastq-files](https://help.basespace.illumina.com/files-used-by-basespace/fastq-files)
3. **Nanopore/Output Structure:** Description of ONT FASTQ naming conventions. [https://software-docs.nanoporetech.com/output-specifications/26.01/minknow/output_structure/](https://software-docs.nanoporetech.com/output-specifications/26.01/minknow/output_structure/)
