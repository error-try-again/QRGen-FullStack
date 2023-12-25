#!/usr/bin/env bash

#######################################
# Dynamic Dockerfile generation - Express
# Provides submodule implementation for the backend
# Spins up server using ts-node and the specified port at runtime
# Globals:
#   BACKEND_DOCKERFILE
#   BACKEND_PORT
#   NODE_VERSION
#   RELEASE_BRANCH
# Arguments:
#  None
#######################################
configure_backend_docker() {
    local backend_submodule_url="https://github.com/error-try-again/QRGen-backend.git"

    local origin="origin"/"$RELEASE_BRANCH"

    cat << EOF > "$BACKEND_DOCKERFILE"
# Use the specified version of Node.js
FROM node:$NODE_VERSION

# Set the default working directory
WORKDIR /usr/app

# Initialize the Git repository
RUN git init

# Add or update the backend submodule
RUN git submodule add --force "$backend_submodule_url" backend \
    && git submodule update --init --recursive

# Checkout the specific branch for each submodule
RUN cd backend \
    && git fetch --all \
    && git reset --hard "$origin" \
    && git checkout "$RELEASE_BRANCH" \
    && npm install \
    && cd ..

# Copies over the user configured environment variables
COPY backend/.env /usr/app/.env

# Set the backend express port
EXPOSE $BACKEND_PORT

# Use ts-node to run the TypeScript server file from the correct directory
CMD ["npx", "ts-node", "/usr/app/backend/src/server.ts"]

EOF
    cat "$BACKEND_DOCKERFILE"
}
