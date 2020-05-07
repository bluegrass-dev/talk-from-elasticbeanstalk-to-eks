#!/usr/bin/env bash

aws ecr delete-repository --repository-name "$$ECR_REPO" --force || true
aws s3api delete-objects \
    --bucket "$ARTIFACTS_BUCKET" \
    --delete "$(aws s3api list-object-versions --bucket "$ARTIFACTS_BUCKET" --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" || true 
aws s3 rb s3://"$ARTIFACTS_BUCKET" --force || true