# Custom Data: build-config-schema

### course-build-config-keys

*   [2026-09-18 02:30:52]

```json
{
  "image": "Docker image to build with. Referenced as ${IMAGE} inside the two build-command keys. Falls back to an interactive prompt if undefined anywhere.",
  "ilt-build-command": "Full shell command to build an ILT course. No interactive fallback \u2014 errors out if undefined in both course and repo config.",
  "elearning-build-command": "Full shell command to build an e-learning course. Same as ilt-build-command re: no interactive fallback.",
  "precedence": "Per key, independently: <course repo root>/course-build-config.yaml > release-config.yaml (release_scripts_lf repo root).",
  "placeholder": "${IMAGE} is a literal string substituted by lftraining_release.sh before eval \u2014 not YAML interpolation (YAML has no native string interpolation; only anchors/aliases, which operate on whole nodes, not substrings).",
  "read_by": "read_config_key() function in /home/eric/lfeducation/lftraining/release_scripts_lf/lftraining_release.sh",
  "example_course_override": "/home/eric/lfeducation/lftraining/release_scripts_lf/scratch/LFD473/course-build-config.yaml"
}
```
