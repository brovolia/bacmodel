# `nf-core/bacmodel`: Contributing Guidelines

Hi there!
Many thanks for taking an interest in improving nf-core/bacmodel.

We try to manage the required tasks for nf-core/bacmodel using GitHub issues, you probably came to this page when creating one.
Please use the pre-filled template to save time.

However, don't be put off by this template - other more general issues and suggestions are welcome!
Contributions to the code are even more welcome ;)

> [!NOTE]
> If you need help using or modifying nf-core/bacmodel then the best place to ask is on the nf-core Slack [#bacmodel](https://nfcore.slack.com/channels/bacmodel) channel ([join our Slack here](https://nf-co.re/join/slack)).

## Contribution workflow

If you'd like to write some code for nf-core/bacmodel, the standard workflow is as follows:

1. Check that there isn't already an issue about your idea in the [nf-core/bacmodel issues](https://github.com/nf-core/bacmodel/issues) to avoid duplicating work. If there isn't one already, please create one so that others know you're working on this
2. [Fork](https://help.github.com/en/github/getting-started-with-github/fork-a-repo) the [nf-core/bacmodel repository](https://github.com/nf-core/bacmodel) to your GitHub account
3. Make the necessary changes / additions within your forked repository following [Pipeline conventions](#pipeline-contribution-conventions)
4. Use `nf-core pipelines schema build` and add any new parameters to the pipeline JSON schema (requires [nf-core tools](https://github.com/nf-core/tools) >= 1.10).
5. Submit a Pull Request against the `dev` branch and wait for the code to be reviewed and merged

If you're not used to this workflow with git, you can start with some [docs from GitHub](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests) or even their [excellent `git` resources](https://try.github.io/).

## Tests

You have the option to test your changes locally by running the pipeline. For receiving warnings about process selectors and other `debug` information, it is recommended to use the debug profile. Execute all the tests with the following command:

```bash
nf-test test --profile debug,test,docker --verbose
```

When you create a pull request with changes, [GitHub Actions](https://github.com/features/actions) will run automatic tests.
Typically, pull-requests are only fully reviewed when these tests are passing, though of course we can help out before then.

There are typically two types of tests that run:

### Lint tests

`nf-core` has a [set of guidelines](https://nf-co.re/developers/guidelines) which all pipelines must adhere to.
To enforce these and ensure that all pipelines stay in sync, we have developed a helper tool which runs checks on the pipeline code. This is in the [nf-core/tools repository](https://github.com/nf-core/tools) and once installed can be run locally with the `nf-core pipelines lint <pipeline-directory>` command.

If any failures or warnings are encountered, please follow the listed URL for more documentation.

### Pipeline tests

Each `nf-core` pipeline should be set up with a minimal set of test-data.
`GitHub Actions` then runs the pipeline on this data to ensure that it exits successfully.
If there are any failures then the automated tests fail.
These tests are run both with the latest available version of `Nextflow` and also the minimum required version that is stated in the pipeline code.

## Patch

:warning: Only in the unlikely and regretful event of a release happening with a bug.

- On your own fork, make a new branch `patch` based on `upstream/main` or `upstream/master`.
- Fix the bug, and bump version (X.Y.Z+1).
- Open a pull-request from `patch` to `main`/`master` with the changes.

## Getting help

For further information/help, please consult the [nf-core/bacmodel documentation](https://nf-co.re/bacmodel/usage) and don't hesitate to get in touch on the nf-core Slack [#bacmodel](https://nfcore.slack.com/channels/bacmodel) channel ([join our Slack here](https://nf-co.re/join/slack)).

## Pipeline contribution conventions

To make the `nf-core/bacmodel` code and processing logic more understandable for new contributors and to ensure quality, we semi-standardise the way the code and other contributions are written.

### Adding a new step

If you wish to contribute a new step, please use the following coding standards:

1. Define the corresponding input channel into your new process from the expected previous process channel.
2. Write the process block (see below).
3. Define the output channel if needed (see below).
4. Add any new parameters to `nextflow.config` with a default (see below).
5. Add any new parameters to `nextflow_schema.json` with help text (via the `nf-core pipelines schema build` tool).
6. Add sanity checks and validation for all relevant parameters.
7. Perform local tests to validate that the new code works as expected.
8. If applicable, add a new test in the `tests` directory.

### Default values

Parameters should be initialised / defined with default values within the `params` scope in `nextflow.config`.

Once there, use `nf-core pipelines schema build` to add to `nextflow_schema.json`.

### Default processes resource requirements

Sensible defaults for process resource requirements (CPUs / memory / time) for a process should be defined in `conf/base.config`. These should generally be specified generic with `withLabel:` selectors so they can be shared across multiple processes/steps of the pipeline. A nf-core standard set of labels that should be followed where possible can be seen in the [nf-core pipeline template](https://github.com/nf-core/tools/blob/main/nf_core/pipeline-template/conf/base.config), which has the default process as a single core-process, and then different levels of multi-core configurations for increasingly large memory requirements defined with standardised labels.

The process resources can be passed on to the tool dynamically within the process with the `${task.cpus}` and `${task.memory}` variables in the `script:` block.

### Naming schemes

Please use the following naming schemes, to make it easy to understand what is going where.

- initial process channel: `ch_output_from_<process>`
- intermediate and terminal channels: `ch_<previousprocess>_for_<nextprocess>`

### Nextflow version bumping

If you are using a new feature from core Nextflow, you may bump the minimum required version of nextflow in the pipeline with: `nf-core pipelines bump-version --nextflow [min-nf-version]` (run from the pipeline directory, or pass `--dir`)

### Images and figures

For overview images and other documents we follow the nf-core [style guidelines and examples](https://nf-co.re/developers/design_guidelines).

#### Updating the pipeline overview (metro map)

The pipeline overview metro map is generated from `assets/metro_map.mmd`
using [nf-metro](https://github.com/pinin4fjords/nf-metro). If you add or
rename pipeline steps, update the `.mmd` source and regenerate the image:

```bash
pip install 'nf-metro>=0.7.2' cairosvg

# Static SVG
nf-metro render assets/metro_map.mmd \
  -o docs/images/nf-core-bacmodel_metro_map.svg \
  --theme light --x-spacing 60 --y-spacing 40 --diamond-style symmetric --center-ports \
  --logo docs/images/nf-core-bacmodel_logo_light.png

# nf-metro's `light` theme has a transparent background (`background_color:
# none`), so the SVG needs an explicit white background rect injected -
# otherwise the diagram is unreadable against a dark GitHub theme, dark
# slide, or any host page that isn't plain white.
python3 -c "
fname = 'docs/images/nf-core-bacmodel_metro_map.svg'
with open(fname, encoding='utf-8') as fh:
    content = fh.read()
marker = '</style>\n'
idx = content.find(marker)
insert_at = idx + len(marker)
bg_rect = '<rect x=\"0\" y=\"0\" width=\"100%\" height=\"100%\" fill=\"#ffffff\" />\n'
with open(fname, 'w', encoding='utf-8') as fh:
    fh.write(content[:insert_at] + bg_rect + content[insert_at:])
"

# PNG conversion (cairosvg) - also opaque, for contexts that don't render SVG
python -c "import cairosvg; cairosvg.svg2png(
    url='docs/images/nf-core-bacmodel_metro_map.svg',
    write_to='docs/images/nf-core-bacmodel_metro_map.png',
    output_width=2265, background_color='#ffffff')"

# Ensure trailing newline on the SVG (required by pre-commit)
sed -i -e '$a\' docs/images/nf-core-bacmodel_metro_map.svg
```

On macOS (BSD `sed`), use `sed -i '' -e '$a\' "$f"` instead for the last step.

**Why no animated SVG (for now):** nf-core/rnaseq and other reference
pipelines embed an _animated_ SVG in their README (balls traveling along
the lines). We are deliberately not doing that yet: the "Metabolic
Modeling" line forks three ways from `Input Assemblies/MAGs` (Prokka,
Bakta DB, and the direct-to-Gapseq bypass), and nf-metro's animation
path-builder (`src/nf_metro/render/animate.py`, `_chain_edge_points`)
fragments that fork unevenly - 6 of the resulting ball paths trace the
CarveMe route and only 1 traces the Gapseq route, so the animation
visually reads as "everything goes to CarveMe." This reproduces even
after removing the `_metabolic_branch` hidden node, so it is a genuine
nf-metro bug, not an `assets/metro_map.mmd` modeling mistake. Revisit
`--animate` (and the `_animated.svg` README embed nf-core pipelines
normally use) once that's fixed upstream.

**Logo:** `docs/images/nf-core-bacmodel_logo_light.png` (mascot +
"nf-core/bacmodel" wordmark) is used both as the top-of-README `<img>`
banner and as the embedded legend logo on the metro map itself - the same
file, deliberately. We tried splitting this into a mascot-only image for
the legend (so the diagram wouldn't repeat the README's banner), but
nf-metro has no way to show the pipeline name on the map _and_ a
mascot-only logo at the same time: checked `src/nf_metro/render/svg.py` -
a standalone title text (`%%metro title:`) and an embedded-in-legend logo
are drawn by an `if`/`elif`, never both. So the choices are: (a) a logo
image with no name text, (b) name text with no logo image, or (c) one
image that bakes the name into the picture. We want the pipeline name
visible on the map itself, so it's (c), reusing the existing banner.
`nf-core-bacmodel_logo_dark.png` still has the old auto-generated nf-core
placeholder (apple-core icon) and is no longer referenced from
`README.md` (we dropped the `<picture>` dark-mode swap since we don't
have a dark-safe variant of the new banner yet). A plain heading (e.g.
"Legend") above the colored line list is likewise not a feature
nf-metro's `render/legend.py` supports today - skipped for now, not
implemented.

## GitHub Codespaces

This repo includes a devcontainer configuration which will create a GitHub Codespaces for Nextflow development! This is an online developer environment that runs in your browser, complete with VSCode and a terminal.

To get started:

- Open the repo in [Codespaces](https://github.com/nf-core/bacmodel/codespaces)
- Tools installed
  - nf-core
  - Nextflow

Devcontainer specs:

- [DevContainer config](.devcontainer/devcontainer.json)
