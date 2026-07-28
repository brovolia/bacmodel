# Metro map

The pipeline overview metro map is generated from `assets/metro_map.mmd`
using [nf-metro](https://github.com/pinin4fjords/nf-metro). If you add or
rename pipeline steps, update the `.mmd` source and regenerate the image:

```bash
pip install 'nf-metro>=0.7.2' cairosvg

# Static SVG
nf-metro render assets/metro_map.mmd \
  -o docs/images/nf-core-bacmodel_metro_map.svg \
  --theme light --x-spacing 60 --y-spacing 40 --no-straight-diamonds \
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

## Why no animated SVG (for now)

nf-core/rnaseq and other reference pipelines embed an _animated_ SVG in
their README (balls traveling along the lines). We are deliberately not
doing that yet: the "Metabolic Modeling" line forks three ways from
`Input Assemblies/MAGs` (Prokka, Bakta DB, and the direct-to-Gapseq
bypass), and nf-metro's animation path-builder
(`src/nf_metro/render/animate.py`, `_chain_edge_points`) fragments that
fork unevenly - 6 of the resulting ball paths trace the CarveMe route and
only 1 traces the Gapseq route, so the animation visually reads as
"everything goes to CarveMe." This reproduces even after removing the
`_metabolic_branch` hidden node, so it is a genuine nf-metro bug, not an
`assets/metro_map.mmd` modeling mistake. Revisit `--animate` (and the
`_animated.svg` README embed nf-core pipelines normally use) once that's
fixed upstream.

## Logo

`docs/images/nf-core-bacmodel_logo_light.png` (mascot + "nf-core/bacmodel"
wordmark) is used both as the top-of-README `<img>` banner and as the
embedded legend logo on the metro map itself - the same file, deliberately.

We tried splitting this into a mascot-only image for the legend (so the
diagram wouldn't repeat the README's banner), but nf-metro has no way to
show the pipeline name on the map _and_ a mascot-only logo at the same time:
checked `src/nf_metro/render/svg.py` - a standalone title text
(`%%metro title:`) and an embedded-in-legend logo are drawn by an `if`/`elif`,
never both. So the choices are: (a) a logo image with no name text, (b) name
text with no logo image, or (c) one image that bakes the name into the
picture. We want the pipeline name visible on the map itself, so it's (c),
reusing the existing banner. `nf-core-bacmodel_logo_dark.png` still has the
old auto-generated nf-core placeholder (apple-core icon) and is no longer
referenced from `README.md` (we dropped the `<picture>` dark-mode swap since
we don't have a dark-safe variant of the new banner yet).

A plain heading (e.g. "Legend") above the colored line list is likewise not
a feature nf-metro's `render/legend.py` supports today - skipped for now,
not implemented.

## Platform note

The trailing-newline `sed` invocation above uses GNU syntax. On macOS (BSD
sed) use:

```bash
sed -i '' -e '$a\' "$f"
```
