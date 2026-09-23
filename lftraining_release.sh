#!/bin/bash
# mkdir --parents ../RELEASE/$COURSE_NAME/outlines/; mv $COURSE_NAME_$(git describe --tags --abbrev=0.txt) $_

# Resolve the directory this script lives in *before* anything cd's around,
# so release-config.yaml can always be found regardless of cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CONFIG="$SCRIPT_DIR/release-config.yaml"
COURSE_CONFIG_NAME="course-build-config.yaml"
BUILD_IMAGE=""          # set interactively after the course repo is cloned

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required (used to parse YAML config files)." >&2; exit 1; }
python3 -c 'import yaml' 2>/dev/null || { echo "ERROR: python3 PyYAML is required to parse YAML config files (pip install pyyaml)." >&2; exit 1; }

# Danger mode: when set to 1, prompt_continue skips all prompts and the script runs to completion
DANGER_MODE=0

# Function to prompt user to continue or exit
prompt_continue() {
    # In danger mode, skip all prompts and continue automatically
    [ "$DANGER_MODE" = "1" ] && return
    while true; do
        read -p "Would you like to continue? (y/n, or d = danger: run to completion with no more prompts): " choice
        case $choice in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            [Dd]* ) DANGER_MODE=1; echo "DANGER MODE ENABLED — running to completion with no further prompts."; break;;
            * ) echo "Please answer y, n, or d.";;
        esac
    done
}

# Print the value of $2 from the YAML file $1; return non-zero if absent/unreadable.
read_config_key() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    python3 -c '
import sys, yaml
try:
    data = yaml.safe_load(open(sys.argv[1])) or {}
except Exception:
    sys.exit(1)
v = data.get(sys.argv[2])
if isinstance(v, str) and v.strip():
    print(v.strip())
else:
    sys.exit(1)
' "$file" "$key" 2>/dev/null
}

# Default organization name
ORGANIZATION_NAME="lftraining"

# Prompt user for inputs
echo "Prompting user for course details..."
read -p "Enter the name of the course (COURSE_NAME): " COURSE_NAME
read -p "Enter the repository to build (COURSE_REPO): " COURSE_REPO
read -p "Enter the version of the course (ILT version should be provided by maintainer/author and should be in something like #.#.# format. Do NOT put a 'v' in front) (e-learning version is format yyyy-mm-dd) (VERSION): " VERSION
read -p "Enter 'e' for elearning or 'i' for ILT: " COURSE_TYPE

echo "User inputs received."
prompt_continue

# Create and navigate to lftraining directory
echo "Creating and navigating to lftraining directory..."
mkdir -p lftraining
cd lftraining

echo "Navigated to lftraining directory."
prompt_continue

# Clone necessary repositories if they don't exist
echo "Cloning necessary repositories..."
[ ! -d "LFCW" ] && git clone git@github.com:$ORGANIZATION_NAME/LFCW.git
cd LFCW
[ ! -d "common" ] && git clone git@github.com:$ORGANIZATION_NAME/common.git
cd ..
[ ! -d "cm-interaction" ] && git clone git@github.com:$ORGANIZATION_NAME/cm-interaction.git

echo "Repositories cloned."
prompt_continue

# Sync cm-interaction
echo "Creating local course directory for cm-interaction..."
mkdir -p cm-interaction/$COURSE_NAME
# cd cm-interaction
# echo "y" | ./sync_cm_download.sh $COURSE_NAME
# cd ..

echo "Local course directory in cm-interaction directory created."
prompt_continue

# Clone course repo inside LFCW (ephemeral: wipe any stale copy first)
echo "Cloning course repository inside LFCW..."
cd LFCW
LFCW_DIR="$(pwd)"

# Ephemeral build: remove any prior checkout so submodules are always re-fetched fresh
echo "Removing any existing course build directory for a clean checkout..."
[ -n "$COURSE_REPO" ] && rm -rf "$LFCW_DIR/$COURSE_REPO"
[ -n "$COURSE_NAME" ] && rm -rf "$LFCW_DIR/$COURSE_NAME"

# Avoid version collisions on re-runs: clear any prior RELEASE output for this version
echo "Removing any existing RELEASE output for $COURSE_NAME V$VERSION..."
[ -n "$COURSE_NAME" ] && [ -n "$VERSION" ] && rm -rf "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION"

