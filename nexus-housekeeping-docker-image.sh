#!/bin/bash

REPO_URL="http://1.2.3.4:8081/repository/"
USERNAME="user"
PASSWORD="password"

BUCKET="dockerbucket"
KEEP_IMAGES=3



# IMAGE_DIR="nginx"
# IMAGE_NAME="nginx"
IMAGE_DIR="$1"
IMAGE_NAME="$2"
IMAGE_FULL_NAME=$IMAGE_DIR/$IMAGE_NAME
# echo "${IMAGE_FULL_NAME}"

TAGS=$(curl --silent -X GET -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u ${USERNAME}:${PASSWORD} "${REPO_URL}${BUCKET}/v2/${IMAGE_FULL_NAME}/tags/list" | jq .tags | jq -r '.[]' | sort -r)


echo "$TAGS" | awk -v img="$IMAGE_NAME" '{print img ":" $0}'

TOTAL_TAGS=$(echo "$TAGS" | wc -l)
echo "total tags = $TOTAL_TAGS"

if [[ $TOTAL_TAGS -gt $KEEP_IMAGES ]]; then
    echo "Total tags ($TOTAL_TAGS) exceed KEEP_IMAGES ($KEEP_IMAGES). Deleting older tags."

    TAGS_TO_DELETE=$(echo "$TAGS" | tail -n +$((KEEP_IMAGES + 1)))

    while IFS= read -r TAG; do
        echo "Deleting image ${IMAGE_NAME}:$TAG"
        echo "Executing curl request..."

        IMAGE_SHA=$(curl --silent -I -X GET -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u ${USERNAME}:${PASSWORD} "${REPO_URL}${BUCKET}/v2/${IMAGE_FULL_NAME}/manifests/$TAG" | grep Docker-Content-Digest | cut -d ":" -f3 | tr -d '\r')
        echo "DELETE ${TAG} ${IMAGE_SHA}";
        DEL_URL="${REPO_URL}${BUCKET}/v2/${IMAGE_FULL_NAME}/manifests/sha256:${IMAGE_SHA}"

        RET="$(curl --silent -k -X DELETE -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u ${USERNAME}:${PASSWORD} $DEL_URL)"
      #   curl -s -X DELETE -u ${USERNAME}:${PASSWORD} "${REPO_URL}${BUCKET}/v2/${IMAGE_FULL_NAME}/manifests/$TAG"
        if [[ $? -ne 0 ]]; then
            echo "Failed to delete image tag: ${IMAGE_NAME}:$TAG"
        else
            echo "Successfully deleted image tag: ${IMAGE_NAME}:$TAG"
        fi

        echo "----------------------------------------"

    done <<< "$TAGS_TO_DELETE"
else
    echo "Total tags ($TOTAL_TAGS) are within or equal to KEEP_IMAGES ($KEEP_IMAGES). No deletion needed."
fi
