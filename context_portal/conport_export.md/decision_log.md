# Decision Log

---
## Decision
*   [2026-09-22 18:45:40] Made course-build-config.yaml mandatory (no fallback to release-config.yaml); added build-system-version enforcement

## Rationale
*   User: "I really think we should just require a course to have that config file or the release just doesn't accept it." A shared release-config.yaml fallback let a course's actual build silently drift from what it needed (the LFS307/build-tex2021 incident: submodule pinned to a stale commit, nothing caught it). Requiring every course to declare image/build-commands/build-system-version itself, with no fallback, removes that drift path structurally instead of just warning about it.

## Implementation Details
*   lftraining_release.sh: course-build-config.yaml must exist in the course repo and define image, ilt-build-command/elearning-build-command (whichever applies), and build-system-version — script exits with a clear error naming the missing key otherwise. New build-system-version key names a tag in the course's build-system submodule (path configurable via optional build-system-submodule, default "common"); after `git submodule update --init --recursive`, the script explicitly checks out that tag and prints a WARNING if the submodule's prior pinned commit didn't already match, rather than silently building against whatever was checked out. The version-bump commit was changed from `git commit -asm` to a scoped `git add "${COURSE_NAME}.tex"` + `git commit -m` so an out-of-sync submodule pointer surfaced by that checkout isn't swept into the commit and pushed unintentionally — any real fix to the submodule pointer is left as a separate, deliberate human commit. release-config.yaml is no longer read by the script at all; repurposed as a copy-paste template (now also documents build-system-version/build-system-submodule). README.md rewritten to match. Verified read_config_key resolution and both the no-drift and drift-detected submodule-checkout paths against the real LFS307 checkout (scratch/LFS307), restoring it to its original clean state afterward — did not run the full script live (would push/tag/build for real).

---
## Decision
*   [2026-09-22 02:32:48] Removed the elearning symlink hack; combo-repo courses now build via explicit COURSE=<name>, no same-named directory required

## Rationale
*   lftraining_release.sh used to `ln -s $COURSE_REPO $COURSE_NAME` (e.g. LFS307 -> LFS207) so the elearning companion course in a combo repo would resolve via Makefile_oneclass's directory-name COURSE fallback. Since COURSE=<name> passed explicitly to `make` has always worked and is structurally immune to the historical appendices-hijack bug (98359a4 in lftraining/common), the symlink was unnecessary for the build step. Verified live 2026-09-21: `make release-elearning COURSE=LFS207` run directly inside the real LFS307 checkout (no symlink) produced correct RELEASE/LFS207_V2026-04-28_* output. However, release_and_upload.sh (in the separate, shared LFCW repo) also depended on a directory literally named after the course (it `pushd`s $1 and reads $1.tex), so removing the symlink required updating that script too: it now takes COURSE (course code) and COURSEDIR (directory to build from, defaults to COURSE) as separate arguments.

---
## Decision
*   [2026-09-18 02:30:47] Build-command key selection branches on COURSE_TYPE (elearning-build-command vs ilt-build-command); missing build-command errors out rather than prompting interactively

## Rationale
*   Mirrors the existing e-learning/ILT split from the old hardcoded docker-run branches. Unlike image, a missing build-command is not prompted for interactively — a full shell command is too long and error-prone to type safely at a terminal prompt — so the script exits with an error naming both config paths and the missing key.

---
## Decision
*   [2026-09-18 02:30:47] Kept both a docker info daemon check and the existing docker image inspect/pull image-availability check, before the git commit/tag/push

## Rationale
*   Considered dropping the image-availability check since docker run auto-pulls anyway, which would have been necessary if image were inlined into build-command with nothing left to inspect. Since image was kept as its own key, both checks remained cheap and valuable, so both were kept. docker info was added in front because a dead Docker daemon previously surfaced as a confusing 'could not pull image' message from docker pull.

---
## Decision
*   [2026-09-18 02:30:47] Build failures now abort lftraining_release.sh instead of silently continuing

## Rationale
*   Previously the hardcoded docker-run exit status was ignored, so a failed build still proceeded to release_and_upload.sh and uploaded a broken release. Flagged explicitly to the user as a deliberate behavior change (not purely mechanical) since the build block was being rewritten anyway; user did not object.

---
## Decision
*   [2026-09-18 02:30:47] LFD473's course-build-config.yaml pins image explicitly and defines both ilt-build-command and elearning-build-command with -j 10 parallelism

## Rationale
*   User wants the course to dictate its own image so it stays pinned even if the shared release-config.yaml default changes later, rather than relying on fallback. Both build modes use extra parallelism (-j 10) for faster builds. Written to /home/eric/lfeducation/lftraining/release_scripts_lf/scratch/LFD473/course-build-config.yaml — the most up-to-date of three local clones of the LFD473 course repo — left uncommitted/unpushed per user's explicit choice.

---
## Decision
*   [2026-09-18 02:30:35] Course build config gains ilt-build-command / elearning-build-command keys; image stays its own key, referenced via ${IMAGE} substitution rather than inlined

## Rationale
*   Courses need to fully customize their build command (e.g. LFD473 needs make release -j 10), which the old hardcoded docker-run branches in lftraining_release.sh couldn't express. Inlining the image literally into every course's build-command was considered and rejected: it would duplicate the image name across every course repo, multiplying a drift failure that already happened once — lftraining-DE_release.sh still hardcodes the stale eeganlf/tex-build:v1.0 image (TeX Live 2021), missed during the 2025 bump to eeganlf/lf-tex-full-2025:v1.0. Keeping image as its own key, with build-command referencing it via a literal ${IMAGE} placeholder substituted by the script (YAML itself has no string interpolation), keeps the image defined once per config while courses still fully control their build command.

## Implementation Details
*   lftraining_release.sh: read_config_image() generalized to read_config_key(file, key); BUILD_CMD resolved via the same course-config>repo-config precedence as BUILD_IMAGE; BUILD_CMD="${BUILD_CMD//'${IMAGE}'/$BUILD_IMAGE}" substitutes before eval.
