//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../DAOConfigs/BravoGovernor.sol";
import "../TokenFactory.sol";
import "../ACL.sol";

/// @notice A contract for creating new DAOs 
contract BravoFactory {
    struct CreateDAOParameters {
        address governanceImplementation; 
        address[] proposers;
        address[] executors;
        string daoName;
        uint256 minDelay;
        uint64 initialVoteExtension;
        uint256 initialVotingDelay;
        uint256 initialVotingPeriod;
        uint256 initialProposalThreshold;
        uint256 initialQuorumNumeratorValue;
    }

    struct CreateDAOAndTokenParameters {
       	CreateDAOParameters createDAOParameters;
        address tokenFactory;
        string tokenName;
        string tokenSymbol;
        uint256 tokenTotalSupply;
        address[] hodlers;
        uint256[] allocations;
    }

    struct CreateDAOWrapTokenParameters {
       	CreateDAOParameters createDAOParameters;
        address tokenFactory;
        address tokenAddress;
        string tokenName;
        string tokenSymbol;
    }

    struct CreateDAOBringTokenParameters {
       	CreateDAOParameters createDAOParameters;
        address tokenAddress;
    }

    event DAODeployed(
        address deployer,
        address votingToken,
        address timelockController,
        address daoProxy,
        address acl
    );

    /// @notice Creates a new DAO and an ERC-20 token that supports voting
    /// @param createDAOAndTokenParameters Struct of all DAO and token creation parameters
    /// @return The address of the created voting token contract
    /// @return The address of the deployed TimelockController contract
    /// @return The address of the proxy deployed for the created DAO
    function createDAOAndToken(
        CreateDAOAndTokenParameters calldata createDAOAndTokenParameters
    )
        external
        returns (
            address,
            address,
            address
        )
    {
        address timelockController = _createTimelock(
            createDAOAndTokenParameters.createDAOParameters.minDelay,
            createDAOAndTokenParameters.createDAOParameters.proposers,
            createDAOAndTokenParameters.createDAOParameters.executors
        );
        
        address votingToken = TokenFactory(createDAOAndTokenParameters.tokenFactory).createToken(
            createDAOAndTokenParameters.tokenName,
            createDAOAndTokenParameters.tokenSymbol,
            createDAOAndTokenParameters.hodlers,
            createDAOAndTokenParameters.allocations,
            createDAOAndTokenParameters.tokenTotalSupply,
            timelockController
        );

        address aclAddress = _createACL(timelockController);

        address proxyAddress = _createDAO(
            createDAOAndTokenParameters.createDAOParameters,
            votingToken,
            timelockController,
            aclAddress
        );

        return (votingToken, timelockController, proxyAddress);
    }

    /// @notice Creates a new DAO and wraps an existing ERC-20 token 
    /// @notice with a new governance token that supports voting
    /// @param createDAOWrapTokenParameters Struct of all DAO and wrapped token creation parameters
    /// @return The address of the created voting token contract
    /// @return The address of the deployed TimelockController contract
    /// @return The address of the proxy deployed for the created DAO
    function createDAOWrapToken(
        CreateDAOWrapTokenParameters calldata createDAOWrapTokenParameters
    )
        external
        returns (
            address,
            address,
            address
        )
    {
        address timelockController = _createTimelock(
            createDAOWrapTokenParameters.createDAOParameters.minDelay,
            createDAOWrapTokenParameters.createDAOParameters.proposers,
            createDAOWrapTokenParameters.createDAOParameters.executors
        );

        address wrappedTokenAddress = TokenFactory(createDAOWrapTokenParameters.tokenFactory).wrapToken(
            createDAOWrapTokenParameters.tokenAddress,
            createDAOWrapTokenParameters.tokenName,
            createDAOWrapTokenParameters.tokenSymbol
        );

        address aclAddress = _createACL(timelockController);

        address proxyAddress = _createDAO(
            createDAOWrapTokenParameters.createDAOParameters,
            wrappedTokenAddress,
            timelockController,
            aclAddress
        );
        return (wrappedTokenAddress, timelockController, proxyAddress);
    }

    /// @notice Creates a new DAO with an existing ERC-20 token that supports voting
    /// @param createDAOBringTokenParameters Struct of all DAO and existing voting token parameters
    /// @return The address of the voting token contract
    /// @return The address of the deployed TimelockController contract
    /// @return The address of the proxy deployed for the created DAO
    function createDAOBringToken(
        CreateDAOBringTokenParameters calldata createDAOBringTokenParameters
    )
        external
        returns (
            address,
            address,
            address
        )
    {       
        address timelockController = _createTimelock(
            createDAOBringTokenParameters.createDAOParameters.minDelay,
            createDAOBringTokenParameters.createDAOParameters.proposers,
            createDAOBringTokenParameters.createDAOParameters.executors
        );

        address aclAddress = _createACL(timelockController);

        address proxyAddress = _createDAO(
            createDAOBringTokenParameters.createDAOParameters,
            createDAOBringTokenParameters.tokenAddress,
            timelockController,
            aclAddress
        );

        return (createDAOBringTokenParameters.tokenAddress, timelockController, proxyAddress);
    }

    /// @dev Creates a new DAO by deploying a new instance of MyGovernor
    /// @param createDAOParameters Struct of all DAO params
    /// @param votingToken The address of the governanceToken
    /// @param timelockController The address of the TimelockController created for the DAO
    /// @param acl The address of the ACL created for the DAO
    /// @return The address of the proxy contract deployed for the created 
    function _createDAO(
        CreateDAOParameters calldata createDAOParameters,
        address votingToken,
        address timelockController,
        address acl
    ) private returns (address) {
        address proxyAddress = address(
            new ERC1967Proxy(
                createDAOParameters.governanceImplementation,
                abi.encodeWithSelector(
                    BravoGovernor(payable(address(0))).initialize.selector,
                    createDAOParameters.daoName,
                    votingToken,
                    timelockController,
                    createDAOParameters.initialVoteExtension,
                    createDAOParameters.initialVotingDelay,
                    createDAOParameters.initialVotingPeriod,
                    createDAOParameters.initialProposalThreshold,
                    createDAOParameters.initialQuorumNumeratorValue
                )
            )
        );
        BravoGovernor(payable(proxyAddress)).transferOwnership(timelockController);

        _configTimelock(timelockController, proxyAddress);

        emit DAODeployed(
            msg.sender,
            votingToken,
            timelockController,
            proxyAddress,
            acl
        );

        return proxyAddress;
    }

    /// @dev Deploys a TimelockController contract for the new DAO
    /// @param proposers Array of addresses that can create proposals
    /// @param executors Array of addresses that can execute proposals
    /// @return The address of the deployed TimelockController contract
    function _createTimelock(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) private returns(address) {
        address timelockController = address(
            new TimelockController(minDelay, proposers, executors)
        );
        return timelockController;
    }

    /// @dev Deploys a ACL contract to manage system level permissions 
    /// @param timelock address of timelock
    /// @return The address of the deployed ACL contract
    function _createACL(
        address timelock
    ) private returns(address) {
        address acl = address(
            new ACL(timelock)
        );
        return acl;
    }

    /// @dev Configures the timelock controller to give the proxy address 
    /// @dev proposer and executor roles
    /// @param _timelock The address of the TimelockController contract
    /// @param _proxyAddress The address of the MyGovernor proxy
    function _configTimelock(address _timelock, address _proxyAddress) private {
        bytes32 proposerRole = keccak256("PROPOSER_ROLE");
        bytes32 executorRole = keccak256("EXECUTOR_ROLE");
        TimelockController(payable(_timelock)).grantRole(
            proposerRole,
            _proxyAddress
        );
        TimelockController(payable(_timelock)).grantRole(
            executorRole,
            _proxyAddress
        );
        TimelockController(payable(_timelock)).renounceRole(
            proposerRole,
            address(this)
        );
        TimelockController(payable(_timelock)).renounceRole(
            executorRole,
            address(this)
        );
    }
}
