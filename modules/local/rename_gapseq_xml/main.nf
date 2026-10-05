process RENAME_GAPSEQ_XML {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'community.wave.seqera.io/library/gapseq:2.1.0--31c8824b3592beaf' :
        'quay.io/biocontainers/gapseq:2.1.0--hdfd78af_0' }"

    input:
    tuple val(meta), path(xml)

    output:
    tuple val(meta), path("*_gapseq.xml"), emit: xml

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Rename the final (non-draft) gapseq XML model to a canonical
    # ${prefix}_gapseq.xml, avoiding collision with CarveMe outputs.
    # The upstream suffix varies by workflow (doall: no suffix, custom
    # find/findtransport/draft/fill: "-filled"), so we normalize to the
    # sample prefix here rather than preserving the input basename -
    # otherwise BACMODEL_SUMMARY's sample-name matching breaks.
    for xml_file in ${xml}; do
        if [[ ! \$xml_file =~ -draft\\.xml\$ ]]; then
            cp "\$xml_file" "${prefix}_gapseq.xml"
        fi
    done
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_gapseq.xml
    """
}
