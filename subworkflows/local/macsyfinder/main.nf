/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MACSYFINDER
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Macromolecular system detection (e.g. secretion systems) from annotated proteins.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MACSYFINDER_DOWNLOAD } from '../../../modules/nf-core/macsyfinder/download/main'
include { MACSYFINDER_SEARCH   } from '../../../modules/nf-core/macsyfinder/search/main'

workflow MACSYFINDER {

    take:
    ch_proteins        // channel: [ val(meta), path(faa) ]
    macsyfinder_models // string: model set to use, e.g. 'TXSS' (non-empty, enforced by nextflow_schema.json)
    macsyfinder_db     // string: pre-downloaded/cached models dir (one subdir per macsyfinder_models value)

    main:

    // Skip the download if these models are already cached at
    // macsyfinder_db/<model_name> (published there by a previous run - see
    // conf/modules.config). Can't use storeDir here: MACSYFINDER_DOWNLOAD also
    // emits tuples for versions-topic reporting, and storeDir only supports
    // processes whose outputs are all `val`/`path`.
    def macsyfinder_models_cached = file("${macsyfinder_db}/${macsyfinder_models}/models")
    if (macsyfinder_models_cached.exists()) {
        ch_macsyfinder_models = Channel.fromPath(macsyfinder_models_cached, checkIfExists: true)
    } else {
        MACSYFINDER_DOWNLOAD(macsyfinder_models)
        ch_macsyfinder_models = MACSYFINDER_DOWNLOAD.out.models
    }

    MACSYFINDER_SEARCH(
        ch_proteins,
        ch_macsyfinder_models,
        macsyfinder_models
    )

    emit:
    results = MACSYFINDER_SEARCH.out.summary // channel: [ val(meta), path(tsv) ]
}
