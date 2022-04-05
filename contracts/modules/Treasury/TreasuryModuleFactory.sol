//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../interfaces/ITreasuryModuleFactory.sol";
import "../../interfaces/ITreasuryModule.sol";

/// @notice A factory contract for deploying Treasury Modules
contract TreasuryModuleFactory is ITreasuryModuleFactory, ERC165 {
    function create(bytes calldata data)
        external
        returns (address treasury)
    {
        (address accessControl, address treasuryImplementation) = abi.decode(data, (address, address));  

        treasury = address(
            new ERC1967Proxy(
                treasuryImplementation,
                abi.encodeWithSelector(
                    ITreasuryModule(payable(address(0))).initialize.selector,
                    accessControl
                )
            )
        );

        emit TreasuryCreated(treasury, accessControl);
    }

    /// @notice Returns whether a given interface ID is supported
    /// @param interfaceId An interface ID bytes4 as defined by ERC-165
    /// @return bool Indicates whether the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(ITreasuryModuleFactory).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
