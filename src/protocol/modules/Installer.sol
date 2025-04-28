// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IRolesManager } from "../../interfaces/IRolesManager.sol";
import { BaseModule } from "../../libraries/base/BaseModule.sol";
import { Constants } from "../../libraries/core/Constants.sol";

contract Installer is BaseModule {
    uint256 constant INSTALLER_ADDED_MODULE_EVENT = 0x2d1d621bfcfbd5ba3ee1033741bae2750b627a2446c6f6a1dfa20df0cf29304d;

    constructor(bytes32 moduleVersion_) BaseModule(Constants.MODULEID__INSTALLER, moduleVersion_) { }

    function installModules(address[] memory moduleAddrs) external onlyAdmin {
        uint256 length = moduleAddrs.length;
        for (uint256 i; i < length;) {
            address moduleAddr = moduleAddrs[i];
            uint256 newModuleId = BaseModule(moduleAddr).moduleId();
            bytes32 moduleVersion = BaseModule(moduleAddr).moduleVersion();

            _moduleLookup[newModuleId] = moduleAddr;

            if (newModuleId <= Constants.MAX_EXTERNAL_SINGLE_PROXY_MODULEID) {
                address proxyAddr = _createProxy(newModuleId);
                _trustedSenders[proxyAddr].moduleImpl = moduleAddr;
            }

            assembly {
                //  Emit the `InstallerAddedModule` event
                mstore(0x00, moduleVersion)
                log3(0x00, 0x20, INSTALLER_ADDED_MODULE_EVENT, newModuleId, moduleAddr)
            }

            unchecked {
                ++i;
            }
        }
    }
}
