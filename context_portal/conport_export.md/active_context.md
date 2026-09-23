# Active Context
## Current Focus
Made course-build-config.yaml mandatory in lftraining_release.sh (no more release-config.yaml fallback) and added build-system-version enforcement (explicit tag checkout + drift warning in the build-system submodule after `git submodule update`). Edited lftraining_release.sh, release-config.yaml (now a template, not read by the script), and README.md. NOT yet committed/pushed — pending user go-ahead. A separate, still-uncommitted local fix in the same file (gating the Docker-image prompt on DANGER_MODE) predates this and is also still pending.

## Open Issues
*   UNCOMMITTED in lftraining_release.sh: (1) DANGER_MODE gate on the image-selection prompt (asked user whether to commit, no answer yet), (2) the course-build-config.yaml-mandatory + build-system-version changes just made. Both sit in the same file and haven't been pushed.
*   Blast radius of making course-build-config.yaml mandatory: LFD254 (/home/eric/lfeducation/LFD254), LFS458 (/home/eric/lfeducation/LFS458), and LFD473 (/home/eric/lfeducation/LFD473) all currently have NO course-build-config.yaml at all (confirmed by direct check) and will fail immediately on their next release until one is committed to each course repo. LFS307 is the only course with the file today.
*   LFD473 uses a differently-named build-system submodule: common_LFD (git@github.com:lftraining/common_LFD.git), not common — this is why build-system-submodule was added as an optional config key (defaults to "common").
*   lftraining-DE_release.sh not converted — still hardcodes stale eeganlf/tex-build:v1.0 image, no config-reading plumbing. Explicitly deferred as an optional second phase.
*   LFD473's course-build-config.yaml (in the scratch/LFD473 clone) is written but uncommitted/unpushed, and would now also need build-system-submodule: common_LFD added — has no effect on real releases until pushed to git@github.com:lftraining/LFD473.git, since lftraining_release.sh wipes and re-clones its own ephemeral checkout from origin every run.
*   Three separate local clones of git@github.com:lftraining/LFD473.git exist at different commits: /home/eric/lfeducation/LFD473 (92664c3, no course-build-config.yaml), scratch/LFD473 (17d1572, has an uncommitted draft config), temp/LFD473 (627ee64). User chose scratch/LFD473 for the new config.
*   temp/ dir in release_scripts_lf is untracked and NOT in .gitignore (only scratch/ is) — contains full course checkouts (temp/LFD473, temp/LFS460) that would get swept into a `git add .`; their READMEs still reference the stale eeganlf/tex-build:v1.0 image.
*   release-config.yaml IS committed/tracked in git (confirmed via git log; the earlier note claiming it was untracked was stale/wrong) — it's now a template only, no longer read by the release script.
*   The local LFCW clone at .../release_scripts_lf/lftraining/LFCW has a large amount of pre-existing, uncommitted local state unrelated to any of this work: dozens of LFD4xx course directories (LFD401, LFD435, LFD440, LFD441, LFD445, LFD450, LFD455, LFD8440) show as locally deleted but never committed, plus an untracked common/ directory (a separate top-level clone, distinct from any course's own common submodule). Do NOT `git add -A`/`git add .` in that checkout — stage files by name only — or these deletions would be pushed to the shared LFCW remote used by every course.

## Last Updated
2026-09-21 session

