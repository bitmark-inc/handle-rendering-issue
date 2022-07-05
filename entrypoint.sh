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

# to send output values to the next step
OUTPUT() {
  printf '::set-output name=%s::%s\n' "${1}" "${2}"
}

# set a secret "ACTIONS_STEP_DEBUG" with the value "true" to see the debug messages
printf '::debug::incoming: %s / %s # %s\n' "${owner}" "${repo}" "${issue}"
printf '::debug::outing: %s / %s # %s\n' "${out_owner}" "${out_repo}" "TBD"

# set outputs
OUTPUT 'issue' 'TBD'
OUTPUT 'owner' "${out_owner}"
OUTPUT 'repo' "${out_repo}"
