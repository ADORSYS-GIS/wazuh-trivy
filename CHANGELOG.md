# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

[a989307](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/a98930738971f0c3403a845eb03b7652477ab427)...[fb0eac1](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/fb0eac16450f15083d97bd8b2b3ede255fb75a22)

### Bug Fixes

- Update Trivy installation command to handle input redirection ([`db97210`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/db97210eaed5374e8952d83482e9e1cddfd805ef)), Signed-off-by:Awambeng Rodrick <awambengrodrick@gmail.com>
- Update Trivy installation to use a temporary script for improved sudo handling ([`6dfe945`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/6dfe945a27ace3f2175bdb17482411dc04e8266c)), Signed-off-by:Awambeng Rodrick <awambengrodrick@gmail.com>
- Update Trivy version to 0.69.3 in installation and uninstall scripts, and adjust test to reflect new version ([`8b8296a`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/8b8296a8016e46658ddba3f48b6895a83ad0221f)), Signed-off-by:Awambeng Rodrick <awambengrodrick@gmail.com>
- Preserve PATH environment variable during Trivy installation ([`9763cc8`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/9763cc87965dce018afa65f5422dd56bff6e9105))
- Corrected command_exists function to return actual command existence ([`edf06dd`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/edf06dd06ecc8e8c65e1d47b01e593b42a708552))

### Documentation

- Update CHANGELOG.md and checksums [skip ci] ([`fc55ed6`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/fc55ed6358a313f03c9ace094d1f3c558d530db8))
- Update CHANGELOG.md and checksums [skip ci] ([`3951b13`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/3951b1363ee48eb6d9392dc97eb09ce87c7f003b))
- Update CHANGELOG.md and checksums [skip ci] ([`327a6d3`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/327a6d37a7811f237442b23d7c2b622e16ead131))
- Update CHANGELOG.md and checksums [skip ci] ([`f1913f6`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/f1913f60ea35a188150ea05fe133257db3f0bab6))
- Update CHANGELOG.md and checksums [skip ci] ([`12ea65a`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/12ea65a265eadd17d2914d5d1b9466e56c11b84d))

### Miscellaneous Tasks

- Update checksums ([`ce80e15`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/ce80e159bb0a399ca25d2949a1f850b2810a3f5c))
- Add job to update changelog and checksums automatically ([`7e0398c`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/7e0398c3c6ac16c61a7032a916b48ed97d86347d))
- Refactor install and uninstall scripts to use shared utils ([`ce84a60`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/ce84a604643cfcac1835498373a527c0684c6a09))
- Chore(ci): add podman installation in CI workflows ([`506c7e3`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/506c7e3fdb1376b4ffbdd1b8b6afa4631f7e9995))

## 0.0.1 - 2026-04-02

### Bug Fixes

- Run commands in sudo mode ([`3a39ecb`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/3a39ecb2ca2a0862e150d8b79d3f316932b66122))
- Configure wazuh agent with dummmy setup ([`3699b60`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/3699b60fb435cd7981fe8bb31870ddba9cc1bf9c))
- Improve scan script ([`ea9b440`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/ea9b44049a015b72134dca1087a2df084ac2045a))
- Fix way of using template file ([`04d642b`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/04d642b6c34f20b33bca1cba1e87cb9720bd3ca9))
- Fix bats test for linux and macos ([`f4eaf58`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/f4eaf582a02298eb458bd4a0bec6103b32400c4f))
- Enhance Trivy installation logic to check for correct version and handle missing container engine ([`63ee22d`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/63ee22d7d9cdd1222468c6db10b5a8ea6bb6d6bc))
- Update Trivy installation path for macOS and Linux ([`460f003`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/460f003b80f97de1d1e532581aa82e0e7e601d63))
- Correct Trivy version format in installation script ([`fefe5d1`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/fefe5d1c8fc422a918eb509db5861c8b78d87964))
- Update containerd image retrieval logic to handle namespaces correctly ([`df21f23`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/df21f231e23df69b5dc249d3d6becc56c70a05fc))
- Update README to correct workflow badge and installation command ([`7050b4f`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/7050b4fded13863d3f5d4044011575bccfee6043))
- Specify main branch for pull request trigger in workflow ([`02b4bb4`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/02b4bb4681821bacc7fca147085045e417807a20))
- Update Trivy version and script URLs, simplify install logic ([`6d33562`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/6d33562c2eb64876563755d48b5fd95cb170dd9d))
- Add environment variable for repository reference in CI workflow ([`81907bf`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/81907bf9a9aca848636b74129be9bdf542c81c2a))
- Update WAZUH_TRIVY_REPO_REF to remove refs/heads prefix ([`3c8ac79`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/3c8ac79731d050ef2b7d4285187b0f753013dfd8))
- Use environment variables ([`9b18ed9`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/9b18ed9afe103624d4e163b9b4a571f4c39cd3ba))
- Use env command for setting WAZUH_AGENT_REPO_REF in installation scripts ([`205bd2d`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/205bd2d16ff86ef81410162cc03eeb460510deef))
- Update installation script paths for macOS and Linux ([`a989307`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/a98930738971f0c3403a845eb03b7652477ab427))

