#!/bin/bash
# 将本地两个提交（ci：添加 GitHub Actions 工作流 和 ci：trigger build on main branch pushes）推送到远程仓库
set -e

git push origin main
git push --tags
