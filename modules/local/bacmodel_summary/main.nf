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
    val(run_macsyfinder)
    val(run_traitar)
    val(run_carveme)
    val(run_gapseq)
    val(run_memote)

    output:
    path("bacmodel_summary.tsv")        , emit: tsv
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //' | sed 's/\\.[0-9]*\$//' | sed 's/.*/\"&\"/'"), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('pandas'), eval("python3 -c 'import pandas; print(pandas.__version__)'"), topic: versions, emit: versions_pandas

    when:
    task.ext.when == null || task.ext.when

    script:
    def macsyfinder_files = macsyfinder_results ? macsyfinder_results.collect { "'$it'" }.join(' ') : ''
    def traitar_majority_files = traitar_majority_results ? traitar_majority_results.collect { "'$it'" }.join(' ') : ''
    def traitar_single_files = traitar_single_results ? traitar_single_results.collect { "'$it'" }.join(' ') : ''
    def carveme_files = carveme_models ? carveme_models.collect { "'$it'" }.join(' ') : ''
    def gapseq_files = gapseq_models ? gapseq_models.collect { "'$it'" }.join(' ') : ''
    def gapseq_tbl_files = gapseq_tbls ? gapseq_tbls.collect { "'$it'" }.join(' ') : ''
    def memote_files = memote_jsons ? memote_jsons.collect { "'$it'" }.join(' ') : ''
    """
    python3 <<'EOF'
    import pandas as pd
    import os
    from pathlib import Path

    # Read sample IDs from file (one per line)
    with open("${sample_ids_file}", 'r') as f:
        sample_ids = [line.strip() for line in f if line.strip()]

    # Tool enable flags (convert Nextflow boolean to Python)
    run_macsyfinder = "${run_macsyfinder}" == "true"
    run_traitar = "${run_traitar}" == "true"
    run_carveme = "${run_carveme}" == "true"
    run_gapseq = "${run_gapseq}" == "true"
    run_memote = "${run_memote}" == "true"

    # Initialize summary dataframe with conditional columns
    summary_data = {'sample_id': sample_ids}

    # Add columns only for enabled tools
    if run_macsyfinder:
        summary_data['macsyfinder_systems'] = [0] * len(sample_ids)
        summary_data['macsyfinder_types'] = [''] * len(sample_ids)

    if run_traitar:
        summary_data['traitar_phenotypes_majority'] = [0] * len(sample_ids)
        summary_data['traitar_phenotypes_single'] = [0] * len(sample_ids)

    if run_carveme:
        summary_data['carveme_model'] = ['No'] * len(sample_ids)
        summary_data['carveme_reactions'] = [0] * len(sample_ids)

    if run_gapseq:
        summary_data['gapseq_model'] = ['No'] * len(sample_ids)
        summary_data['gapseq_reactions'] = [0] * len(sample_ids)

    # Process MacSyFinder results (only if enabled)
    if run_macsyfinder:
        macsyfinder_files = [f for f in "${macsyfinder_files}".split() if f and f != "null"]
        for mf_file in macsyfinder_files:
            if mf_file.strip("'"):
                # Extract sample name from path (file is usually sample/all_systems.tsv)
                file_path = Path(mf_file.strip("'"))
                sample = file_path.parent.name if file_path.parent.name else file_path.stem

                if sample in sample_ids:
                    idx = sample_ids.index(sample)
                    try:
                        # Read file and count non-comment lines (actual detected systems)
                        with open(mf_file.strip("'"), 'r') as f:
                            lines = f.readlines()

                        # Filter out comment lines (starting with #)
                        data_lines = [line for line in lines if line.strip() and not line.startswith('#')]
                        systems_count = len(data_lines)

                        # Extract system types if systems were found
                        system_types = set()
                        if systems_count > 0:
                            # Parse TSV data - typically has columns like: replicon, hit_id, system, etc.
                            for line in data_lines:
                                parts = line.strip().split('\\t')
                                if len(parts) >= 3:  # Assuming system type is in 3rd column
                                    system_types.add(parts[2])

                        summary_data['macsyfinder_systems'][idx] = systems_count
                        summary_data['macsyfinder_types'][idx] = ', '.join(sorted(system_types)) if system_types else ''
                    except Exception as e:
                        pass

    # Process TRAITAR results (only if enabled)
    if run_traitar:
        # Process TRAITAR majority-vote results (conservative predictions, score = 3.0)
        traitar_majority_files = [f for f in "${traitar_majority_files}".split() if f and f != "null"]
        for tr_file in traitar_majority_files:
            if tr_file.strip("'"):
                try:
                    with open(tr_file.strip("'"), 'r') as f:
                        lines = f.readlines()
                        if len(lines) > 1:  # Has header + data
                            data_line = lines[1].strip().split('\\t')
                            sample = data_line[0] if data_line else None
                            if sample and sample in sample_ids:
                                idx = sample_ids.index(sample)
                                # Count phenotypes with score 3.0 (positive predictions)
                                phenotypes = sum(1 for val in data_line[1:] if val.strip() == '3.0')
                                summary_data['traitar_phenotypes_majority'][idx] = phenotypes
                except Exception as e:
                    pass

        # Process TRAITAR single-votes results (permissive predictions, score > 0)
        traitar_single_files = [f for f in "${traitar_single_files}".split() if f and f != "null"]
        for tr_file in traitar_single_files:
            if tr_file.strip("'"):
                try:
                    with open(tr_file.strip("'"), 'r') as f:
                        lines = f.readlines()
                        if len(lines) > 1:  # Has header + data
                            data_line = lines[1].strip().split('\\t')
                            sample = data_line[0] if data_line else None
                            if sample and sample in sample_ids:
                                idx = sample_ids.index(sample)
                                # Count phenotypes with score > 0 (any evidence)
                                phenotypes = sum(1 for val in data_line[1:] if float(val.strip()) > 0 if val.strip())
                                summary_data['traitar_phenotypes_single'][idx] = phenotypes
                except Exception as e:
                    pass

    # Process CarveMe models (only if enabled)
    if run_carveme:
        carveme_files = [f for f in "${carveme_files}".split() if f and f != "null"]
        for cm_file in carveme_files:
            if cm_file.strip("'"):
                sample = Path(cm_file.strip("'")).stem
                if sample in sample_ids:
                    idx = sample_ids.index(sample)
                    summary_data['carveme_model'][idx] = 'Yes'
                    # Count reactions in XML (rough estimate by counting <reaction> tags)
                    try:
                        with open(cm_file.strip("'"), 'r') as f:
                            content = f.read()
                            reactions = content.count('<reaction ')
                        summary_data['carveme_reactions'][idx] = reactions
                    except:
                        pass

    # Process Gapseq models (only if enabled)
    if run_gapseq:
        gapseq_files = [f for f in "${gapseq_files}".split() if f and f != "null"]
        for gs_file in gapseq_files:
            if gs_file.strip("'"):
                # Remove _gapseq suffix and -draft suffix to get sample name
                sample = Path(gs_file.strip("'")).stem.replace("_gapseq", "").replace("-draft", "")
                if sample in sample_ids:
                    idx = sample_ids.index(sample)
                    summary_data['gapseq_model'][idx] = 'Yes'
                    # Count reactions in XML (same approach as CarveMe)
                    try:
                        with open(gs_file.strip("'"), 'r') as f:
                            content = f.read()
                            reactions = content.count('<reaction ')
                        summary_data['gapseq_reactions'][idx] = reactions
                    except:
                        pass

    # Create and save dataframe (sorted by sample_id for deterministic output)
    df = pd.DataFrame(summary_data)
    df = df.sort_values('sample_id').reset_index(drop=True)
    df.to_csv('bacmodel_summary.tsv', sep='\\t', index=False)
    EOF
    """

    stub:
    """
    touch bacmodel_summary.tsv
    """
}
