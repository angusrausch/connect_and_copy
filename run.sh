
# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "${CYAN}Loading environment variables${NC}"
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo -e "${RED}.env file not found!${NC}"
  exit 1
fi

ABSOLUTE_FOLDER_PATH=$(readlink -f "$COPY_FOLDER")
FOLDER_NAME=$(basename "$ABSOLUTE_FOLDER_PATH")

ABSOLUTE_CONFIG_PATH=$(readlink -f "$CONFIG_FILE")
ABSOLUTE_SSH_PRIVATE_KEY_FILE="$(eval echo $SSH_PRIVATE_KEY_FILE)"

shopt -s nocasematch
if [[ "$HOST_TYPE" == "smb" ]]; then
  echo "\n${BLUE}Starting Container${NC}\n"
  docker run \
    --rm -it \
    --network bridge \
    --privileged \
    -v $ABSOLUTE_FOLDER_PATH:/tmp/copy_from/$FOLDER_NAME \
    -v $ABSOLUTE_CONFIG_PATH:/tmp/config/wg0.conf \
    -e HOST_TYPE=$HOST_TYPE \
    -e REMOTE_HOST=$REMOTE_HOST \
    -e REMOTE_SHARE=$REMOTE_SHARE \
    -e REMOTE_LOCATION=$REMOTE_LOCATION \
    -e USERNAME=$USERNAME \
    -e PASSWORD=$PASSWORD \
    connect_and_copy
elif [[ "$HOST_TYPE" == "ssh" ]]; then
  echo "$ABSOLUTE_SSH_PRIVATE_KEY_FILE"
  if [ -z "$ABSOLUTE_SSH_PRIVATE_KEY_FILE" ]; then
    echo "\n${RED}No SSH Key File specified${NC}"
    exit
  fi
  echo "\n${BLUE}Starting Container${NC}\n"
  docker run \
    --rm -it \
    --network bridge \
    --privileged \
    -v $ABSOLUTE_FOLDER_PATH:/tmp/copy_from/$FOLDER_NAME \
    -v $ABSOLUTE_CONFIG_PATH:/tmp/config/wg0.conf \
    -v $ABSOLUTE_SSH_PRIVATE_KEY_FILE:/.ssh/docker_id \
    -e HOST_TYPE=$HOST_TYPE \
    -e REMOTE_HOST=$REMOTE_HOST \
    -e REMOTE_LOCATION=$REMOTE_LOCATION \
    -e USERNAME=$USERNAME \
    connect_and_copy
fi