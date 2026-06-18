# nf-core/bacmodel: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/bacmodel/usage](https://nf-co.re/bacmodel/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

nf-core/bacmodel is a bioinformatics pipeline for functional annotation and metabolic modeling of bacterial genomes. The pipeline takes genome assemblies (FASTA files) as input and performs:

- Genome annotation (Prokka or Bakta)
- Macromolecular system detection (MacSyFinder)
- Phenotype prediction (TRAITAR)
- Metabolic model reconstruction (CarveMe and/or Gapseq)

## Samplesheet input

You will need to create a samplesheet with information about the genome assemblies you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 2 columns, and a header row as shown in the example below.

```bash
--input '[path to samplesheet file]'
```

### Samplesheet format

The samplesheet should contain at minimum two required columns: `sample` and `fasta`. Two optional columns `medium_gapseq` and `medium_carveme` can be added to specify growth media for metabolic modeling. An example is shown below:

```csv title="samplesheet.csv"
sample,fasta,medium_gapseq,medium_carveme
SAMPLE1,/path/to/sample1_assembly.fasta,,complete
SAMPLE2,/path/to/sample2_assembly.fasta,LB,LB
SAMPLE3,/path/to/sample3_assembly.fasta,M9,M9
```

| Column           | Description                                                                                                                                                                                                                                           |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`         | **Required.** Custom sample name. Spaces in sample names are automatically converted to underscores (`_`).                                                                                                                                            |
| `fasta`          | **Required.** Full path to genome assembly file in FASTA format. File can be gzipped (`.fasta.gz`, `.fa.gz`, `.fna.gz`) or uncompressed (`.fasta`, `.fa`, `.fna`).                                                                                    |
| `medium_gapseq`  | **Optional.** Growth medium for gapseq metabolic modeling. Can be a medium name (e.g., `LB`, `M9`) or path to custom CSV file. If empty, gapseq auto-predicts the medium. See [Metabolic modeling media](#metabolic-modeling-media) for details.      |
| `medium_carveme` | **Optional.** Growth medium name for CarveMe gap-filling (e.g., `LB`, `M9`). Must correspond to a medium in the CarveMe media database. If empty, no gap-filling is performed. See [Metabolic modeling media](#metabolic-modeling-media) for details. |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

### Metabolic modeling media

The optional `medium_gapseq` and `medium_carveme` columns allow you to specify growth media for metabolic model reconstruction on a per-sample basis. This is useful when:

- You have experimental growth data for specific media
- You want to ensure models can simulate growth under specific conditions
- Different bacterial species in your dataset require different growth conditions

#### Gapseq media (`medium_gapseq`)

> **Note:** Gapseq automatically downloads reference sequence databases on first use. The pipeline uses container options to ensure each process has a writable directory for database initialization.

**Default behavior (empty column):** Gapseq uses its built-in **anaerobic complete medium** for gap-filling, which is a permissive rich medium allowing comprehensive metabolic reconstruction.

**Built-in media names:** You can specify predefined media names that gapseq recognizes: `LB` (Luria-Bertani rich medium) or `M9` (M9 minimal medium). See the [gapseq medium documentation](https://gapseq.readthedocs.io/en/latest/usage/medium.html) for available options.

**Custom media files:** Provide a path to a CSV file with three columns:

- `compounds`: Metabolite IDs (e.g., `cpd00027` for D-Glucose)
- `name`: Metabolite names
- `maxFlux`: Maximum uptake rate in mmol/gDW/h

The `maxFlux` parameter defines the maximum inflow flux for each compound. Use lower values (5-10) for carbon sources, medium values (10-20) for O2/CO2, and high values (100) for abundant nutrients like water, ions, and cofactors. For detailed information, see the [gapseq medium documentation](https://gapseq.readthedocs.io/en/latest/usage/medium.html).

Example custom medium CSV:

```csv
compounds,name,maxFlux
cpd00027,D-Glucose,5
cpd00007,O2,10
cpd00009,Phosphate,100
cpd00013,NH3,100
```

**Advanced customization:** The pipeline uses `gapseq doall` for streamlined workflow execution. For advanced users who need full control over individual gapseq subworkflows (`find`, `find-transport`, `draft`, `medium`, and `fill`), additional parameters can be passed via a custom configuration file:

```nextflow
process {
    withName: 'GAPSEQ_DOALL' {
        ext.args = '-b 200 -p nuc -c 0.5'  // Example: custom blast threshold, pathway completion threshold
    }
}
```

Refer to the [gapseq documentation](https://gapseq.readthedocs.io/) for available parameters. Note that full subworkflow customization may require creating a custom workflow outside of the `doall` command.

#### CarveMe media (`medium_carveme`)

**Default behavior (empty column):** CarveMe uses **complete rich medium** for gap-filling by default, ensuring the model can simulate growth and shows comprehensive metabolic capabilities. This matches gapseq's permissive default behavior.

**Media names:** Specify media names from the CarveMe media database (e.g., `LB`, `M9`, `complete`, `TSB`) to override the default and gap-fill for a specific growth medium.

**Custom media database:** To use a custom CarveMe media database, provide the `--carveme_mediadb` parameter pointing to a TSV file containing multiple media definitions.

Example usage:

```bash
nextflow run nf-core/bacmodel \
  --input samplesheet.csv \
  --outdir results \
  --carveme_mediadb /path/to/custom_media_db.tsv \
  -profile docker
```

> [!NOTE]
> The `medium_carveme` column should contain media **names** that exist in the media database, not file paths.

> [!TIP]
> For most applications, leaving both media columns empty uses sensible defaults: both tools use rich complete media for gap-filling, ensuring comparable and comprehensive metabolic models. Specify media explicitly when you need to constrain models to experimentally validated growth conditions (e.g., use `M9` for both tools for minimal medium experiments, or `LB` for rich medium cultures).

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/bacmodel --input ./samplesheet.csv --outdir ./results -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

### Analysis options

The pipeline provides several options to customize the analysis:

#### Annotation tool

Choose between Prokka (default) and Bakta for genome annotation:

```bash
--annotation_tool prokka  # Default
--annotation_tool bakta   # Requires --baktadb or --baktadb_download
```

#### Enable/disable analysis tools

Control which functional analysis tools to run:

```bash
--run_macsyfinder true  # Default: true
--run_traitar true      # Default: true
--run_carveme true      # Default: true
--run_gapseq true       # Default: false
--run_memote true       # Default: false - Evaluate metabolic model quality
```

**Note:** MEMOTE requires at least one metabolic modeling tool (`run_carveme` or `run_gapseq`) to be enabled. MEMOTE will evaluate the quality of all generated metabolic models (SBML XML format) and produce HTML reports with comprehensive quality metrics.

#### Database options

Specify or download required databases:

```bash
--pfamdb /path/to/pfam      # Required if run_traitar=true
--pfamdb_download true      # Download Pfam database automatically

--baktadb /path/to/bakta    # Required if annotation_tool=bakta
--baktadb_download true     # Download Bakta database automatically
```

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/bacmodel -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/bacmodel
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/bacmodel releases page](https://github.com/nf-core/bacmodel/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow ` 24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
