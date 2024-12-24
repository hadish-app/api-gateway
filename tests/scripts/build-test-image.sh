#!/bin/bash

# Build the test image with a specific tag
docker build -t hadish-test-image:latest -f tests/Dockerfile .

# Save the image to a tar file for caching
docker save hadish-test-image:latest > tests/cache/test-image.tar

echo "Test image built and cached successfully!" 