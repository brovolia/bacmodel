/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    BACMODEL SUBWORKFLOW - Using nf-core modules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Orchestrates functional annotation and modeling of bacterial genomes
    using nf-core modules and custom local modules for specialized tools
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PROKKA                  } from '../../../modules/nf-core/prokka/main'
include { BAKTA_BAKTA             } from '../../../modules/nf-core/bakta/bakta/main'
include { BAKTA_BAKTADBDOWNLOAD   } from '../../../modules/nf-core/bakta/baktadbdownload/main'
include { MACSYFINDER_SEARCH      } from '../../../modules/nf-core/macsyfinder/search/main'
include { MACSYFINDER_DOWNLOAD    } from '../../../modules/nf-core/macsyfinder/download/main'
include { TRAITAR                 } from '../../../modules/nf-core/traitar/run/main'
include { TRAITAR_PFAMGET         } from '../../../modules/nf-core/traitar/pfamget/main'
include { CARVEME_CARVE           } from '../../../modules/nf-core/carveme/carve/main'
include { GAPSEQ_WORKFLOW         } from '../gapseq_workflow/main'
include { MEMOTE_RUN              } from '../../../modules/nf-core/memote/run/main'
include { MEMOTE_REPORT           } from '../../../modules/nf-core/memote/report/main'
include { BACMODEL_SUMMARY        } from '../../../modules/local/bacmodel_summary/main'
include { RENAME_GAPSEQ_XML       } from '../../../modules/local/rename_gapseq_xml/main'

