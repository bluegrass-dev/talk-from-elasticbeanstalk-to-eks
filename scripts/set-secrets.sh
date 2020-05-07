#!/usr/bin/env bash

aws secretsmanager create-secret \
    --name github-token \
    --secret-string "$WORKSHOP_GITHUB_TOKEN" \
    --region "$AWS_REGION"