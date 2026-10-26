#!/usr/bin/env python3
import sys
import pandas as pd

# Read sample IDs from file (one per line)
with open("${sample_ids_file}", 'r') as f:
    sample_ids = [line.strip() for line in f if line.strip()]

# Tool enable flags (convert Nextflow boolean to Python)
macsyfinder_enabled = "${macsyfinder_enabled}" == "true"
traitar_enabled = "${traitar_enabled}" == "true"
carveme_enabled = "${carveme_enabled}" == "true"
gapseq_enabled = "${gapseq_enabled}" == "true"
memote_enabled = "${memote_enabled}" == "true"

# Initialize summary dataframe with conditional columns
summary_data = {'sample_id': sample_ids}

# Add columns only for enabled tools
if macsyfinder_enabled:
    summary_data['macsyfinder_systems'] = [0] * len(sample_ids)
    summary_data['macsyfinder_types'] = [''] * len(sample_ids)

if traitar_enabled:
    summary_data['traitar_phenotypes_majority'] = [0] * len(sample_ids)
    summary_data['traitar_phenotypes_single'] = [0] * len(sample_ids)

if carveme_enabled:
    summary_data['carveme_model'] = ['No'] * len(sample_ids)
    summary_data['carveme_reactions'] = [0] * len(sample_ids)

if gapseq_enabled:
    summary_data['gapseq_model'] = ['No'] * len(sample_ids)
    summary_data['gapseq_reactions'] = [0] * len(sample_ids)

# Process MacSyFinder results (only if enabled)
if macsyfinder_enabled:
    macsyfinder_files = [f.strip("'") for f in "${macsyfinder_files}".split() if f and f != "null"]
    macsyfinder_ids = [i.strip("'") for i in "${macsyfinder_ids_str}".split() if i and i != "null"]
    for sample, mf_file in zip(macsyfinder_ids, macsyfinder_files):
        if sample in sample_ids:
            idx = sample_ids.index(sample)
            try:
                # '#'-prefixed metadata comments precede the header + one row per
                # detected system; when none are found the file is comments only,
                # which pandas reports as EmptyDataError (treated as zero below).
                df = pd.read_csv(mf_file, sep='\t', comment='#')
                summary_data['macsyfinder_systems'][idx] = len(df)
                if len(df.columns) >= 3 and not df.empty:
                    # Assuming system type is in the 3rd column, as before.
                    types = sorted(df.iloc[:, 2].astype(str).unique())
                    summary_data['macsyfinder_types'][idx] = ', '.join(types)
            except Exception as e:
                pass

# Process TRAITAR results (only if enabled)
if traitar_enabled:
    # Process TRAITAR majority-vote results (conservative predictions, score = 3.0)
    traitar_majority_files = [f for f in "${traitar_majority_files}".split() if f and f != "null"]
    for tr_file in traitar_majority_files:
        if tr_file.strip("'"):
            try:
                with open(tr_file.strip("'"), 'r') as f:
                    lines = f.readlines()
                    if len(lines) > 1:  # Has header + data
                        data_line = lines[1].strip().split('\t')
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
                        data_line = lines[1].strip().split('\t')
                        sample = data_line[0] if data_line else None
                        if sample and sample in sample_ids:
                            idx = sample_ids.index(sample)
                            # Count phenotypes with score > 0 (any evidence)
                            phenotypes = sum(1 for val in data_line[1:] if float(val.strip()) > 0 if val.strip())
                            summary_data['traitar_phenotypes_single'][idx] = phenotypes
            except Exception as e:
                pass

# Process CarveMe models (only if enabled)
if carveme_enabled:
    carveme_files = [f.strip("'") for f in "${carveme_files}".split() if f and f != "null"]
    carveme_ids = [i.strip("'") for i in "${carveme_ids_str}".split() if i and i != "null"]
    for sample, cm_file in zip(carveme_ids, carveme_files):
        if sample in sample_ids:
            idx = sample_ids.index(sample)
            summary_data['carveme_model'][idx] = 'Yes'
            # Count reactions in XML (rough estimate by counting <reaction> tags)
            try:
                with open(cm_file, 'r') as f:
                    content = f.read()
                    reactions = content.count('<reaction ')
                summary_data['carveme_reactions'][idx] = reactions
            except Exception:
                pass

# Process Gapseq models (only if enabled)
if gapseq_enabled:
    gapseq_files = [f.strip("'") for f in "${gapseq_files}".split() if f and f != "null"]
    gapseq_ids = [i.strip("'") for i in "${gapseq_ids_str}".split() if i and i != "null"]
    for sample, gs_file in zip(gapseq_ids, gapseq_files):
        if sample in sample_ids:
            idx = sample_ids.index(sample)
            summary_data['gapseq_model'][idx] = 'Yes'
            # Count reactions in XML (same approach as CarveMe)
            try:
                with open(gs_file, 'r') as f:
                    content = f.read()
                    reactions = content.count('<reaction ')
                summary_data['gapseq_reactions'][idx] = reactions
            except Exception:
                pass

# Create and save dataframe (sorted by sample_id for deterministic output)
df = pd.DataFrame(summary_data)
df = df.sort_values('sample_id').reset_index(drop=True)
df.to_csv('bacmodel_summary.tsv', sep='\t', index=False)

with open("versions.yml", "w") as vf:
    vf.write('"${task.process}":\\n')
    vf.write(f'    python: "{".".join(sys.version.split()[0].split(".")[:2])}"\\n')
    vf.write(f'    pandas: "{pd.__version__}"\\n')
