# Changelog

All notable changes to `lua-resty-reqargs` will be documented in this file.

## [1.4] - 2015-01-07
### Fixed
- Fixed issue with no options passed as reported here:
  https://groups.google.com/forum/#!topic/openresty-en/uXRXC0NbfbI

## [1.3] - 2016-09-29
### Added
- Support for the official OpenResty package manager (opm).
- Added changelog (this file).
- A lots of new documentation.

##[1.2] - 2016-08-23
### Added
- Added max_fsize option that can be used to control how large can one uploaded file be.
- Added max_files option that can be used to control how many files can be uploaded.

### Fixed
- LuaRocks etc. was using wrong directory name (renamed regargs dir to resty).

##[1.1] - 2016-08-19
### Fixed
- Files are always opened in binary mode (this affects mainly Windows users).

##[1.0] - 2016-07-06
### Added
- Initial Release.