git clone git@github.com:$ORGANIZATION_NAME/$COURSE_REPO.git

echo "Course repository cloned inside LFCW."

# Every course must ship its own course-build-config.yaml — no fallback to this
# repo's release-config.yaml. A per-course file is the only way to keep image,
# build commands, and build-system-version (checked below) consistent with each
# other for that specific course; a shared fallback let them drift silently.
COURSE_CONFIG="$LFCW_DIR/$COURSE_REPO/$COURSE_CONFIG_NAME"

if [ ! -f "$COURSE_CONFIG" ]; then
    echo "ERROR: $COURSE_CONFIG_NAME not found in course repo." >&2
    echo "  Expected: $COURSE_CONFIG" >&2
    echo "Every course must commit its own $COURSE_CONFIG_NAME at its repo root," >&2
    echo "defining: image, ilt-build-command, elearning-build-command, build-system-version." >&2
    echo "See $REPO_CONFIG for a template to copy in." >&2
    exit 1
fi

DEFAULT_IMAGE="$(read_config_key "$COURSE_CONFIG" image)" || {
    echo "ERROR: $COURSE_CONFIG_NAME is missing required key 'image'." >&2
    echo "  File: $COURSE_CONFIG" >&2
    exit 1
}

# In danger mode the default is accepted automatically, like every other
# prompt_continue in this script; otherwise the user is prompted and hitting
# Enter accepts the default.
if [ "$DANGER_MODE" = "1" ]; then
    echo "Using image: $DEFAULT_IMAGE (from $COURSE_CONFIG)"
    BUILD_IMAGE="$DEFAULT_IMAGE"
else
    read -p "Enter the Docker image to build with [Enter for default: $DEFAULT_IMAGE, from $COURSE_CONFIG]: " BUILD_IMAGE
    [ -z "$BUILD_IMAGE" ] && BUILD_IMAGE="$DEFAULT_IMAGE"
fi

echo "Build image: $BUILD_IMAGE"

# Resolve the build command from the course's own config. Which key to look for
# depends on course type, matching the elearning/ILT split further below.
if [ "$COURSE_TYPE" == "e" ]; then
    BUILD_CMD_KEY="elearning-build-command"
else
    BUILD_CMD_KEY="ilt-build-command"
fi

BUILD_CMD="$(read_config_key "$COURSE_CONFIG" "$BUILD_CMD_KEY")" || {
    echo "ERROR: $COURSE_CONFIG_NAME is missing required key '$BUILD_CMD_KEY'." >&2
    echo "  File: $COURSE_CONFIG" >&2
    exit 1
}

# Substitute the resolved image into the build command (supports the literal placeholder ${IMAGE}).
BUILD_CMD="${BUILD_CMD//'${IMAGE}'/$BUILD_IMAGE}"

echo "Build command: $BUILD_CMD"

# Version of the common build system this course is pinned to (a tag in the
# build-system submodule, checked out below once submodules are initialized).
BUILD_SYSTEM_VERSION="$(read_config_key "$COURSE_CONFIG" build-system-version)" || {
    echo "ERROR: $COURSE_CONFIG_NAME is missing required key 'build-system-version'." >&2
    echo "  File: $COURSE_CONFIG" >&2
    exit 1
}
# Path to the build-system submodule within the course repo; defaults to "common"
# (LFS307 and most courses) but some courses use a differently named submodule,
# e.g. LFD473 uses "common_LFD".
BUILD_SYSTEM_SUBMODULE="$(read_config_key "$COURSE_CONFIG" build-system-submodule)" || BUILD_SYSTEM_SUBMODULE="common"

echo "Build system: $BUILD_SYSTEM_SUBMODULE @ $BUILD_SYSTEM_VERSION"

# Fail before the commit/tag/push below if docker isn't reachable or the image cannot be obtained.
docker info >/dev/null 2>&1 || {
    echo "ERROR: cannot reach the Docker daemon. Is Docker running?" >&2
    exit 1
}
docker image inspect "$BUILD_IMAGE" >/dev/null 2>&1 || docker pull "$BUILD_IMAGE" || {
    echo "ERROR: could not pull build image '$BUILD_IMAGE'." >&2
    exit 1
}

prompt_continue

# Create RELEASE directory
echo "Creating RELEASE directory..."
mkdir -p RELEASE/$COURSE_NAME
mkdir RELEASE/BLURBS
echo "RELEASE directory created."
prompt_continue

