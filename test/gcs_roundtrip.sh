#!/usr/bin/env bash
# Prove the Worklytics GCP identity can read objects in the import bucket.
# The caller (CI agent) writes a test object, then the tenant SA reads it.
#
# Usage:
#   ./test/gcs_roundtrip.sh <tenant_sa_email> <bucket_name>
#
# Prerequisites:
#   - gcloud / gsutil authenticated as an identity that can write to the bucket
#     and impersonate tenant_sa_email
set -euo pipefail

TENANT_SA_EMAIL="${1:?tenant SA email required}"
BUCKET_NAME="${2:?bucket name required}"

CI_RUN="${CI_RUN:-$(date +%Y%m%dT%H%M%S)}"
OBJECT_PATH="ci/${CI_RUN}/test.txt"
OBJECT_URI="gs://${BUCKET_NAME}/${OBJECT_PATH}"
BODY="worklytics-import-ci ${CI_RUN}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "TENANT_SA_EMAIL: ${TENANT_SA_EMAIL}"
echo "BUCKET_NAME: ${BUCKET_NAME}"
echo "OBJECT: ${OBJECT_URI}"

printf '%s' "${BODY}" > "${TMP_DIR}/test.txt"

retry() {
  local attempt=1
  local max_attempts=12
  local delay=10
  local stdout_file stderr_file
  stdout_file="$(mktemp "${TMP_DIR}/retry-out.XXXXXX")"
  stderr_file="$(mktemp "${TMP_DIR}/retry-err.XXXXXX")"
  while (( attempt <= max_attempts )); do
    # Do not merge stderr into the captured body: gsutil prints an
    # impersonation WARNING on stdout-adjacent stderr that is not object data.
    if "$@" >"${stdout_file}" 2>"${stderr_file}"; then
      cat "${stderr_file}" >&2
      cat "${stdout_file}"
      return 0
    fi
    echo "Attempt ${attempt}/${max_attempts} failed: $(cat "${stderr_file}" "${stdout_file}")" >&2
    sleep "${delay}"
    delay=$(( delay < 40 ? delay * 2 : 40 ))
    attempt=$(( attempt + 1 ))
  done
  echo "Giving up after ${max_attempts} attempts." >&2
  return 1
}

echo "Writing test object as CI identity..."
gsutil cp "${TMP_DIR}/test.txt" "${OBJECT_URI}"

echo "Reading test object as Worklytics tenant SA..."
DOWNLOADED="$(retry gsutil --impersonate-service-account="${TENANT_SA_EMAIL}" cat "${OBJECT_URI}")"

if [[ "${DOWNLOADED}" != "${BODY}" ]]; then
  echo "Object content mismatch." >&2
  echo "expected: ${BODY}" >&2
  echo "actual:   ${DOWNLOADED}" >&2
  exit 1
fi

echo "Read round-trip succeeded."
gsutil rm "${OBJECT_URI}" || true
