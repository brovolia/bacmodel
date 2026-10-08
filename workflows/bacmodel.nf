/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_bacmodel_pipeline'
include { BACMODEL_ANALYSIS      } from '../subworkflows/local/bacmodel_analysis'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow BACMODEL {

    take:
    ch_genomes // channel: [ val(meta), path(fasta) ] - samplesheet read in from --input, already formatted by PIPELINE_INITIALISATION
    outdir     // string: output directory
    main:

    def ch_versions = channel.empty()

    //
    // Snapshot the params BACMODEL_ANALYSIS and its subworkflows need, so
    // params.* access stays confined to this top-level workflow file instead
    // of being read again in every subworkflow down the call chain.
    //
    def annotation_options = [
        annotation_tool           : params.annotation_tool,
        // DB cache dirs default under this run's outdir (not the pipeline's own assets/
        // dir) when the user hasn't pointed at a pre-downloaded copy - see conf/modules.config,
        // which mirrors this same fallback for where the download gets published.
        bakta_db                  : params.bakta_db ?: "${params.outdir}/databases/bakta",
        skip_macsyfinder          : params.skip_macsyfinder,
        macsyfinder_models        : params.macsyfinder_models,
        macsyfinder_db            : params.macsyfinder_db ?: "${params.outdir}/databases/macsyfinder",
        skip_traitar              : params.skip_traitar,
        pfamdb                    : params.pfamdb ?: "${params.outdir}/databases/pfam",
        skip_carveme              : params.skip_carveme,
        carveme_mediadb           : params.carveme_mediadb,
        skip_gapseq               : params.skip_gapseq,
        gapseq_db                 : params.gapseq_db ?: "${params.outdir}/databases/gapseq",
        skip_memote               : params.skip_memote,
        gapseq_find_args          : params.gapseq_find_args,
        gapseq_findtransport_args : params.gapseq_findtransport_args,
        gapseq_draft_args         : params.gapseq_draft_args,
        gapseq_medium_args        : params.gapseq_medium_args,
        gapseq_fill_args          : params.gapseq_fill_args,
    ]

    //
    // Run functional annotation and analysis
    //
    BACMODEL_ANALYSIS(ch_genomes, annotation_options)

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: !(entry instanceof Path)
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { entry ->
            def process = entry[0]
            def tool = entry[1]
            def version = entry[2]
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'bacmodel_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )
    emit:
    versions       = ch_collated_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
