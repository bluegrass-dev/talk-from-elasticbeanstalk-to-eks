#!/usr/bin/env bash

if [ -z "$WORKSHOP_GITHUB_TOKEN" ]; then
    echo "Set WORKSHOP_GITHUB_TOKEN"
    exit 1
fi