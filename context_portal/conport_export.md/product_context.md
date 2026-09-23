# Product Context
## Name
release_scripts_lf

## Purpose
Scripts to automate the release process for Linux Foundation training courses (LaTeX-based ILT and e-learning course repos).

## Key Scripts
{'lftraining_release.sh': 'Primary release script: clones course + support repos, resolves build image/build-command from config, updates version, commits/tags/pushes the course repo, builds inside Docker, uploads via release_and_upload.sh, syncs cm-interaction.', 'lftraining-DE_release.sh': 'Older/parallel release script; not yet migrated to the config-driven image/build-command system. Still hardcodes the stale image eeganlf/tex-build:v1.0 at lines 128 and 137.'}

## Config Files
{'release-config.yaml': '/home/eric/lfeducation/lftraining/release_scripts_lf/release-config.yaml — repo-level shared fallback defaults (image, ilt-build-command, elearning-build-command). Currently untracked in git.', 'course-build-config.yaml': 'Per-course override, expected at the root of each course repo (filename from COURSE_CONFIG_NAME in lftraining_release.sh). Overrides any subset of the same keys, resolved independently per key. As of 2026-09-17 only LFD473 has one, at scratch/LFD473/course-build-config.yaml, uncommitted.'}