### Documentation

- Add monitoring of trivy scan logs ([`d8e13f3`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/d8e13f34a2649a92a3fa6896f9afb672ba641584))
- Add monitoring of trivy scan logs ([`1a0b48a`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/1a0b48ad222a9a6ea8c351df7ec8f0e648111d08))
- Add test workflow badge ([`8eaf74b`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/8eaf74beccc3f6ba296aaadf5c8b4cfc2db1adab))

### Features

- Add uninstall script for Trivy with logging and cleanup functions ([`e440290`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/e440290ebd764f406c47e7073412bb7e3f6dea11))
- Consolidate CI workflow into a single file and add script checksums ([`df84553`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/df845538ba5c4e2c103e1fc3a825d5326b88c5d2))
- Log Trivy scan script URL during setup ([`01981e1`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/01981e135ca7663c152967780ebddabd80b48680))

### Miscellaneous Tasks

- Add script to install trivy on hosts: update trivy scan script to consider docker odman and containerd ([`5e0cea6`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/5e0cea66ed76373ed61d2bddd3eb42f496776fe8))
- Create log file if it doesn't exist with install script ([`1e6768a`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/1e6768a0acdb3383805b6c4092816f6a23b5c0a8))
- Create log file if it doesn't exist with install script ([`480baf1`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/480baf1a0d3e2b4c1023651a3ce891e9ded0e54a))
- Add test workflow ([`163eaf3`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/163eaf31274f9525465e2371db6703ab114d11dc))
- Update copyright signature in scan script ([`33a850f`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/33a850fddf7f4b344176605fa72f0155a3b2bde5))
- Update path in which scan script is stored ([`df00ff6`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/df00ff627ea1333008c11ec79505a171eedc221c))
- Improve scan script ([`4e23e0c`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/4e23e0cba638b37dd306ff7a7cbd79914e4b5f31))
- Update scan script path ([`2e43835`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/2e438356a5de4e1db92e7c7c6a4baf0753a791b6))
- Configure for macos ([`5f27454`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/5f27454cd3b583700e98cf86c2682dfb012ab5ed))
- Improve trivy installation logging messages ([`49bd87b`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/49bd87bb297e3157427c5c7b002efd9aca365a23))

### Refactor

- Rename trivy_scan.sh -> trivy-scan.sh ([`297dfa5`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/297dfa57d5e7d2f3d79f7bef4f0ad798c70c175e))
- Restructure and modularize installation and scanning scripts ([`256c2ed`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/256c2ed23adf447d036f6ce9c4b501ce276e3a38))
- Unify and enhance logging and scanning logic for Linux and macOS scripts ([`bae8761`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/bae87617bf8c1f842d3eb0d423f230672ca34b49))
- Update Trivy script URL handling and ensure directory creation ([`936aada`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/936aadadcf78ef3bb5fea59765d0092c039b4d1d))

### Add

- Wazuh-trivy config ([`ec3addb`](https://github.com/ADORSYS-GIS/wazuh-trivy/commit/ec3addb42e4ab7c6a925ee9ad121cf191e711f71))

<!-- generated by git-cliff -->
