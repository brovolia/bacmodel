/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    BACMODEL SUBWORKFLOW - Using nf-core modules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Orchestrates functional annotation and modeling of bacterial genomes
    using nf-core modules and custom local modules for specialized tools
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PROKKA                  } from '../../modules/nf-core/prokka/main'
include { BAKTA_BAKTA             } from '../../modules/nf-core/bakta/bakta/main'
include { MACSYFINDER_SEARCH      } from '../../modules/nf-core/macsyfinder/search/main'
include { TRAITAR                 } from '../../modules/nf-core/traitar/run/main'
include { CARVEME_CARVE           } from '../../modules/nf-core/carveme/carve/main'

workflow BACMODEL_FUNCTIONAL_ANNOTATION {

    take:
    ch_genomes  // channel: [ val(meta), path(fasta) ]

    main:

    ch_versions = Channel.empty()

    // Option 1: Prokka for annotation (preferred for speed)
    if (params.annotation_tool == 'prokka' || !params.annotation_tool) {
        PROKKA(ch_genomes, [], [])
        ch_annotated_proteins = PROKKA.out.faa
        ch_annotated_gff = PROKKA.out.gff
        ch_versions = ch_versions.mix(PROKKA.out.versions)
    }

    // Option 2: Bakta for annotation (alternative)
    if (params.annotation_tool == 'bakta') {
        BAKTA_BAKTA(ch_genomes, [], [], [])
        ch_annotated_proteins = BAKTA_BAKTA.out.faa
        ch_annotated_gff = BAKTA_BAKTA.out.gff
        ch_versions = ch_versions.mix(BAKTA_BAKTA.out.versions)
    }

    // Macromolecular Systems - run on all
    if (params.run_macsyfinder) {
        ch_macsyfinder_input = ch_annotated_proteins
            .map { meta, faa -> [ meta, faa, [] ] }
        
        MACSYFINDER_SEARCH(
            ch_macsyfinder_input
        )
        ch_versions = ch_versions.mix(MACSYFINDER_SEARCH.out.versions)
    }

    // Phenotype Prediction - run on all
    if (params.run_traitar) {
        TRAITAR(
            ch_annotated_proteins
        )
        ch_versions = ch_versions.mix(TRAITAR.out.versions)
    }

    // Metabolic Modeling - run on all
    if (params.run_carveme) {
        CARVEME_CARVE(ch_genomes)
        ch_versions = ch_versions.mix(CARVEME_CARVE.out.versions)
    }

    emit:
    prokka_dir       = PROKKA.out.prokka_dir.ifEmpty([])
    bakta_dir        = BAKTA_BAKTA.out.bakta_dir.ifEmpty([])
    macsyfinder_dir  = MACSYFINDER_SEARCH.out.summary.ifEmpty([])
    traitar_dir      = TRAITAR.out.traitar_results.ifEmpty([])
    carveme_model    = CARVEME_CARVE.out.model.ifEmpty([])
    versions         = ch_versions
}
