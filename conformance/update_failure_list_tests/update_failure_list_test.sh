#!/bin/bash
#

# Checks for expected behavior of update_failure_list.py

# Files for adding tests to a need-to-update list should end in "_add.txt"
# Files for removing tests from a need-to-update list should end in "_remove.txt"
# Files for updating a need-to-update list should end in "_update.txt"
# Files for comparing the updated list should end in "_golden.txt"

readonly txt_file_dir="${TEST_SRCDIR}/google3/third_party/protobuf/conformance/update_failure_list_tests"
readonly copy_to_update_file_dir="${TEST_UNDECLARED_OUTPUTS_DIR}"

copy_and_permission() {
  local TO_UPDATE="${1}"
  local TO_COPY="${2}"
  # Copy the to-update file 
  cp "${TO_UPDATE}" \
    "${TO_COPY}"

  # Give permission to modify it
  chmod u+w "${copy_to_update_file_dir}/${TO_UPDATE_NAME}"
}

compare() {
  local GOLDEN="${1}"
  local UPDATED="${2}"

  cmp "${GOLDEN}" "${UPDATED}"
  
  # Compare the to-update file with its golden file for content equality
  if cmp -s "${GOLDEN}" \
    "${UPDATED}"; then
    echo "PASS"
  else
    die "FAILED"
  fi
}

test_fixture() {
  local ACTION="${2}"
  local ADD="${txt_file_dir}/${1}_add.txt"
  local REMOVE="${txt_file_dir}/${1}_remove.txt"
  local TO_UPDATE="${txt_file_dir}/${1}_update.txt"
  local GOLDEN="${txt_file_dir}/${1}_golden.txt"
  local TO_UPDATE_NAME="${1}_update.txt"
  local COPY="${copy_to_update_file_dir}/${TO_UPDATE_NAME}"
  local ACTION_COMMAND=

  if [[ "${ACTION}" == "add" ]]; then
    ACTION_COMMAND="--add ${ADD}"
  elif [[ "${ACTION}" == "remove" ]]; then
    ACTION_COMMAND="--remove ${REMOVE}"
  elif [[ "${ACTION}" == "add_and_remove" ]]; then
    ACTION_COMMAND="--add ${ADD} --remove ${REMOVE}"
  else
    die "FAILED: Invalid action: ${ACTION}"
  fi

  copy_and_permission "${TO_UPDATE}" "${COPY}"

  # Run update_failure_list.py script
  "${TEST_SRCDIR}/google3/third_party/protobuf/conformance/update_failure_list" \
    ${ACTION_COMMAND} \
    "${COPY}"

  compare "${GOLDEN}" "${COPY}"
}

# If a test name contains failure messages, the tests here will indirectly
# test their alignment.

# All golden failure lists should have a newline at the end. This behavior is 
# also indirectly tested in every test. 

# Adds one test and removes one test simultaneously.
test_fixture "add_remove_simult" "add_and_remove"

# Tests alphabetization of added tests to an already alphabetized one.
test_fixture "alphabetized" "add"

# Tests removing from the middle of a failure list.
test_fixture "from_middle" "remove"

