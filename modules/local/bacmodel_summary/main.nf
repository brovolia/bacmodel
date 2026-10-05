process BACMODEL_SUMMARY {
    tag "summary"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    path(sample_ids_file)
    path(macsyfinder_results)
    path(traitar_majority_results)
    path(traitar_single_results)
    path(carveme_models)
    path(gapseq_models)
    path(gapseq_tbls)
    path(memote_jsons)
    val(macsyfinder_enabled)
    val(traitar_enabled)
    val(carveme_enabled)
    val(gapseq_enabled)
    val(memote_enabled)

    output:
    path("bacmodel_summary.tsv")        , emit: tsv
    path("versions.yml")                , topic: versions, emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    macsyfinder_files = macsyfinder_results ? macsyfinder_results.collect { "'$it'" }.join(' ') : ''
    traitar_majority_files = traitar_majority_results ? traitar_majority_results.collect { "'$it'" }.join(' ') : ''
    traitar_single_files = traitar_single_results ? traitar_single_results.collect { "'$it'" }.join(' ') : ''
    carveme_files = carveme_models ? carveme_models.collect { "'$it'" }.join(' ') : ''
    gapseq_files = gapseq_models ? gapseq_models.collect { "'$it'" }.join(' ') : ''
    gapseq_tbl_files = gapseq_tbls ? gapseq_tbls.collect { "'$it'" }.join(' ') : ''
    memote_files = memote_jsons ? memote_jsons.collect { "'$it'" }.join(' ') : ''
    template 'bacmodel_summary.py'

    stub:
    """
    touch bacmodel_summary.tsv
    touch versions.yml
    """
}
