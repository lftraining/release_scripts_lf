# release_scripts_lf
Scripts to automate the release process for Linux Foundation courses

Pre-requisites
Docker must be installed and you must be on Ubuntu 22.04 or later (others may work but no guarantees, also some have run into issues with apparmour/SELinux.
To release a course you must have setup rclone with google drive and you must be added to the cm server. 

Adding user to cm server documentation can be found here - https://confluence.linuxfoundation.org/display/TC/Adding+to+and+Removing+a+User+from+CM+Server

## Build configuration

`lftraining_release.sh` builds each course in a Docker container, using a build command read from
config — never hardcoded in the script.

**Every course must commit its own `course-build-config.yaml` at its repo root.** There is no
shared fallback: the script refuses to run if that file is missing, or if it's missing any of the
required keys below. A per-course file is the only way to keep a course's image, build commands,
and required build-system version consistent with each other; a shared fallback let those drift
silently (see `build-system-version` below).

[`release-config.yaml`](release-config.yaml) at the root of this repo is **not read by the
script** — it's a template you copy into a course repo as `course-build-config.yaml` and fill in.

**Required keys:**

- `image` — the Docker image to build with. After cloning the course repo, the script always
  prompts you with this as the default — press Enter to accept it, or type a different image to
  use just for this run.
- `ilt-build-command` — the full shell command used to build an ILT course.
- `elearning-build-command` — the full shell command used to build an e-learning course.
- `build-system-version` — the tag, in the course's build-system submodule, that this course must
  build against. After `git submodule update`, the script explicitly checks out this tag in that
  submodule and warns if it wasn't already pinned there — this is what catches a course silently
  building against a stale build-system commit instead of the one it actually declares it needs.

**Optional keys:**

- `build-system-submodule` — path to the build-system submodule within the course repo. Defaults
  to `common` if omitted; some courses use a different name, e.g. LFD473 uses `common_LFD`.

A build command can reference the resolved image with the literal placeholder `${IMAGE}`, which
the script substitutes before running the command. This is not YAML syntax — it's plain text the
release script replaces — so `${IMAGE}` must appear exactly as written, and it only works inside
the two build-command keys, not anywhere else in the file.

For example, LFS307 (a combo repo building both the LFS307 ILT course and its LFS207 e-learning
companion) passes `COURSE=` explicitly and builds with extra parallelism:

```yaml
ilt-build-command: >
  docker run --rm -v $(pwd):/$(basename $(pwd)) --user $(id -u):$(id -g)
  --workdir /$(basename $(pwd)) ${IMAGE} /bin/bash -c "make COURSE=LFS307 release -j 10"
```

If a course repo has no `course-build-config.yaml`, or is missing any required key, the script
errors out immediately and tells you exactly what's missing and where to add it — a full build
command or a submodule tag is too easy to mistype to prompt for interactively.
