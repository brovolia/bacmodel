/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Functional annotation and phenotypic modeling of bacterial genomes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Main analysis workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BACMODEL_FUNCTIONAL_ANNOTATION } from '../../subworkflows/local/bacmodel_annotation'

workflow BACMODEL_ANALYSIS {

    take:
    ch_genomes  // channel: [ val(meta), path(fasta) ]

    main:

    ch_versions = Channel.empty()

    //
    // Run functional annotation and modeling
    //
    BACMODEL_FUNCTIONAL_ANNOTATION(ch_genomes)
    ch_versions = ch_versions.mix(BACMODEL_FUNCTIONAL_ANNOTATION.out.versions)

    emit:
    annotation_results = BACMODEL_FUNCTIONAL_ANNOTATION.out
    versions            = ch_versions
}
