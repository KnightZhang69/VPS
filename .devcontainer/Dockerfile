FROM node:20-bullseye

# Install system dependencies
RUN apt-get update && apt-get install -y \
  curl \
  git \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Install pnpm globally
RUN npm install -g pnpm
