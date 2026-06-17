# nf-core/bacmodel: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### `Dependencies`

- Prokka 1.14.6
- Bakta 1.10.0
- MacSyFinder 2.1.6 with TXSS models 1.1.4
- TRAITAR 2.0.0
- CarveMe 1.6.6
- gapseq 2.1.0
- MEMOTE 0.17.0

### `Deprecated`
