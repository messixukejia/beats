#!/usr/bin/env bash

source .buildkite/scripts/common.sh

set -euo pipefail

pipelineName="pipeline.xpack-heartbeat-dynamic.yml"

echo "Add the mandatory and extended tests without additional conditions into the pipeline"
if are_conditions_met_mandatory_tests; then
  cat > $pipelineName <<- YAML
steps:
  - group: "Mandatory Tests"
    key: "mandatory-tests"
    steps:
      - label: ":linux: Ubuntu Unit Tests"
        key: "mandatory-linux-unit-test"
        command: "cd $BEATS_PROJECT_NAME && mage build unitTest"
        agents:
          provider: "gcp"
          image: "${IMAGE_UBUNTU_X86_64}"
          machineType: "${GCP_DEFAULT_MACHINE_TYPE}"
        artifact_paths:
          - "$BEATS_PROJECT_NAME/build/*.xml"
          - "$BEATS_PROJECT_NAME/build/*.json"
        notify:
          - github_commit_status:
              context: "$BEATS_PROJECT_NAME: Ubuntu Unit Tests"

      - label: ":go: Go Integration Tests"
        key: "mandatory-int-test"
        command: "cd $BEATS_PROJECT_NAME && mage goIntegTest"
        agents:
          provider: "gcp"
          image: "${IMAGE_UBUNTU_X86_64}"
          machineType: "${GCP_HI_PERF_MACHINE_TYPE}"
        artifact_paths:
          - "$BEATS_PROJECT_NAME/build/*.xml"
          - "$BEATS_PROJECT_NAME/build/*.json"
        notify:
          - github_commit_status:
              context: "$BEATS_PROJECT_NAME: Go Integration Tests"

  ####### skip: "see elastic/beats#23957 and elastic/beats#23958"
  #     - label: ":windows: Windows 2016 Unit Tests"
  #       command: |
  #         Set-Location -Path $BEATS_PROJECT_NAME
  #         mage build unitTest
  #       key: "mandatory-win-2016-unit-tests"
  #       agents:
  #         provider: "gcp"
  #         image: "${IMAGE_WIN_2016}"
  #         machine_type: "${GCP_WIN_MACHINE_TYPE}"
  #         disk_size: 100
  #         disk_type: "pd-ssd"
  #       artifact_paths:
  #         - "$BEATS_PROJECT_NAME/build/*.xml"
  #         - "$BEATS_PROJECT_NAME/build/*.json"
  #       notify:
  #         - github_commit_status:
  #             context: "$BEATS_PROJECT_NAME: Windows 2016 Unit Tests"

  #     - label: ":windows: Windows 2022 Unit Tests"
  #       command: |
  #         Set-Location -Path $BEATS_PROJECT_NAME
  #         mage build unitTest
  #       key: "mandatory-win-2022-unit-tests"
  #       agents:
  #         provider: "gcp"
  #         image: "${IMAGE_WIN_2022}"
  #         machine_type: "${GCP_WIN_MACHINE_TYPE}"
  #         disk_size: 100
  #         disk_type: "pd-ssd"
  #       artifact_paths:
  #         - "$BEATS_PROJECT_NAME/build/*.xml"
  #         - "$BEATS_PROJECT_NAME/build/*.json"
  #       notify:
  #         - github_commit_status:
  #             context: "$BEATS_PROJECT_NAME: Windows 2022 Unit Tests"

  # - group: "Extended Windows Tests" ## TODO: this condition will be changed in the Phase 3
  #   key: "extended-win-tests"
  #   steps:
  #     - label: ":windows: Windows 10 Unit Tests"
  #       command: |
  #         Set-Location -Path $BEATS_PROJECT_NAME
  #         mage build unitTest
  #       key: "extended-win-10-unit-tests"
  #       agents:
  #         provider: "gcp"
  #         image: "${IMAGE_WIN_10}"
  #         machineType: "${GCP_WIN_MACHINE_TYPE}"
  #         disk_size: 100
  #         disk_type: "pd-ssd"
  #       artifact_paths:
  #         - "$BEATS_PROJECT_NAME/build/*.xml"
  #         - "$BEATS_PROJECT_NAME/build/*.json"
  #       notify:
  #         - github_commit_status:
  #             context: "$BEATS_PROJECT_NAME: Windows 10 Unit Tests"

  #     - label: ":windows: Windows 11 Unit Tests"
  #       command: |
  #         Set-Location -Path $BEATS_PROJECT_NAME
  #         mage build unitTest
  #       key: "extended-win-11-unit-tests"
  #       agents:
  #         provider: "gcp"
  #         image: "${IMAGE_WIN_11}"
  #         machineType: "${GCP_WIN_MACHINE_TYPE}"
  #         disk_size: 100
  #         disk_type: "pd-ssd"
  #       artifact_paths:
  #         - "$BEATS_PROJECT_NAME/build/*.xml"
  #         - "$BEATS_PROJECT_NAME/build/*.json"
  #       notify:
  #         - github_commit_status:
  #             context: "$BEATS_PROJECT_NAME: Windows 11 Unit Tests"

  #     - label: ":windows: Windows 2019 Unit Tests"
  #       command: |
  #         Set-Location -Path $BEATS_PROJECT_NAME
  #         mage build unitTest
  #       key: "extended-win-2019-unit-tests"
  #       agents:
  #         provider: "gcp"
  #         image: "${IMAGE_WIN_2019}"
  #         machineType: "${GCP_WIN_MACHINE_TYPE}"
  #         disk_size: 100
  #         disk_type: "pd-ssd"
  #       artifact_paths:
  #         - "$BEATS_PROJECT_NAME/build/*.xml"
  #         - "$BEATS_PROJECT_NAME/build/*.json"
  #       notify:
  #         - github_commit_status:
  #             context: "$BEATS_PROJECT_NAME: Windows 2019 Unit Tests"
  ####### skip: "see elastic/beats#23957 and elastic/beats#23958"

