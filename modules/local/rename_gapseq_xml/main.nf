process RENAME_GAPSEQ_XML {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/31/31ec84fb4e50446228f9f2d971b8c08cd68977d20fa3cd24ce92851d15e8bb7d/data':
        'community.wave.seqera.io/library/pip_pygments:85c7e7669ec60a48' }"

    input:
    tuple val(meta), path(xml)

    output:
    tuple val(meta), path("*_gapseq.xml"), emit: xml
    path "versions.yml"              , emit: versions

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_gapseq.xml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """
}
