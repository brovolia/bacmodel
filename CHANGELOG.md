# nf-core/bacmodel: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### `Changed`

- **Breaking:** Renamed `run_macsyfinder`/`run_traitar`/`run_carveme`/`run_gapseq`/`run_memote` params to `skip_macsyfinder`/`skip_traitar`/`skip_carveme`/`skip_gapseq`/`skip_memote`, following the nf-core `skip_*` convention. Default behavior is unchanged: MacSyFinder, TRAITAR, and CarveMe still run unless skipped; gapseq and MEMOTE are still opt-in (`skip_gapseq`/`skip_memote` default to `true`).
- **Breaking:** Split the overloaded `medium_gapseq` samplesheet column (name **or** path) into `medium_gapseq` (built-in medium name only, e.g. `LB`/`M9`) and `medium_gapseq_csv` (path to a custom medium CSV only). Existing samplesheets that put a file path in `medium_gapseq` must move it to the new `medium_gapseq_csv` column. Also tightened `medium_carveme`'s validation to reject slashes, since it was always name-only.
- Stopped reading `params.*` directly inside `subworkflows/local/bacmodel_annotation`, `subworkflows/local/gapseq_workflow`, and `subworkflows/local/bacmodel_analysis` (PR review feedback from @erikrikarddaniel). `workflows/bacmodel.nf` now reads the relevant params once into an `annotation_options` map and passes it down explicitly through each subworkflow's `take:`, matching the existing `bacmodel_summary` module pattern (`val(run_macsyfinder)` etc.) instead of each subworkflow reaching into the global `params` object itself. No behavior change.

### `Added`

- Example `medium_gapseq` CSV (`assets/medium_gapseq_example.csv`) and `--carveme_mediadb` TSV (`assets/medium_carveme_mediadb_example.tsv`) templates, referenced from the usage docs, so the expected file format is a concrete file rather than only a docs code block.
- Exposed MacSyFinder's `--db-type` as the `--macsyfinder_db_type` pipeline parameter (`unordered` default, or `ordered_replicon`/`gembase`), instead of a value hardcoded in `conf/modules.config`.
- Exposed the default `gapseq doall` search step's hardcoded `-b 200 -A diamond` as `--gapseq_doall_args`, instead of a value hardcoded in `conf/modules.config`. Only applies to the simplified doall workflow; ignored once any `gapseq_find_args`/etc. custom-mode param is set.
- New `medium_carveme_tsv` samplesheet column: a per-sample custom CarveMe media database (same 4-column TSV format as `--carveme_mediadb`) that overrides the run-wide `--carveme_mediadb` for that sample only. Named `_tsv`, not `_csv` like its gapseq counterpart, because CarveMe's media database is genuinely tab-separated - a `_csv` name would have implied the wrong delimiter and file extension.
- `conf/test_bakta.config`, `conf/test_carveme.config`, `conf/test_gapseq.config`, `conf/test_gapseq_custom.config`, `conf/test_macsyfinder.config`, `conf/test_traitar.config` (PR review feedback from @erikrikarddaniel): each per-tool `tests/*.nf.test` now loads a matching `-profile test_<name>` instead of setting params inline, so every test is also directly runnable via `nextflow run . -profile docker,test_<name>`, not just through nf-test. `tests/default.nf.test` and `tests/full.nf.test` now declare their (pre-existing) `test`/`test_full` profiles explicitly too, for consistency.
- Content assertions for the output files listed in `tests/.nftignore` (PR review feedback from @erikrikarddaniel: "consider adding meaningful test assertions" for files whose md5 is unstable), across all 8 `tests/*.nf.test`: `summary/bacmodel_summary.tsv`'s exact header/row shape (derived directly from `bacmodel_summary/main.nf`'s column logic), FASTA/GFF3 format markers for Prokka/Bakta, SBML markers for CarveMe/gapseq models, and existence/non-emptiness for MEMOTE and TRAITAR outputs whose exact filenames aren't fixed by our own code.

### `Fixed`

