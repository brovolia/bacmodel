/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    TRAITAR_WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Phenotype prediction from annotated proteins via TRAITAR.
    Named TRAITAR_WORKFLOW (not TRAITAR) to avoid colliding with the TRAITAR
    process imported from modules/nf-core/traitar/run.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { TRAITAR_PFAMGET } from '../../../modules/nf-core/traitar/pfamget/main'
include { TRAITAR         } from '../../../modules/nf-core/traitar/run/main'

workflow TRAITAR_WORKFLOW {

    take:
    ch_proteins // channel: [ val(meta), path(faa) ]
    pfam_db      // string: pre-downloaded/cached Pfam DB dir

    main:

    // Skip the download if the DB is already cached at pfam_db (published there
    // by a previous run - see conf/modules.config). Can't use storeDir here:
    // TRAITAR_PFAMGET also emits a tuple for versions-topic reporting, and
    // storeDir only supports processes whose outputs are all `val`/`path`.
    def pfam_db_cached = file("${pfam_db}/pfam_data")
    if (pfam_db_cached.exists()) {
        ch_pfam_db = Channel.fromPath(pfam_db_cached, checkIfExists: true)
    } else {
        TRAITAR_PFAMGET()
        ch_pfam_db = TRAITAR_PFAMGET.out.pfam_db
    }

    TRAITAR(
        ch_proteins,
        'from_genes',
        ch_pfam_db
    )

    emit:
    results      = TRAITAR.out.predictions_combined     // channel: [ val(meta), path(txt) ]
    single_votes = TRAITAR.out.predictions_single_votes // channel: [ val(meta), path(txt) ]
}
