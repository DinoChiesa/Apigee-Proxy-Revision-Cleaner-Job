#!/bin/bash
# Copyright 2024-2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


CURL() {
  [[ -z "${CURL_OUT}" ]] && CURL_OUT=$(mktemp /tmp/apigee-setup-script.curl.out.XXXXXX)
  [[ -f "${CURL_OUT}" ]] && rm ${CURL_OUT}
  #[[ $verbosity -gt 0 ]] && echo "curl $@"
  [[ $verbosity -gt 0 ]] && echo "curl $@"
  CURL_RC=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $TOKEN" -o "${CURL_OUT}" "$@")
  [[ $verbosity -gt 0 ]] && echo "==> ${CURL_RC}"
}

check_shell_variables() {
  local MISSING_ENV_VARS
  MISSING_ENV_VARS=()
  for var_name in "$@"; do
    if [[ -z "${!var_name}" ]]; then
      MISSING_ENV_VARS+=("$var_name")
    fi
  done

  [[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
    printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
    printf "You must set these environment variables: %s\n" "${joined%,}"
    exit 1
  }

  printf "Settings in use:\n"
  for var_name in "$@"; do
    if [[ "$var_name" == *_APIKEY || "$var_name" == *_SECRET || "$var_name" == *_CLIENT_ID ]]; then
      local value="${!var_name}"
      local dots
      dots=$(printf '%*s' "${#value}" '' | tr ' ' '.')
      printf "  %s=%s\n" "$var_name" "${value:0:4}${dots}"
    else
      printf "  %s=%s\n" "$var_name" "${!var_name}"
    fi
  done
  printf "\n"
}

check_required_commands() {
  local missing
  missing=()
  for cmd in "$@"; do
    #printf "checking %s\n" "$cmd"
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ -n "$missing" ]]; then
    printf -v joined '%s,' "${missing[@]}"
    printf "\n\nThese commands are missing; they must be available on path: %s\nExiting.\n" "${joined%,}"
    exit 1
  fi
}

apply_roles_to_sa() {
  local sa_email project ROLE AVAILABLE_ROLES
  local -a SA_REQUIRED_ROLES
  sa_email="$1"
  project="$2"
  required_rolestring="$3"
  read -r -a SA_REQUIRED_ROLES <<< "$required_rolestring"
  
  # shellcheck disable=SC2076
  AVAILABLE_ROLES=($(gcloud projects get-iam-policy "${project}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${sa_email}" |
    grep -v deleted | grep -A 1 members | grep role | sed -e 's/role: //'))

  for j in "${!SA_REQUIRED_ROLES[@]}"; do
    ROLE=${SA_REQUIRED_ROLES[j]}
    printf "    check the role %s...\n" "$ROLE"
    if ! [[ ${AVAILABLE_ROLES[*]} =~ "${ROLE}" ]]; then
      printf "Adding role %s...\n" "${ROLE}"

      echo "gcloud projects add-iam-policy-binding ${project} \
                 --condition=None \
                 --member=serviceAccount:${sa_email} \
                 --role=${ROLE}"
      if gcloud projects add-iam-policy-binding "${project}" \
        --condition=None \
        --member="serviceAccount:${sa_email}" \
        --role="${ROLE}" --quiet 2>&1; then
        printf "Success\n"
      else
        printf "\n*** FAILED\n\n"
        printf "You must manually run:\n\n"
        echo "gcloud projects add-iam-policy-binding ${project} \
                 --condition=None \
                 --member=serviceAccount:${sa_email} \
                 --role=${ROLE}"
      fi
    else
      printf "      That role is already set.\n"
    fi
  done
}

check_and_maybe_create_sa() {
  local short_service_account project sa_email rolestring
  short_service_account="$1"
  project="$2"
  rolestring="$3"
  sa_email="${short_service_account}@${project}.iam.gserviceaccount.com"
  printf "Checking for service account %s...\n" "$sa_email"
  echo "gcloud iam service-accounts describe \"$sa_email\""
  if gcloud iam service-accounts describe "$sa_email" --quiet >>/dev/null 2>&1; then
    printf "That service account exists...\n"
  else
    printf "Creating service account %s ...\n" "${short_service_account}"
    echo "gcloud iam service-accounts create \"${short_service_account}\" --project=\"${project}\""
    if gcloud iam service-accounts create "${short_service_account}" --project="${project}" --quiet; then
      if [[ -n "$rolestring" ]]; then
        printf "There can be errors if all these changes happen too quickly, so we need to sleep a bit...\n"
        sleep 12
        apply_roles_to_sa "$sa_email" "$project" "$rolestring"
      fi
    else
      printf "Failed to create the service account.\n\n"
      exit 1
    fi
  fi
}


clean_files() {
  rm -f "${example_name}/*.*~"
  rm -fr "${example_name}/bin"
  rm -fr "${example_name}/obj"
}

