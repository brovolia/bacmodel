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
    proteins    = BACMODEL_FUNCTIONAL_ANNOTATION.out.proteins
    gff         = BACMODEL_FUNCTIONAL_ANNOTATION.out.gff
    macsyfinder = BACMODEL_FUNCTIONAL_ANNOTATION.out.macsyfinder
    traitar     = BACMODEL_FUNCTIONAL_ANNOTATION.out.traitar
    carveme     = BACMODEL_FUNCTIONAL_ANNOTATION.out.carveme
    gapseq      = BACMODEL_FUNCTIONAL_ANNOTATION.out.gapseq
    summary     = BACMODEL_FUNCTIONAL_ANNOTATION.out.summary
    versions    = ch_versions
}
