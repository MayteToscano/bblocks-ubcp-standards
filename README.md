# UBCP Building Blocks — standards mapped as blocks (v2)

**Goal:** make the **standard-to-attribute mapping explicit in code**.

Structure:
- `ogc.ubcp.std.*` : **one bblock per standard** containing the *UBCP canonical attributes* mapped to that standard.
- `ogc.ubcp.core` + `ogc.ubcp.extension.*` : UBCP modules that use `$ref` to the standard blocks.

## Build locally
```bash
docker run --pull=always --rm --workdir /workspace \
  -v "$(pwd):/workspace" \
  ghcr.io/opengeospatial/bblocks-postprocess \
  --clean true
```
