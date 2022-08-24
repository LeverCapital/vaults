// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single manager authorization mixin.
/// @author prampey
abstract contract Managed {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ManagerUpdated(address indexed user, address indexed newManager);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Manages and trades with vault funds. Can be a human, bot or contract.
    address public manager;

    modifier onlyManager() virtual {
        require(msg.sender == manager, "You are not authorized to manage funds!");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _manager) {
        manager = _manager;

        emit ManagerUpdated(address(0), _manager);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function setManager(address newManager) public virtual onlyManager {
        manager = newManager;

        emit ManagerUpdated(msg.sender, newManager);
    }
}
