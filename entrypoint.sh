#!/bin/sh -l

local issue owner repo GITHUB_TOKEN
local out_owner out_repo OUT_GITHUB_TOKEN

issue="${1}" ; shift
owner="${1}" ; shift
repo="${1}" ; shift
GITHUB_TOKEN="${1}" ; shift
out_owner="${1}" ; shift
out_repo="${1}" ; shift
OUT_GITHUB_TOKEN="${1}" ; shift

printf 'incoming: %s / %s # %s\n' "${owner}" "${repo}" "${issue}"
printf 'outing: %s / %s # %s\n' "${out_owner}" "${out_repo}" "TBD"


printf '::set-output name=%s::%s\n' 'issue' 'TBD'
printf '::set-output name=%s::%s\n' 'owner' "${out_owner}"
printf '::set-output name=%s::%s\n' 'repo' "${out_repo}"