- CarveMe gap-filling no longer defaults to `--gapfill complete`. `complete` was never a real entry in CarveMe's bundled media database (only `LB`, `LB[-O2]`, `M9`, `M9[-O2]`, `M9[glyc]`, `PHOTO` exist), so CarveMe silently printed `Medium complete not in database, ignored.` and skipped gap-filling for every sample without an explicit `medium_carveme` - the flag looked like a sensible default but was a no-op. `--gapfill` is now only passed when `medium_carveme` is actually set; corrected the same fabricated `complete`/`TSB` medium names in `docs/usage.md` and in the `medium_carveme` value shipped in `assets/samplesheet.csv` (now `LB`, so the test profile actually exercises gap-filling).
- Added `description` fields and clearer `errorMessage`s (delimiter called out explicitly for the two `_tsv`/`_csv` media columns) to all four `medium_*` properties in `assets/schema_input.json`, each linking to `docs/usage.md#metabolic-modeling-media`.
- `conf/test_full.config` pointed `input` at `.../bacmodel/samplesheet.csv`, which 404s - the file actually published on the `bacmodel` branch of `nf-core/test-datasets` is `samplesheet.tsv`. Also, `tests/full.nf.test` never actually loaded the `test_full` profile (no `profile "test_full"` line, and nf-test's global default is `profile "test"` - see `nf-test.config`), so this had gone unnoticed: the "full" test was silently running against the small local `assets/samplesheet.csv` instead of the intended full-size external dataset. Fixed both: corrected the extension, and wired `profile "test_full"` into `tests/full.nf.test`.
- The `profile "test_full"` fix above turned out to be incomplete: nf-test 0.9.3 silently drops a suite-level `profile "..."` directive for `nextflow_pipeline` tests entirely. Confirmed via `meta/nextflow.log`: every one of `tests/{bakta,carveme,gapseq,gapseq_custom,macsyfinder,traitar,full}.nf.test` actually invoked Nextflow with only nf-test.config's global default `-profile test` (plus the executor profile), never its own `test_<name>`/`test_full` profile - `AbstractTestSuite.configure()` appends the global default profile to the same list the suite-level `profile(...)` call populates, and (per Nextflow's own documented profile-merge rule - by definition order in the config file, not CLI order) `test` loses to the later-defined `test_carveme` etc. in `nextflow.config`'s `profiles {}` block on paper, yet empirically the opposite happened: the logged `-profile` string didn't contain the per-tool profile at all. Root cause not fully resolved upstream, but the effect is reproducible and severe: every one of these tests was silently running with its intended tool(s) _skipped_ instead of enabled, so their "passing" runs (before the CarveMe/gapseq-media changes above surfaced it) weren't testing what they claimed to. Worked around by inlining each `conf/test_<name>.config`'s param overrides directly into that test's `when { params {...} } }` block (test-level inline params are unaffected by this bug), so the tests are self-contained and no longer depend on the broken profile mechanism. The `profile "test_<name>"` line is kept in each file (harmless, and keeps `nextflow run . -profile test_<name>,docker` working for manual runs) with a comment explaining why it's not load-bearing for nf-test itself.
- `tests/full.nf.test`'s inline `input` override (from the fix above) initially reused `params.pipelines_testdata_base_path + 'bacmodel/samplesheet.tsv'`, copying the expression from `conf/test_full.config` - but a `.nf.test` file's `when { params {...} } }` block is evaluated by nf-test itself to build the params-overrides JSON, before Nextflow has loaded `nextflow.config`, so `params.pipelines_testdata_base_path` was actually Groovy's `null` there, producing the literal (and silently "valid-looking" until schema validation rejected it) input path `nullbacmodel/samplesheet.tsv`. Replaced with the fully-resolved literal URL.

## v1.0.0 - 2026-06-17

Initial release of nf-core/bacmodel, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- Genome annotation with Prokka or Bakta
- Macromolecular system detection with MacSyFinder (TXSS models)
- Phenotype prediction with TRAITAR
- Metabolic model reconstruction with CarveMe and gapseq
- Model quality evaluation with MEMOTE
- Per-sample growth medium specification for metabolic modeling
- Default gap-filling with complete medium for CarveMe
- Comprehensive summary table combining all analysis results

### `Fixed`

- XML filename collision between CarveMe and gapseq outputs
- Reaction counting for gapseq models now parses XML directly
- MEMOTE module whitespace alignment with nf-core remote
- Gapseq database auto-download: container options ensure writable directory for database initialization

### `Dependencies`

- Prokka 1.14.6
- Bakta 1.10.0
- MacSyFinder 2.1.6 with TXSS models 1.1.4
- TRAITAR 2.0.0
- CarveMe 1.6.6
- gapseq 2.1.0
- MEMOTE 0.17.0

### `Deprecated`
