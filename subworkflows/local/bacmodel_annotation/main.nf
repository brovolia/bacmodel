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
include { GAPSEQ_DOALL            } from '../../../modules/nf-core/gapseq/doall/main'
include { MEMOTE_RUN              } from '../../../modules/nf-core/memote/run/main'
include { MEMOTE_REPORT           } from '../../../modules/nf-core/memote/report/main'
include { BACMODEL_SUMMARY        } from '../../../modules/local/bacmodel_summary/main'
include { RENAME_GAPSEQ_XML       } from '../../../modules/local/rename_gapseq_xml/main'

workflow BACMODEL_FUNCTIONAL_ANNOTATION {

    take:
    ch_genomes  // channel: [ val(meta), path(fasta) ]

    main:

    ch_versions = Channel.empty()
    ch_annotated_proteins = Channel.empty()
    ch_annotated_gff = Channel.empty()
    ch_macsyfinder_results = Channel.empty()
    ch_traitar_results = Channel.empty()
    ch_traitar_single_votes = Channel.empty()
    ch_carveme_model = Channel.empty()
    ch_gapseq_model = Channel.empty()
    ch_gapseq_tbl = Channel.empty()

    // Option 1: Prokka for annotation (preferred for speed)
    if (params.annotation_tool == 'prokka' || !params.annotation_tool) {
        PROKKA(ch_genomes, [], [])
        ch_annotated_proteins = PROKKA.out.faa
        ch_annotated_gff = PROKKA.out.gff
        // versions emitted via topic system
    }

    // Option 2: Bakta for annotation (alternative)
    if (params.annotation_tool == 'bakta') {
        // Handle Bakta database
        ch_baktadb = Channel.empty()
        
        if (params.baktadb_download) {
            // Download database
            BAKTA_BAKTADBDOWNLOAD()
            ch_baktadb = BAKTA_BAKTADBDOWNLOAD.out.db
        } else if (params.baktadb) {
            // Use provided database path
            ch_baktadb = Channel.fromPath(params.baktadb, checkIfExists: true)
        } else {
            error "Bakta requires a database. Please provide --baktadb /path/to/db or use --baktadb_download true"
        }
        
        BAKTA_BAKTA(ch_genomes, ch_baktadb, [], [], [], [])
        ch_annotated_proteins = BAKTA_BAKTA.out.faa
        ch_annotated_gff = BAKTA_BAKTA.out.gff
    }

    // Macromolecular Systems - run on all
    if (params.run_macsyfinder) {
        if (!params.macsyfinder_models) {
            error "MacSyFinder requires model names. Please provide --macsyfinder_models (e.g., 'TXSS')"
        }
        
        // Download MacSyFinder models
        MACSYFINDER_DOWNLOAD(params.macsyfinder_models)
        
        MACSYFINDER_SEARCH(
            ch_annotated_proteins,
            MACSYFINDER_DOWNLOAD.out.models,
            params.macsyfinder_models
        )
        ch_macsyfinder_results = MACSYFINDER_SEARCH.out.summary
    } else {
        ch_macsyfinder_results = Channel.empty()
    }

    // Phenotype Prediction - run on all
    if (params.run_traitar) {
        // Handle Pfam database for TRAITAR
        ch_pfamdb = Channel.empty()
        
        if (params.pfamdb_download) {
            // Download database
            TRAITAR_PFAMGET()
            ch_pfamdb = TRAITAR_PFAMGET.out.pfam_db
        } else if (params.pfamdb) {
            // Use provided database path
            ch_pfamdb = Channel.fromPath(params.pfamdb, checkIfExists: true)
        } else {
            error "TRAITAR requires a Pfam database. Please provide --pfamdb /path/to/pfam or use --pfamdb_download true"
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
    if (params.run_carveme) {
        ch_carveme_input = ch_annotated_proteins.map { meta, faa -> 
            // Keep medium_carveme in meta for ext.args configuration
            // Pass mediadb as input (or empty if using default)
            def mediadb = params.carveme_mediadb ? file(params.carveme_mediadb) : []
            [ meta, faa, [], mediadb, [], [], [] ]
        }
        CARVEME_CARVE(ch_carveme_input)
        ch_carveme_model = CARVEME_CARVE.out.model
    } else {
        ch_carveme_model = Channel.empty()
    }

    // Metabolic Modeling - Gapseq (genome-based)
    if (params.run_gapseq) {
        ch_gapseq_input = ch_genomes.map { meta, fasta -> 
            // medium_gapseq from meta: can be empty, a medium name (LB, M9), or path to CSV file
            def medium = []
            if (meta.medium_gapseq && meta.medium_gapseq.toString().contains('/')) {
                // It's a file path - convert to file object
                medium = file(meta.medium_gapseq)
            }
            // If it's just a name (LB, M9, etc.), leave medium as [] and handle via ext.args
            [ meta, fasta, medium ]
        }
        GAPSEQ_DOALL(ch_gapseq_input)
        ch_gapseq_model = GAPSEQ_DOALL.out.model
        ch_gapseq_xml = GAPSEQ_DOALL.out.xml
        ch_gapseq_tbl = GAPSEQ_DOALL.out.tbl
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
    if (params.run_memote) {
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
    if (params.run_gapseq) {
        ch_gapseq_xml_filtered = ch_gapseq_xml.map { meta, xml ->
            // Filter out draft models if xml is a list
            def final_xml = xml instanceof List ? xml.findAll { !it.name.contains('-draft') } : xml
            [ meta, final_xml ]
        }
        RENAME_GAPSEQ_XML(ch_gapseq_xml_filtered)
        ch_gapseq_for_summary = RENAME_GAPSEQ_XML.out.xml.map { meta, xml -> xml }.flatten().collect().ifEmpty([])
    } else {
        ch_gapseq_for_summary = Channel.empty()
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
        params.run_macsyfinder ?: false,
        params.run_traitar ?: false,
        params.run_carveme ?: false,
        params.run_gapseq ?: false,
        params.run_memote ?: false
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
    versions         = ch_versions
}
