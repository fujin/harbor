#!/bin/bash

# GitHub username and repo
GITHUB_USER="fujin"
GITHUB_REPO="harbor"

# Get the current git commit SHA for tagging
COMMIT_SHA=$(git rev-parse --short HEAD)

echo "🔨 Rebuilding Harbor images with proper GitHub repository labels..."
echo "📝 Using commit SHA: ${COMMIT_SHA}"

# List of Harbor images to rebuild and push
IMAGES=(
    "goharbor/harbor-core:dev"
    "goharbor/harbor-portal:dev" 
    "goharbor/harbor-jobservice:dev"
)

for image in "${IMAGES[@]}"; do
    # Extract image name and convert to your naming pattern
    if [[ $image == goharbor/* ]]; then
        image_name=$(echo $image | sed 's/goharbor\///' | sed 's/:dev//')
    else
        # For nginx-photon, redis-photon, registry-photon - keep full name
        image_name=$(echo $image | sed 's/:dev//')
    fi
    
    # Create GHCR tag with harbor namespace
    ghcr_latest="ghcr.io/${GITHUB_USER}/${GITHUB_REPO}/${image_name}:latest"
    ghcr_tag="ghcr.io/${GITHUB_USER}/${GITHUB_REPO}/${image_name}:${COMMIT_SHA}"
    
    echo "🏗️  Processing $image_name with GitHub repository labels..."
    
    # Verify the local image exists
    if ! docker image inspect $image >/dev/null 2>&1; then
        echo "❌ Error: Local image $image not found!"
        exit 1
    fi
    
    echo "🏷️  Adding GitHub repository labels to ${image_name} via temp dockerfile..."
    
    # Create temp dockerfile with labels (using image name, not ID)
    cat > temp-${image_name}.Dockerfile << EOF
FROM $image
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
LABEL org.opencontainers.image.description="Harbor container registry - ${image_name}"  
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="${image_name}"
LABEL org.opencontainers.image.url="https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
LABEL org.opencontainers.image.vendor="Harbor"
LABEL org.opencontainers.image.version="${COMMIT_SHA}"
EOF
    
    # Build with labels, forcing local image usage
    docker build --pull=false --no-cache -f temp-${image_name}.Dockerfile -t $ghcr_latest -t $ghcr_tag .
    
    # Clean up temp file
    rm temp-${image_name}.Dockerfile
    
    # Push both tags
    echo "📤 Pushing $ghcr_latest"
    docker push $ghcr_latest
    
    echo "📤 Pushing $ghcr_tag"  
    docker push $ghcr_tag
    
    echo "✅ Completed $image_name with GitHub repository connection"
    echo ""
done

echo "🎉 All Harbor images rebuilt and pushed with GitHub repository labels!"
echo ""
echo "📋 Images available with repository connection:"
for image in "${IMAGES[@]}"; do
    if [[ $image == goharbor/* ]]; then
        image_name=$(echo $image | sed 's/goharbor\///' | sed 's/:dev//')
    else
        image_name=$(echo $image | sed 's/:dev//')
    fi
    echo "   ghcr.io/${GITHUB_USER}/${GITHUB_REPO}/${image_name}:latest"
    echo "   ghcr.io/${GITHUB_USER}/${GITHUB_REPO}/${image_name}:${COMMIT_SHA}"
done

echo ""
echo "🔗 Packages should now be automatically connected to: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo "🔗 Check packages at: https://github.com/${GITHUB_USER}?tab=packages&repo_name=${GITHUB_REPO}"
