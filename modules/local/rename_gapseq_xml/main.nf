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
    # Rename XML files with _gapseq suffix to avoid collision with CarveMe
    for xml_file in ${xml}; do
        if [[ ! \$xml_file =~ -draft\\.xml\$ ]]; then
            base=\$(basename "\$xml_file" .xml)
            cp "\$xml_file" "\${base}_gapseq.xml"
        fi
    done
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_gapseq.xml
    """
}
