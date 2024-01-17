# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [0.7.1] - 2024-01-17
### Fixed
- Ensure that workflow credentials is not-nil ([#156](https://github.com/ManageIQ/floe/pull/156))

## [0.7.0] - 2023-12-18
### Changed
- Remove the dependency on more_core_extensions in ReferencePath ([#144](https://github.com/ManageIQ/floe/pull/144))

### Added
- Implement `ReferencePath#get` ([#144](https://github.com/ManageIQ/floe/pull/144))
- Allow a State to set a value in Credentials for subsequent states ([#145](https://github.com/ManageIQ/floe/pull/145))

## [0.6.1] - 2023-11-21
### Fixed
- Return an error payload if run_async! fails ([#143](https://github.com/ManageIQ/floe/pull/143))

### Changed
- Extract run_container_params for docker/podman ([#142](https://github.com/ManageIQ/floe/pull/142))

## [0.6.0] - 2023-11-09
### Added
- Prefix pod names with 'floe-' ([#132](https://github.com/ManageIQ/floe/pull/132))
- Validate that the workflow payload is correct ([#136](https://github.com/ManageIQ/floe/pull/136))

### Fixed
- Fix issue where certain docker image names cannot be pod names ([#134](https://github.com/ManageIQ/floe/pull/134))
- Fix uninitialized constant RSpec::Support::Differ in tests ([#137](https://github.com/ManageIQ/floe/pull/137))
- Handle ImagePullErr/ImagePullBackOff as errors ([#135](https://github.com/ManageIQ/floe/pull/135))

### Changed
- Add task spec helper ([#123](https://github.com/ManageIQ/floe/pull/123))
- Rename State#run_wait to just #wait ([#139](https://github.com/ManageIQ/floe/pull/139))
- Refactor the Podman runner to be a Docker subclass ([#140](https://github.com/ManageIQ/floe/pull/140))

## [0.5.0] - 2023-10-12
### Added
- For task errors, use the json on the last line ([#128](https://github.com/ManageIQ/floe/pull/128))
- Add ability to pass task service account to kube runner ([#131](https://github.com/ManageIQ/floe/pull/131))

### Fixed
- Don't put credentials file into input ([#124](https://github.com/ManageIQ/floe/pull/124))
- exe/floe return success status if the workflow was successful ([#129](https://github.com/ManageIQ/floe/pull/129))
- For error output, drop trailing newline ([#126](https://github.com/ManageIQ/floe/pull/126))

## [0.4.1] - 2023-10-06
### Added
- Add Fail#CausePath and Fail#ErrorPath ([#110](https://github.com/ManageIQ/floe/pull/110))
- Add Task#Retrier incremental backoff and Wait#Timestamp ([#100](https://github.com/ManageIQ/floe/pull/100))

### Fixed
- Combine stdout and stderr for docker and podman runners ([#104](https://github.com/ManageIQ/floe/pull/104))
- Don't raise an exception on task failure ([#115](https://github.com/ManageIQ/floe/pull/115))
- Fix task output handling ([#112](https://github.com/ManageIQ/floe/pull/112))
- Fix Context#input not JSON parsed ([#122](https://github.com/ManageIQ/floe/pull/122))

## [0.4.0] - 2023-09-26
### Added
- Add ability to run workflows asynchronously ([#52](https://github.com/ManageIQ/floe/pull/92))
- Add Workflow.wait, Workflow#step_nonblock, Workflow#step_nonblock_wait ([#92](https://github.com/ManageIQ/floe/pull/92))

## [0.3.1] - 2023-08-29
### Added
- Add more global podman runner options ([#90](https://github.com/ManageIQ/floe/pull/90))

## [0.3.0] - 2023-08-07
### Added
- Add --network=host option to Docker/Podman runners ([#81](https://github.com/ManageIQ/floe/pull/81))

### Fixed
- Fix PayloadTemplate value transformation rules ([#78](https://github.com/ManageIQ/floe/pull/78))
- Move end out of the root state node ([#80](https://github.com/ManageIQ/floe/pull/80))

## [0.2.3] - 2023-07-28
### Fixed
- Fix storing next_state in Context ([#76](https://github.com/ManageIQ/floe/pull/76))

## [0.2.2] - 2023-07-24
### Fixed
- Don't pick up real KUBECONFIG for tests ([#73](https://github.com/ManageIQ/floe/pull/73))
- Fix double json.parse and context default value ([#69](https://github.com/ManageIQ/floe/pull/69))

### Added
- Configure Renovate ([#46](https://github.com/ManageIQ/floe/pull/46))

### Changed
- Simplify next state handling ([#66](https://github.com/ManageIQ/floe/pull/66))
- Refactor Input/Output path handling ([#68](https://github.com/ManageIQ/floe/pull/68))

## [0.2.1] - 2023-07-12
### Fixed
- Fix State EnteredTime and FinishedTime ([#59](https://github.com/ManageIQ/floe/pull/59))

### Added
- Add workflow output ([#57](https://github.com/ManageIQ/floe/pull/57))

## [0.2.0] - 2023-07-05
### Added
- Add ability to pass options to `Floe::Workflow::Runner` ([#48](https://github.com/ManageIQ/floe/pull/48))
- Add kubeconfig file support to `Floe::Workflow::Runner::Kubernetes` ([#53](https://github.com/ManageIQ/floe/pull/53))

### Removed
- Remove to_dot/to_svg code ([#54](https://github.com/ManageIQ/floe/pull/54))

### Fixed
- Fixed default rake task to spec ([#55](https://github.com/ManageIQ/floe/pull/55))

## [0.1.1] - 2023-06-05
### Fixed
- Fix States::Wait Path initializer arguments ([#47](https://github.com/ManageIQ/floe/pull/47))

## [0.1.0] - 2023-03-13
### Added
- Initial release

[Unreleased]: https://github.com/ManageIQ/floe/compare/v0.7.1...HEAD
[0.7.1]: https://github.com/ManageIQ/floe/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/ManageIQ/floe/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/ManageIQ/floe/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/ManageIQ/floe/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/ManageIQ/floe/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/ManageIQ/floe/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/ManageIQ/floe/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/ManageIQ/floe/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/ManageIQ/floe/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/ManageIQ/floe/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/ManageIQ/floe/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/ManageIQ/floe/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ManageIQ/floe/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/ManageIQ/floe/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ManageIQ/floe/tree/v0.1.0
