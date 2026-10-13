/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_bacmodel_pipeline'
include { ANNOTATION             } from '../subworkflows/local/annotation/main'
include { MACSYFINDER            } from '../subworkflows/local/macsyfinder/main'
include { TRAITAR_WORKFLOW       } from '../subworkflows/local/traitar_workflow/main'
include { GAPSEQ                 } from '../subworkflows/local/gapseq_workflow/main'
include { CARVEME_CARVE          } from '../modules/nf-core/carveme/carve/main'
include { MEMOTE_RUN             } from '../modules/nf-core/memote/run/main'
include { MEMOTE_REPORT          } from '../modules/nf-core/memote/report/main'
include { BACMODEL_SUMMARY       } from '../modules/local/bacmodel_summary/main'

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

    // DB cache dirs default under this run's outdir (not the pipeline's own assets/
    // dir) when the user hasn't pointed at a pre-downloaded copy - see conf/modules.config,
    // which mirrors this same fallback for where each download gets published.
    def bakta_db = params.bakta_db ?: "${outdir}/databases/bakta"
    def macsyfinder_db = params.macsyfinder_db ?: "${outdir}/databases/macsyfinder"
    def pfam_db = params.pfam_db ?: "${outdir}/databases/pfam"
    def gapseq_db = params.gapseq_db ?: "${outdir}/databases/gapseq"

    //
    // Genome annotation - Prokka (default) or Bakta
    //
    ANNOTATION(ch_genomes, params.annotation_tool, bakta_db)
    ch_proteins = ANNOTATION.out.proteins
    ch_gff = ANNOTATION.out.gff

    //
    // Macromolecular Systems - optional
    //
    if (!params.skip_macsyfinder) {
        // macsyfinder_models being non-empty when skip_macsyfinder=false is enforced
        // by nextflow_schema.json's conditional validation, not re-checked here.
        MACSYFINDER(ch_proteins, params.macsyfinder_models, macsyfinder_db)
        ch_macsyfinder_results = MACSYFINDER.out.results
    } else {
        ch_macsyfinder_results = Channel.empty()
    }

    //
    // Phenotype Prediction - optional
    //
    if (!params.skip_traitar) {
        TRAITAR_WORKFLOW(ch_proteins, pfam_db)
        ch_traitar_results = TRAITAR_WORKFLOW.out.results
        ch_traitar_single_votes = TRAITAR_WORKFLOW.out.single_votes
    } else {
        ch_traitar_results = Channel.empty()
        ch_traitar_single_votes = Channel.empty()
    }

    //
    // Metabolic Modeling - CarveMe (protein-based) - optional
    //
    if (!params.skip_carveme) {
        ch_carveme_input = ch_proteins.map { meta, faa ->
            // Keep medium_carveme in meta for ext.args configuration (selects which
            // medium, by name, to gap-fill with - from whichever mediadb applies below).
            // A per-sample medium_carveme_tsv overrides the global --carveme_mediadb
            // for that sample only; otherwise fall back to --carveme_mediadb, or
            // CarveMe's own bundled default database if neither is set.
            def mediadb = meta.medium_carveme_tsv ? file(meta.medium_carveme_tsv) :
                (params.carveme_mediadb ? file(params.carveme_mediadb) : [])
            [ meta, faa, [], mediadb, [], [], [] ]
        }
        CARVEME_CARVE(ch_carveme_input)
        ch_carveme_model = CARVEME_CARVE.out.model
    } else {
        ch_carveme_model = Channel.empty()
    }

    //
    // Metabolic Modeling - Gapseq (genome-based) - optional
    //
    if (!params.skip_gapseq) {
        // Workflow automatically uses custom mode if any gapseq_*_args are provided
        // Otherwise uses streamlined 'doall' mode (recommended for most users)
        GAPSEQ(
            ch_genomes,
            gapseq_db,
            params.gapseq_find_args,
            params.gapseq_findtransport_args,
            params.gapseq_draft_args,
            params.gapseq_medium_args,
            params.gapseq_fill_args
        )

        ch_gapseq_model = GAPSEQ.out.model
        ch_gapseq_xml = GAPSEQ.out.xml
        ch_gapseq_pathways = GAPSEQ.out.pathways
        ch_gapseq_transporters = GAPSEQ.out.transporters

        // Combine pathways and transporters into single tbl channel for compatibility
        ch_gapseq_tbl = ch_gapseq_pathways
            .join(ch_gapseq_transporters, by: 0)
            .map { meta, pathways, transporters ->
                [ meta, [ pathways, transporters ] ]
            }
    } else {
        ch_gapseq_model = Channel.empty()
        ch_gapseq_xml = Channel.empty()
        ch_gapseq_tbl = Channel.empty()
    }

    //
    // MODULE: Memote - Evaluate model quality - optional
    //
    ch_memote_report = Channel.empty()
    ch_memote_json = Channel.empty()
    if (!params.skip_memote) {
        // Filter gapseq models to only use final model (not draft) and add tool tag
        ch_gapseq_final = ch_gapseq_xml
            .map { meta, xml ->
                // If xml is a list, filter out draft models
                def final_xml = xml instanceof List ? xml.findAll { !it.name.contains('-draft') } : xml
                def new_meta = meta + [tool: 'gapseq']
                [new_meta, final_xml]
            }
            .filter { meta, xml ->
                // Keep only if there's at least one final model
                xml instanceof List ? !xml.isEmpty() : xml != null
            }

        // Add tool tag to carveme models
        ch_carveme_tagged = ch_carveme_model.map { meta, xml ->
            def new_meta = meta + [tool: 'carveme']
            [new_meta, xml]
        }

        // Combine gapseq and carveme models for memote evaluation
        ch_models_for_memote = ch_gapseq_final.mix(ch_carveme_tagged)

        // Run memote for JSON output (for summary table)
        MEMOTE_RUN(ch_models_for_memote)
        ch_memote_json = MEMOTE_RUN.out.json

        // Generate HTML report for visualization
        MEMOTE_REPORT(ch_models_for_memote)
        ch_memote_report = MEMOTE_REPORT.out.report
    }

    //
    // Generate summary table combining all results
    //
    // Collect sample IDs and write to file
    ch_sample_ids = ch_genomes.map { meta, fasta -> meta.id }.collectFile(name: 'sample_ids.txt', newLine: true)

    // Collect all results for summary (handling empty channels). macsyfinder/carveme/gapseq
    // results are paired with their sample id here (rather than letting BACMODEL_SUMMARY
    // recover it later by parsing the published filename/directory) so the summary script
    // doesn't need to guess at a naming convention - file list and id list are derived from
    // the same tuple channel, so they stay index-aligned once both are collected.
    ch_macsyfinder_for_summary = ch_macsyfinder_results.map { meta, file -> file }.collect().ifEmpty([])
    ch_macsyfinder_ids_for_summary = ch_macsyfinder_results.map { meta, file -> meta.id }.collect().ifEmpty([])
    ch_traitar_majority_for_summary = ch_traitar_results.map { meta, file -> file }.collect().ifEmpty([])
    ch_traitar_single_for_summary = ch_traitar_single_votes.map { meta, file -> file }.collect().ifEmpty([])
    ch_carveme_for_summary = ch_carveme_model.map { meta, file -> file }.collect().ifEmpty([])
    ch_carveme_ids_for_summary = ch_carveme_model.map { meta, file -> meta.id }.collect().ifEmpty([])

    if (!params.skip_gapseq) {
        // Filter out draft models (xml may be a single path or a list) and pair the
        // one surviving non-draft model with its sample id - errors out if gapseq
        // ever produces anything other than exactly one final model per sample.
        ch_gapseq_pairs = ch_gapseq_xml.map { meta, xml ->
            def files = xml instanceof List ? xml : [xml]
            def final_files = files.findAll { !it.name.contains('-draft') }
            if (final_files.size() != 1) {
                error("Expected exactly one non-draft gapseq model for ${meta.id}, got ${final_files.size()}: ${final_files.collect { f -> f.name }}")
            }
            [ meta.id, final_files[0] ]
        }
        ch_gapseq_for_summary = ch_gapseq_pairs.map { id, file -> file }.collect().ifEmpty([])
        ch_gapseq_ids_for_summary = ch_gapseq_pairs.map { id, file -> id }.collect().ifEmpty([])
    } else {
        ch_gapseq_for_summary = Channel.empty().collect().ifEmpty([])
        ch_gapseq_ids_for_summary = Channel.empty().collect().ifEmpty([])
    }

    ch_gapseq_tbl_for_summary = ch_gapseq_tbl.map { meta, files -> files }.flatten().collect().ifEmpty([])
    ch_memote_for_summary = ch_memote_json.map { meta, json -> json }.collect().ifEmpty([])

    BACMODEL_SUMMARY(
        ch_sample_ids,
        ch_macsyfinder_for_summary,
        ch_macsyfinder_ids_for_summary,
        ch_traitar_majority_for_summary,
        ch_traitar_single_for_summary,
        ch_carveme_for_summary,
        ch_carveme_ids_for_summary,
        ch_gapseq_for_summary,
        ch_gapseq_ids_for_summary,
        ch_gapseq_tbl_for_summary,
        ch_memote_for_summary,
        !params.skip_macsyfinder,
        !params.skip_traitar,
        !params.skip_carveme,
        !params.skip_gapseq,
        !params.skip_memote
    )

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
