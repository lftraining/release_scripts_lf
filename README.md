# release_scripts_lf
Scripts to automate the release process for Linux Foundation courses

Pre-requisites
Docker must be installed and you must be on Ubuntu 22.04 or later (others may work but no guarantees, also some have run into issues with apparmour/SELinux.
To release a course you must have setup rclone with google drive and you must be added to the cm server. 

Adding user to cm server documentation can be found here - https://confluence.linuxfoundation.org/display/TC/Adding+to+and+Removing+a+User+from+CM+Server

## Build configuration

`lftraining_release.sh` builds each course in a Docker container, using a build command read from
config — never hardcoded in the script. Two files can supply it:

1. `course-build-config.yaml` at the root of the course repo being released (must be committed to
   that repo — the checkout is deleted and re-cloned on every run)
2. `release-config.yaml` at the root of this repo — the fallback default for every course

Each key below is resolved independently with that same priority, so a course can override just
one key and still inherit everything else from `release-config.yaml`.

**Keys:**

- `image` — the Docker image to build with. After cloning the course repo, the script always
  prompts you with whichever value it resolved as the default — press Enter to accept it, or type
  a different image to use just for this run.
- `ilt-build-command` — the full shell command used to build an ILT course.
- `elearning-build-command` — the full shell command used to build an e-learning course.

A build command can reference the resolved image with the literal placeholder `${IMAGE}`, which
the script substitutes before running the command. This is not YAML syntax — it's plain text the
release script replaces — so `${IMAGE}` must appear exactly as written, and it only works inside
these two command keys, not anywhere else in the file.

To change the default image or build commands for every course, edit
[`release-config.yaml`](release-config.yaml). To override one for a specific course, commit a
`course-build-config.yaml` in that course's repo root. For example, LFD473 builds with extra
parallelism and only needs to override the ILT command:

```yaml
ilt-build-command: >
  docker run --rm -v $(pwd):/$(basename $(pwd)) --user $(id -u):$(id -g)
  --workdir /$(basename $(pwd)) ${IMAGE} /bin/bash -c "make release -j 10"
```

If neither file has an `image:` value, the script tells you so and requires you to type an image
before continuing — it will not guess. If neither file has the build-command key for the course
type being released, the script errors out and tells you which two files it checked and which key
to add — a full build command is too easy to mistype to prompt for interactively.