# Elearning courses (e.g. LFS207) build directly from their ILT combo repo's
# checkout (e.g. LFS307) with COURSE=<name> passed explicitly to make — no
# symlink needed. For a non-combo course COURSE_REPO == COURSE_NAME anyway.
cd $COURSE_REPO

# Re-run safety: drop any existing tag for this version locally and on GitHub
# so the tag + push below can recreate it cleanly on the new commit.
echo "Deleting any existing '$VERSION' tag (local + remote) to avoid collisions..."
git tag -d "$VERSION" 2>/dev/null || true
git push --delete origin "$VERSION" 2>/dev/null || true

# Update version number in .tex file
echo "Updating version number in .tex file..."
sed -i 's/\\newcommand{\\version}{.*}/\\newcommand{\\version}{'$VERSION'}/' ${COURSE_NAME}.tex


prompt_continue

echo "Version number updated in .tex file."
echo "Updated version line:"
grep "\\newcommand{\\version}{" ${COURSE_NAME}.tex

prompt_continue

# Check and update submodules
echo "Checking and updating submodules..."
git submodule update --init --recursive

echo "Submodules checked and updated."

# Enforce build-system-version: pin the build-system submodule to the tag the
# course's own config declares, rather than trusting whatever commit the
# submodule happened to be pinned to. This is what catches a course silently
# drifting onto a stale build-system commit (the LFS307/build-tex2021 incident)
# instead of building against an unverified checkout.
[ -d "$BUILD_SYSTEM_SUBMODULE" ] || {
    echo "ERROR: build-system submodule '$BUILD_SYSTEM_SUBMODULE' not found in $COURSE_REPO." >&2
    echo "Checked: $(pwd)/$BUILD_SYSTEM_SUBMODULE" >&2
    exit 1
}
pushd "$BUILD_SYSTEM_SUBMODULE" >/dev/null
PINNED_COMMIT="$(git rev-parse HEAD)"
git fetch --tags >/dev/null 2>&1
if ! git checkout "$BUILD_SYSTEM_VERSION" 2>/tmp/build-system-checkout-err; then
    echo "ERROR: '$BUILD_SYSTEM_SUBMODULE' has no tag/ref '$BUILD_SYSTEM_VERSION'" >&2
    echo "(declared as build-system-version in $COURSE_CONFIG)." >&2
    cat /tmp/build-system-checkout-err >&2
    popd >/dev/null
    exit 1
fi
rm -f /tmp/build-system-checkout-err
RESOLVED_COMMIT="$(git rev-parse HEAD)"
if [ "$PINNED_COMMIT" != "$RESOLVED_COMMIT" ]; then
    echo "WARNING: $BUILD_SYSTEM_SUBMODULE was pinned to $PINNED_COMMIT, which is not" >&2
    echo "build-system-version $BUILD_SYSTEM_VERSION ($RESOLVED_COMMIT)." >&2
    echo "Building against $BUILD_SYSTEM_VERSION as declared in $COURSE_CONFIG." >&2
    echo "The course repo's committed submodule pointer is now stale — fix it in a" >&2
    echo "normal commit so this doesn't drift again (this script does not do so" >&2
    echo "automatically, to keep the version-bump commit below scoped to just the" >&2
    echo "version change)." >&2
fi
popd >/dev/null

prompt_continue

# Commit and tag the changes. Scoped to just the .tex version bump (not `-a`)
# so a build-system-version checkout above that left the submodule pointer
# changed isn't swept into this commit and pushed unintentionally.
echo "Committing and tagging the changes..."
git add "${COURSE_NAME}.tex"
git commit -m "Version $VERSION"
git tag $VERSION
git push
git push --tags

echo "Changes committed and tagged."

prompt_continue

# Create BINARIES directory
echo "Creating BINARIES directory..."
mkdir -p BINARIES

echo "BINARIES directory created."
prompt_continue

# Run cmtool download
echo "Running cmtool download..."
./common/cmtool download || echo "cmtool download failed."

echo "cmtool download completed or failed. IT IS OK TO FAIL IF THIS PARTICULAR COURSE DOES NOT HAVE RESOURCES TO DOWNLOAD."
prompt_continue

# Run the resolved build command (see BUILD_CMD resolution above)
if [ "$COURSE_TYPE" == "e" ]; then
    make clean
fi

