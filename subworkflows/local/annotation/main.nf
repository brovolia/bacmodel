/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ANNOTATION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Genome annotation via Prokka (default) or Bakta.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PROKKA                } from '../../../modules/nf-core/prokka/main'
include { BAKTA_BAKTA           } from '../../../modules/nf-core/bakta/bakta/main'
include { BAKTA_BAKTADBDOWNLOAD } from '../../../modules/nf-core/bakta/baktadbdownload/main'

workflow ANNOTATION {

    take:
    ch_genomes      // channel: [ val(meta), path(fasta) ]
    annotation_tool // string: 'prokka' or 'bakta'
    bakta_db        // string: pre-downloaded/cached Bakta DB dir (only used when annotation_tool == 'bakta')

    main:

    ch_proteins = Channel.empty()
    ch_gff = Channel.empty()

    if (annotation_tool == 'bakta') {
        // Skip the download if the DB is already cached at bakta_db (published
        // there by a previous run - see conf/modules.config). Can't use storeDir here:
        // BAKTA_BAKTADBDOWNLOAD also emits a tuple for versions-topic reporting, and
        // storeDir only supports processes whose outputs are all `val`/`path`.
        def bakta_db_cached = file("${bakta_db}/db")
        if (bakta_db_cached.exists()) {
            ch_bakta_db = Channel.fromPath(bakta_db_cached, checkIfExists: true)
        } else {
            BAKTA_BAKTADBDOWNLOAD()
            ch_bakta_db = BAKTA_BAKTADBDOWNLOAD.out.db
        }

        BAKTA_BAKTA(ch_genomes, ch_bakta_db, [], [], [], [])
        ch_proteins = BAKTA_BAKTA.out.faa
        ch_gff = BAKTA_BAKTA.out.gff
    } else {
        // Prokka is the default (preferred for speed) - also the fallback for any
        // unrecognised value, matching nextflow_schema.json's enum + default.
        PROKKA(ch_genomes, [], [])
        ch_proteins = PROKKA.out.faa
        ch_gff = PROKKA.out.gff
    }

    emit:
    proteins = ch_proteins // channel: [ val(meta), path(faa) ]
    gff      = ch_gff      // channel: [ val(meta), path(gff) ]
}
