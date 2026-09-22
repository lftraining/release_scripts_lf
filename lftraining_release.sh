#!/bin/bash
# mkdir --parents ../RELEASE/$COURSE_NAME/outlines/; mv $COURSE_NAME_$(git describe --tags --abbrev=0.txt) $_

# Resolve the directory this script lives in *before* anything cd's around,
# so release-config.yaml can always be found regardless of cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CONFIG="$SCRIPT_DIR/release-config.yaml"
COURSE_CONFIG_NAME="course-build-config.yaml"
BUILD_IMAGE=""          # set interactively after the course repo is cloned
BUILD_IMAGE_SOURCE=""   # human-readable source, for logging

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

# Resolve the default build image: course repo's course-build-config.yaml > this repo's release-config.yaml.
# The user is always prompted; hitting Enter accepts whichever default was found (if any).
COURSE_CONFIG="$LFCW_DIR/$COURSE_REPO/$COURSE_CONFIG_NAME"

DEFAULT_IMAGE=""
DEFAULT_SOURCE=""
if DEFAULT_IMAGE="$(read_config_key "$COURSE_CONFIG" image)"; then
    DEFAULT_SOURCE="$COURSE_CONFIG"
elif DEFAULT_IMAGE="$(read_config_key "$REPO_CONFIG" image)"; then
    DEFAULT_SOURCE="$REPO_CONFIG"
fi

if [ -n "$DEFAULT_IMAGE" ]; then
    read -p "Enter the Docker image to build with [Enter for default: $DEFAULT_IMAGE, from $DEFAULT_SOURCE]: " BUILD_IMAGE
    if [ -z "$BUILD_IMAGE" ]; then
        BUILD_IMAGE="$DEFAULT_IMAGE"
        BUILD_IMAGE_SOURCE="$DEFAULT_SOURCE"
    else
        BUILD_IMAGE_SOURCE="user input"
    fi
else
    echo "No default build image found."
    echo "  Checked course repo config: $COURSE_CONFIG"
    echo "  Checked this repo's config: $REPO_CONFIG"
    echo ""
    echo "You must either enter an image below, or cancel now (Ctrl+C) and create one of:"
    echo "  - $COURSE_CONFIG"
    echo "  - $REPO_CONFIG"
    echo "  each with contents:  image: <your-image>:<tag>"
    echo ""
    while [ -z "$BUILD_IMAGE" ]; do
        read -p "Enter the Docker image to build with (required — no default available): " BUILD_IMAGE
        [ -z "$BUILD_IMAGE" ] && echo "An image is required since no config default was found."
    done
    BUILD_IMAGE_SOURCE="user input"
fi

echo "Build image: $BUILD_IMAGE  (source: $BUILD_IMAGE_SOURCE)"

# Resolve the build command: course repo's course-build-config.yaml > this repo's release-config.yaml.
# Which key to look for depends on course type, matching the elearning/ILT split further below.
if [ "$COURSE_TYPE" == "e" ]; then
    BUILD_CMD_KEY="elearning-build-command"
else
    BUILD_CMD_KEY="ilt-build-command"
fi

BUILD_CMD=""
BUILD_CMD_SOURCE=""
if BUILD_CMD="$(read_config_key "$COURSE_CONFIG" "$BUILD_CMD_KEY")"; then
    BUILD_CMD_SOURCE="$COURSE_CONFIG"
elif BUILD_CMD="$(read_config_key "$REPO_CONFIG" "$BUILD_CMD_KEY")"; then
    BUILD_CMD_SOURCE="$REPO_CONFIG"
else
    echo "ERROR: no '$BUILD_CMD_KEY' found in either config file:" >&2
    echo "  Checked course repo config: $COURSE_CONFIG" >&2
    echo "  Checked this repo's config: $REPO_CONFIG" >&2
    echo "Add a '$BUILD_CMD_KEY: <command>' entry to one of the above and re-run." >&2
    exit 1
fi

# Substitute the resolved image into the build command (supports the literal placeholder ${IMAGE}).
BUILD_CMD="${BUILD_CMD//'${IMAGE}'/$BUILD_IMAGE}"

echo "Build command: $BUILD_CMD  (source: $BUILD_CMD_SOURCE)"

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
prompt_continue

# Commit and tag the changes
echo "Committing and tagging the changes..."
git commit -asm "Version $VERSION"
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