echo "Running build command: $BUILD_CMD"
eval "$BUILD_CMD" || {
    echo "ERROR: build command failed." >&2
    exit 1
}

echo "Build command executed."
prompt_continue

# Navigate back to LFCW and run release_and_upload.sh
echo "Navigating back to LFCW and running release_and_upload.sh..."
cd ..
./release_and_upload.sh $COURSE_NAME $COURSE_REPO

echo "Navigated back to LFCW and ran release_and_upload.sh."
prompt_continue
echo "Cleaning up"
cd $COURSE_REPO
make clean
cd ..

# Copy SOL and RES files
echo "Copying SOL and RES files..."
cp RELEASE/$COURSE_NAME/V$VERSION/*SOL* ../cm-interaction/$COURSE_NAME/
cp RELEASE/$COURSE_NAME/V$VERSION/*RES* ../cm-interaction/$COURSE_NAME/

echo "SOL and RES files copied."
prompt_continue

# Sync cm-interaction
echo "Syncing cm-interaction..."
cd ../cm-interaction
chmod +x sync_cm_nodelete.sh
if [ "$DANGER_MODE" = "1" ]; then
    echo "y" | ./sync_cm_nodelete.sh $COURSE_NAME
else
    ./sync_cm_nodelete.sh $COURSE_NAME
fi

echo "cm-interaction synced."
prompt_continue

# Reminders
if [ "$COURSE_TYPE" == "i" ]; then
   echo "Reminding user of post-script actions..."
   echo "Don’t forget to compare LFCW/RELEASE/$COURSE_NAME/V$VERSION/"$COURSE_NAME"-long-outline_V"$VERSION.html  " with outline on wordpress site (https://training.linuxfoundation.org/wp-admin) and update wordpress site if necessary. Documentation for updating can be found here: https://confluence.linuxfoundation.org/display/TC/Updating+Wordpress+Site+Outline, Reach out to marketing for wordpress access if you don't have access."
   echo "Don’t forget to upload the following files found in the RELEASE/$COURSE_NAME/V$VERSION directory:" $COURSE_NAME"_"$VERSION.pdf", $COURSE_NAME-COVER-FRONT_V$VERSION.pdf and $COURSE_NAME-COVER-BACK_V$VERSION.pdf pdfs to printer at https://upload.zebraprintsolutions.com/index-sales.php"
   echo "Don’t forget to update version to $VERSION in https://docs.google.com/spreadsheets/d/1zCsRyPDufgLK4ihgZ1x4iLZsjLaOZceDl1dA5hf1pqw/edit#gid=0"
   echo "Don’t forget to email instructors@lists.linuxfoundation.org with subject: Release of $COURSE_NAME version $VERSION 
   message: Hi All, It is our pleasure to announce the release of version $VERSION of $COURSE_NAME. Authors and/or maintainers may wish to comment further on this release."
else
    echo "Elearning All Done!"
fi

# Create printer directory with the three PDFs needed for the print upload
if [ "$COURSE_TYPE" == "i" ]; then
    echo "Creating printer directory..."
    PRINTER_DIR="$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/printer"
    mkdir -p "$PRINTER_DIR"
    cp "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/${COURSE_NAME}_V${VERSION}.pdf" "$PRINTER_DIR/"
    cp "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/${COURSE_NAME}-COVER-FRONT_V${VERSION}.pdf" "$PRINTER_DIR/"
    cp "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/${COURSE_NAME}-COVER-BACK_V${VERSION}.pdf" "$PRINTER_DIR/"
    echo "Printer directory created: $PRINTER_DIR"
fi

# Ephemeral build: remove the course checkout now that the release is complete
echo "Removing ephemeral course build directory..."
[ -n "$COURSE_REPO" ] && rm -rf "$LFCW_DIR/$COURSE_REPO"
[ -n "$COURSE_NAME" ] && rm -rf "$LFCW_DIR/$COURSE_NAME"

# Print key release files with absolute paths (Ctrl/Cmd+Click to open in VSCode)
RELEASE_DIR="$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION"
echo ""
echo "==================================================================="
echo "Key release files (Ctrl+Click / Cmd+Click to open in VSCode):"
echo "$RELEASE_DIR/${COURSE_NAME}_V${VERSION}.pdf"
echo "$RELEASE_DIR/${COURSE_NAME}-long-outline_V${VERSION}.html"
echo "==================================================================="