workflow BACMODEL_FUNCTIONAL_ANNOTATION {

    take:
    ch_genomes  // channel: [ val(meta), path(fasta) ]
    options     // map: annotation/analysis tool options, see workflows/bacmodel.nf

    main:

    ch_annotated_proteins = Channel.empty()
    ch_annotated_gff = Channel.empty()
    ch_macsyfinder_results = Channel.empty()
    ch_traitar_results = Channel.empty()
    ch_traitar_single_votes = Channel.empty()
    ch_carveme_model = Channel.empty()
    ch_gapseq_model = Channel.empty()
    ch_gapseq_tbl = Channel.empty()

    // Option 1: Prokka for annotation (preferred for speed)
    if (options.annotation_tool == 'prokka' || !options.annotation_tool) {
        PROKKA(ch_genomes, [], [])
        ch_annotated_proteins = PROKKA.out.faa
        ch_annotated_gff = PROKKA.out.gff
        // versions emitted via topic system
    }

    // Option 2: Bakta for annotation (alternative)
    if (options.annotation_tool == 'bakta') {
        // Skip the download if the DB is already cached at options.baktadb (published
        // there by a previous run - see conf/modules.config). Can't use storeDir here:
        // BAKTA_BAKTADBDOWNLOAD also emits a tuple for versions-topic reporting, and
        // storeDir only supports processes whose outputs are all `val`/`path`.
        def baktadb_cached = file("${options.baktadb}/db")
        if (baktadb_cached.exists()) {
            ch_baktadb = Channel.fromPath(baktadb_cached, checkIfExists: true)
        } else {
            BAKTA_BAKTADBDOWNLOAD()
            ch_baktadb = BAKTA_BAKTADBDOWNLOAD.out.db
        }

        BAKTA_BAKTA(ch_genomes, ch_baktadb, [], [], [], [])
        ch_annotated_proteins = BAKTA_BAKTA.out.faa
        ch_annotated_gff = BAKTA_BAKTA.out.gff
    }

    // Macromolecular Systems - run on all
    if (!options.skip_macsyfinder) {
        if (!options.macsyfinder_models) {
            error "MacSyFinder requires model names. Please provide --macsyfinder_models (e.g., 'TXSS')"
        }

        // Skip the download if these models are already cached at
        // options.macsyfinder_db/<model_name> (published there by a previous run -
        // see conf/modules.config). Can't use storeDir here: MACSYFINDER_DOWNLOAD also
        // emits tuples for versions-topic reporting, and storeDir only supports
        // processes whose outputs are all `val`/`path`.
        def macsyfinder_models_cached = file("${options.macsyfinder_db}/${options.macsyfinder_models}/models")
        if (macsyfinder_models_cached.exists()) {
            ch_macsyfinder_models = Channel.fromPath(macsyfinder_models_cached, checkIfExists: true)
        } else {
            MACSYFINDER_DOWNLOAD(options.macsyfinder_models)
            ch_macsyfinder_models = MACSYFINDER_DOWNLOAD.out.models
        }

        MACSYFINDER_SEARCH(
            ch_annotated_proteins,
            ch_macsyfinder_models,
            options.macsyfinder_models
        )
        ch_macsyfinder_results = MACSYFINDER_SEARCH.out.summary
    } else {
        ch_macsyfinder_results = Channel.empty()
    }

    // Phenotype Prediction - run on all
    if (!options.skip_traitar) {
        // Skip the download if the DB is already cached at options.pfamdb (published
        // there by a previous run - see conf/modules.config). Can't use storeDir here:
        // TRAITAR_PFAMGET also emits a tuple for versions-topic reporting, and
        // storeDir only supports processes whose outputs are all `val`/`path`.
        def pfamdb_cached = file("${options.pfamdb}/pfam_data")
        if (pfamdb_cached.exists()) {
            ch_pfamdb = Channel.fromPath(pfamdb_cached, checkIfExists: true)
        } else {
            TRAITAR_PFAMGET()
            ch_pfamdb = TRAITAR_PFAMGET.out.pfam_db
        }

        TRAITAR(
            ch_annotated_proteins,
            'from_genes',
            ch_pfamdb
        )
        ch_traitar_results = TRAITAR.out.predictions_combined
        ch_traitar_single_votes = TRAITAR.out.predictions_single_votes
    } else {
        ch_traitar_results = Channel.empty()
        ch_traitar_single_votes = Channel.empty()
    }

    // Metabolic Modeling - CarveMe (protein-based)
    if (!options.skip_carveme) {
        ch_carveme_input = ch_annotated_proteins.map { meta, faa ->
            // Keep medium_carveme in meta for ext.args configuration (selects which
            // medium, by name, to gap-fill with - from whichever mediadb applies below).
            // A per-sample medium_carveme_tsv overrides the global --carveme_mediadb
            // for that sample only; otherwise fall back to --carveme_mediadb, or
            // CarveMe's own bundled default database if neither is set.
            def mediadb = meta.medium_carveme_tsv ? file(meta.medium_carveme_tsv) :
                (options.carveme_mediadb ? file(options.carveme_mediadb) : [])
            [ meta, faa, [], mediadb, [], [], [] ]
        }
        CARVEME_CARVE(ch_carveme_input)
        ch_carveme_model = CARVEME_CARVE.out.model
    } else {
        ch_carveme_model = Channel.empty()
    }

    // Metabolic Modeling - Gapseq (genome-based)
    if (!options.skip_gapseq) {
        // Workflow automatically uses custom mode if any gapseq_*_args are provided
        // Otherwise uses streamlined 'doall' mode (recommended for most users)

        GAPSEQ_WORKFLOW(ch_genomes, options)

        ch_gapseq_model = GAPSEQ_WORKFLOW.out.model
        ch_gapseq_xml = GAPSEQ_WORKFLOW.out.xml
        ch_gapseq_pathways = GAPSEQ_WORKFLOW.out.pathways
        ch_gapseq_transporters = GAPSEQ_WORKFLOW.out.transporters

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
    // MODULE: Memote - Evaluate model quality
    //
    ch_memote_report = Channel.empty()
    ch_memote_json = Channel.empty()
    if (!options.skip_memote) {
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
        MEMOTE_RUN(
            ch_models_for_memote
        )
        ch_memote_json = MEMOTE_RUN.out.json

        // Generate HTML report for visualization
        MEMOTE_REPORT(
            ch_models_for_memote
        )
        ch_memote_report = MEMOTE_REPORT.out.report
    }

    // Generate summary table combining all results
    // Collect sample IDs and write to file
    ch_sample_ids = ch_genomes.map { meta, fasta -> meta.id }.collectFile(name: 'sample_ids.txt', newLine: true)

    // Collect all results for summary (handling empty channels)
    ch_macsyfinder_for_summary = ch_macsyfinder_results.map { meta, file -> file }.collect().ifEmpty([])
    ch_traitar_majority_for_summary = ch_traitar_results.map { meta, file -> file }.collect().ifEmpty([])
    ch_traitar_single_for_summary = ch_traitar_single_votes.map { meta, file -> file }.collect().ifEmpty([])
    ch_carveme_for_summary = ch_carveme_model.map { meta, file -> file }.collect().ifEmpty([])

    // Use RENAME_GAPSEQ_XML process to rename XML files (avoid collision with CarveMe)
    if (!options.skip_gapseq) {
        ch_gapseq_xml_filtered = ch_gapseq_xml.map { meta, xml ->
            // Filter out draft models if xml is a list
            def final_xml = xml instanceof List ? xml.findAll { !it.name.contains('-draft') } : xml
            [ meta, final_xml ]
        }
        RENAME_GAPSEQ_XML(ch_gapseq_xml_filtered)
        ch_gapseq_for_summary = RENAME_GAPSEQ_XML.out.xml.map { meta, xml -> xml }.flatten().collect().ifEmpty([])
    } else {
        ch_gapseq_for_summary = Channel.empty().collect().ifEmpty([])
    }

    ch_gapseq_tbl_for_summary = ch_gapseq_tbl.map { meta, files -> files }.flatten().collect().ifEmpty([])
    ch_memote_for_summary = ch_memote_json.map { meta, json -> json }.collect().ifEmpty([])

    BACMODEL_SUMMARY(
        ch_sample_ids,
        ch_macsyfinder_for_summary,
        ch_traitar_majority_for_summary,
        ch_traitar_single_for_summary,
        ch_carveme_for_summary,
        ch_gapseq_for_summary,
        ch_gapseq_tbl_for_summary,
        ch_memote_for_summary,
        !options.skip_macsyfinder,
        !options.skip_traitar,
        !options.skip_carveme,
        !options.skip_gapseq,
        !options.skip_memote
    )

    emit:
    proteins         = ch_annotated_proteins
    gff              = ch_annotated_gff
    macsyfinder      = ch_macsyfinder_results
    traitar          = ch_traitar_results
    carveme          = ch_carveme_model
    gapseq           = ch_gapseq_model
    gapseq_xml       = ch_gapseq_xml
    memote           = ch_memote_report
    summary          = BACMODEL_SUMMARY.out.tsv
}
