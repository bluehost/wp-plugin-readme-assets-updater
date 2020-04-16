#!/bin/bash
set -e

# Required variables
if [[ -z "$SVN_USERNAME" ]]; then
	echo "❌ SVN_USERNAME secret is not set."
	exit 1
fi

if [[ -z "$SVN_PASSWORD" ]]; then
	echo "❌ SVN_PASSWORD secret is not set."
	exit 1
fi

# Optional custom variables
if [[ -z "$SLUG" ]]; then
	SLUG=${GITHUB_REPOSITORY#*/}
fi
echo "ℹ️ SLUG is $SLUG"

if [[ -z "$ASSETS_DIR" ]]; then
	ASSETS_DIR=".wporg"
fi
echo "ℹ️ ASSETS_DIR is $ASSETS_DIR"

if [[ -z "$README_NAME" ]]; then
	README_NAME="readme.txt"
fi
echo "ℹ️ README_NAME is $README_NAME"

SVN_URL="https://plugins.svn.wordpress.org/${SLUG}/"
SVN_DIR="/github/svn-${SLUG}"


echo "▶️ Checking out repository from wordpress.org..."

# Only need /assets and /trunk from the repo initially
# Checkout just the root level repository directories
svn checkout --depth immediates "$SVN_URL" "$SVN_DIR"
cd "$SVN_DIR"
# Pull down files in the assets and trunk directories
svn update --set-depth infinity assets
svn update --set-depth infinity trunk


echo "▶️ Looking for readme and assets file changes..."

# Readme file first
rsync -c "$GITHUB_WORKSPACE/$README_NAME" "trunk/"
echo "- Copied $README_NAME"

# Next copy the assets directory, respecting any excludes from .distignore or .gitattributes
if [[ -e "$GITHUB_WORKSPACE/.distignore" ]]; then
	echo "ℹ️ Using .distignore to check for excluded assets"

	# Use $TMP_DIR as the source of truth
	TMP_DIR=$GITHUB_WORKSPACE

	# Copy the assets directory
	rsync -rc --exclude-from="$GITHUB_WORKSPACE/.distignore" "$GITHUB_WORKSPACE/$ASSETS_DIR/" assets/ --delete --delete-excluded
else
	echo "ℹ️ Using .gitattributes to check for excluded assets"

	cd "$GITHUB_WORKSPACE"

	# "Export" a cleaned copy to a temp directory
	TMP_DIR="/github/archivetmp"
	mkdir "$TMP_DIR"

	git config --global user.email "wordpress-team@endurance.com"
	git config --global user.name "Bluehost WP Team Bot"

	# This will exclude everything in the .gitattributes file with the export-ignore flag
	git archive HEAD | tar x --directory="$TMP_DIR"

	cd "$SVN_DIR"

	# Copy the assets directory
	rsync -rc "$TMP_DIR/$ASSETS_DIR/" assets/ --delete --delete-excluded
fi
echo "- Copied assets"

# Show any changes
svn status

# Exit if there aren't any changes to deploy
if [[ -z $(svn stat) ]]; then
	echo "🛑 No changes to deploy!"
	exit 0
fi


# Check for a stable tag declaration
echo "▶️ Verifying stable tag..."
STABLE_TAG=$(grep -m 1 "^Stable tag:" "$TMP_DIR/$README_NAME" | tr -d '\r\n' | awk -F ' ' '{print $NF}')

if [[ -z "$STABLE_TAG" ]]; then
    echo "⚠ Could not get stable tag from $README_NAME";
else
	echo "ℹ️ STABLE_TAG is $STABLE_TAG"

	if [[ $STABLE_TAG != 'trunk' ]]; then
		# Check that the stable tag exists on wordpress.org
		if svn info "^/$SLUG/tags/$STABLE_TAG" > /dev/null 2>&1; then
			# If the stable tag exists, make sure to update the readme there too
			echo "✅ Tag $STABLE_TAG exists in wordpress.org repository."

			echo "▶️ Updating readme in stable tag..."
			# Pull down the files for the tag
			svn update --set-depth infinity "tags/$STABLE_TAG"

			# Copy the readme into the stable tag
			rsync -c "$TMP_DIR/$README_NAME" "tags/$STABLE_TAG/"

		else
			echo "❌ Tag $STABLE_TAG is not in the wordpress.org repository."
			exit 1
		fi
	fi
fi

# Add everything and commit to SVN
# The force flag ensures we recurse into subdirectories even if they are already added
svn add . --force > /dev/null

# SVN delete any deleted files
svn status | grep '^\!' | sed 's/! *//' | xargs -I% svn rm %@ > /dev/null

# Now show full SVN status
svn status


echo "▶️ Committing changes..."
svn commit -m "Update readme/assets from GitHub" --no-auth-cache --non-interactive  --username "$SVN_USERNAME" --password "$SVN_PASSWORD"

echo "✅ Readme/Assets deployed!"
