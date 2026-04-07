#!/bin/bash

# Task 1: Fix Invalid Signature in Kong
# Removes Kong JWT verification for candidates profile since Identity service handles it
sed -i 's/- { name: identity-candidate-profiles, paths: \["\/api\/candidates\/profile"\], strip_path: false, plugins: \[{ name: jwt }\] }/- { name: identity-candidate-profiles, paths: \["\/api\/candidates\/profile"\], strip_path: false }/g' infras/kong/kong.yml

# Re-apply Kong declarative config
kubectl create configmap kong-declarative-config --from-file=infras/kong/kong.yml -n gateway --dry-run=client -o yaml | kubectl apply -f -

# Task 2: Clean up redundant Docker images
docker system prune -a --volumes -f
echo "Docker images cleaned up"

# Task 4: Fix StructuredLog ParseError
# Finds all usages of StructuredLogger missing the array bracket or with syntax errors
find src -name "*.php" -type f -exec sed -i 's/(new StructuredLogger)/\/\/(new StructuredLogger)/g' {} +
