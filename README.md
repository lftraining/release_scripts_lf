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

## Building from a tag or branch

By default the script builds the course repo's default branch. To release from a specific tag or
branch instead (e.g. a snapshot an author tagged), enter it at the `COURSE_REF` prompt; the repo is
then cloned with `git clone -b <ref>` and its submodules are checked out exactly as pinned there.

An older ref may predate the course's `course-build-config.yaml`, or need a different one than what
is committed on the default branch. In that case the script then asks for the path to a config file
to use **instead of** the one in the repo. Configs written for this purpose are kept in
[`course-configs/`](course-configs/), named `<course>-<ref>.yaml` (e.g.
[`LFD450-v6.4-u3.yaml`](course-configs/LFD450-v6.4-u3.yaml)). For such a ref, set
`build-system-submodule` and `build-system-version` to what that ref actually pins — a SHA works for
an untagged build-system commit — so the build-system check confirms the author's pin rather than
moving it.

Notes on a tag/branch build:

- For ILT releases, only the **GitHub tag** gets an `r` prefix: entering version `6.4-u3` tags the
  release `r6.4-u3`, while `\version` in the `.tex`, the PDF titles, the `RELEASE/` and Drive
  folder names, the spreadsheet and the announcement all use the plain `6.4-u3`.
- The release tag (`r<version>`) must differ from the ref (the script deletes any existing tag
  named like the release tag, so it refuses to run if they match).
- A tag clone is a detached HEAD, so the script pushes only the new release tag. If the `.tex`
  already carries the version (the usual case for an author's tag), no commit is made and the tag
  lands on the author's commit; otherwise it also uploads the one-line version commit it points at.
  The branch and the author's original tag are left untouched.
- `cmtool` is found at `common/cmtool`, falling back to `common/UTILS/cmtool` for older build systems.