YAML
else
  echo "The conditions don't match to requirements for generating pipeline steps."
  exit 0
fi

if are_conditions_met_macos_tests; then
  cat >> $pipelineName <<- YAML
  - group: "Extended Tests"
    key: "extended-tests"
    steps:
      - label: ":mac: MacOS Unit Tests"
        key: "extended-macos-unit-tests"
        command: ".buildkite/scripts/unit_tests.sh"
        agents:
          provider: "orka"
          imagePrefix: "${IMAGE_MACOS_X86_64}"
        artifact_paths:
          - "$BEATS_PROJECT_NAME/build/*.xml"
          - "$BEATS_PROJECT_NAME/build/*.json"
        notify:
          - github_commit_status:
              context: "$BEATS_PROJECT_NAME: MacOS Unit Tests"

YAML
fi

echo "Check and add the Packaging into the pipeline"
if are_conditions_met_packaging; then
  cat >> $pipelineName <<- YAML
  - wait: ~
    depends_on:
      - step: "mandatory-tests"
        allow_failure: false

  - group: "Packaging"    # TODO: check conditions for future the main pipeline migration: https://github.com/elastic/beats/pull/28589
    key: "packaging"
    steps:
      - label: ":linux: Packaging Linux"
        key: "packaging-linux"
        command: "cd $BEATS_PROJECT_NAME && mage package"
        agents:
          provider: "gcp"
          image: "${IMAGE_UBUNTU_X86_64}"
          machineType: "${GCP_HI_PERF_MACHINE_TYPE}"
          disk_size: 100
          disk_type: "pd-ssd"
        env:
          PLATFORMS: "${PACKAGING_PLATFORMS}"
        notify:
          - github_commit_status:
              context: "$BEATS_PROJECT_NAME: Packaging Linux"

      - label: ":linux: Packaging ARM"
        key: "packaging-arm"
        command: "cd $BEATS_PROJECT_NAME && mage package"
        agents:
          provider: "aws"
          imagePrefix: "${IMAGE_UBUNTU_ARM_64}"
          instanceType: "${AWS_ARM_INSTANCE_TYPE}"
        env:
          PLATFORMS: "${PACKAGING_ARM_PLATFORMS}"
          PACKAGES: "docker"
        notify:
          - github_commit_status:
              context: "$BEATS_PROJECT_NAME: Packaging Linux ARM"

YAML
fi

echo "+++ Printing dynamic steps"
yq . -P -e $pipelineName || (echo "Yaml formatting error, below is the YAML"; cat $pipelineName; exit 1)

echo "--- Loading dynamic steps"
buildkite-agent pipeline upload $pipelineName