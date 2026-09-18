#!/bin/bash

# Function to prompt user to continue or exit
prompt_continue() {
    while true; do
        read -p "Would you like to continue? (y/n): " choice
        case $choice in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Default organization name
ORGANIZATION_NAME="lftraining-DE"

# Prompt user for inputs
echo "Prompting user for course details..."
read -p "Enter the name of the course (COURSE_NAME): " COURSE_NAME
read -p "Enter the repository to build (COURSE_REPO): " COURSE_REPO
read -p "Enter the version of the course (VERSION): " VERSION
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
echo "Syncing cm-interaction..."
mkdir -p cm-interaction/$COURSE_NAME
cd cm-interaction
echo "y" | ./sync_cm_download.sh $COURSE_NAME
cd ..

echo "cm-interaction synced."
prompt_continue

# Clone course repo inside LFCW
echo "Cloning course repository inside LFCW..."
cd LFCW
[ ! -d "$COURSE_REPO" ] && git clone git@github.com:$ORGANIZATION_NAME/$COURSE_REPO.git

echo "Course repository cloned inside LFCW."
prompt_continue

# Create RELEASE directory
echo "Creating RELEASE directory..."
mkdir -p RELEASE/$COURSE_NAME

echo "RELEASE directory created."
prompt_continue

# Create softlink for elearning
if [ "$COURSE_TYPE" == "e" ]; then
    echo "Creating softlink for elearning..."
    ln -s $COURSE_REPO $COURSE_NAME
fi

echo "Softlink created for elearning (if applicable)."
prompt_continue

cd $COURSE_NAME

# Update version number in .tex file
echo "Updating version number in .tex file..."
sed -i 's/\\newcommand{\\version}{.*}/\\newcommand{\\version}{'$VERSION'}/' ${COURSE_NAME}.tex


prompt_continue

echo "Version number updated in .tex file."
echo "Updated version line:"
grep "\\newcommand{\\version}{" ${COURSE_NAME}.tex

prompt_continue

# Commit and tag the changes
echo "Committing and tagging the changes..."
git commit -asm "Version $VERSION"
git tag $VERSION
git push
git push --tags

echo "Changes committed and tagged."
prompt_continue

# Check and update submodules
echo "Checking and updating submodules..."
git submodule update --init --recursive

echo "Submodules checked and updated."
prompt_continue

# Create BINARIES directory
echo "Creating BINARIES directory..."
mkdir -p BINARIES

echo "BINARIES directory created."
prompt_continue

# Run cmtool download
echo "Running cmtool download..."
./common/cmtool download || echo "cmtool download failed."

echo "cmtool download completed (or failed)."
prompt_continue

# Run make command based on course type
if [ "$COURSE_TYPE" == "e" ]; then
    cd ../$COURSE_REPO
    make clean
    cd ../$COURSE_NAME
    echo "Running make for elearning..."
    docker run --rm -v $(pwd):/$(basename $(pwd)) --user $(id -u):$(id -g) --workdir /$(basename $(pwd)) eeganlf/tex-build:v1.0 /bin/bash -c "make release-elearning"
else
    echo "Running make for ILT..."
    docker run --rm -v $(pwd):/$(basename $(pwd)) --user $(id -u):$(id -g) --workdir /$(basename $(pwd)) eeganlf/tex-build:v1.0 /bin/bash -c "make release-full"
fi

echo "Make command executed based on course type."
prompt_continue

# Navigate back to LFCW and run release_and_upload.sh
echo "Navigating back to LFCW and running release_and_upload.sh..."
cd ..
./release_and_upload.sh $COURSE_NAME

echo "Navigated back to LFCW and ran release_and_upload.sh."
prompt_continue

# Copy SOL and RES files
echo "Copying SOL and RES files..."
cp RELEASE/$COURSE_NAME/V$VERSION/*SOL* ../cm-interaction/$COURSE_NAME/
cp RELEASE/$COURSE_NAME/V$VERSION/*RES* ../cm-interaction/$COURSE_NAME/

echo "SOL and RES files copied."
prompt_continue

# Sync cm-interaction
echo "Syncing cm-interaction..."
cd ../cm-interaction
./sync_cm.sh $COURSE_NAME

echo "cm-interaction synced."
prompt_continue

# Reminders
if [ "$COURSE_TYPE" == "i" ]; then
   echo "Reminding user of post-script actions..."
   echo "Don’t forget to compare long outline.html with outline on wordpress site and update wordpress site if necessary, reach out to marketing for wordpress access"
   echo "Don’t forget to upload the following files found in the RELEASE/$COURSE_NAME directory: $COURSE_NAME'_'$VERSION.pdf, '$COURSE_NAME' $COURSE_NAME-COVER-FRONT_V$VERSION.pdf and $COURSE_NAME-COVER-BACK_V$VERSION.pdf pdfs to printer at https://upload.zebraprintsolutions.com/index-sales.php"
   echo "Don’t forget to update version to $VERSION in https://docs.google.com/spreadsheets/d/1zCsRyPDufgLK4ihgZ1x4iLZsjLaOZceDl1dA5hf1pqw/edit#gid=0"
   echo "Don’t forget to email instructors@lists.linuxfoundation.org with subject: Release of $COURSE_NAME version $VERSION along with the message: Hi All, It is our pleasure to announce the release of version $VERSION of $COURSE_NAME. Authors and/or maintainers may wish to comment further on this release."
else
    echo "Elearning All Done!" 
fi
