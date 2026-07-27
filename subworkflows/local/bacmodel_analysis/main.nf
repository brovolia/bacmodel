/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Functional annotation and phenotypic modeling of bacterial genomes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Main analysis workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BACMODEL_FUNCTIONAL_ANNOTATION } from '../bacmodel_annotation/main'

workflow BACMODEL_ANALYSIS {

    take:
    ch_genomes         // channel: [ val(meta), path(fasta) ]
    annotation_options // map: annotation/analysis tool options, see workflows/bacmodel.nf

    main:

    //
    // Run functional annotation and modeling
    //
    BACMODEL_FUNCTIONAL_ANNOTATION(ch_genomes, annotation_options)

    emit:
    proteins    = BACMODEL_FUNCTIONAL_ANNOTATION.out.proteins
    gff         = BACMODEL_FUNCTIONAL_ANNOTATION.out.gff
    macsyfinder = BACMODEL_FUNCTIONAL_ANNOTATION.out.macsyfinder
    traitar     = BACMODEL_FUNCTIONAL_ANNOTATION.out.traitar
    carveme     = BACMODEL_FUNCTIONAL_ANNOTATION.out.carveme
    gapseq      = BACMODEL_FUNCTIONAL_ANNOTATION.out.gapseq
    memote      = BACMODEL_FUNCTIONAL_ANNOTATION.out.memote
    summary     = BACMODEL_FUNCTIONAL_ANNOTATION.out.summary
}
