# System Patterns

---
## per-key course-config-over-repo-config precedence
*   [2026-09-18 02:30:51]
Each build-config key (image, ilt-build-command, elearning-build-command) is resolved independently: try <course repo root>/course-build-config.yaml first via read_config_key(file, key), then fall back to /home/eric/lfeducation/lftraining/release_scripts_lf/release-config.yaml. A course can override just one key and inherit the rest from the repo-level default. Implemented via the shared read_config_key() bash function in lftraining_release.sh, which shells out to `python3 -c 'import yaml; ...'` (PyYAML safe_load) and returns non-zero on a missing file, missing key, blank/non-string value, or malformed YAML.
