// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin dsc;

    function setUp() public {
        dsc = new DecentralizedStableCoin();
    }

    function testFunctionMintWorks() public {
        // Arrange/Act
        bool success = dsc.mint(address(this), 100);

        // Assert
        assertEq(dsc.balanceOf(address(this)), 100, "Not enough");
        assertEq(success, true, "Not true");
    }

    function testFunctionMintOnlyOwnerCanCall() public {
        // Arrange
        address user = makeAddr("USER");

        // Act/Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        dsc.mint(address(this), 100);
    }

    function testFunctionMintRevertIfToIsAddressZero() public {
        // Arrange/Act/Assert
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), 100);
    }

    function testFunctionMintRevertIfAmountIsLowerEqualZero() public {
        // Arrange/Act/Assert
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MintMustBeMoreThanZero.selector);
        dsc.mint(address(this), 0);
    }

    function testFunctionBurnWorks() public {
        // Arrange
        dsc.mint(address(this), 100);

        // Act
        dsc.burn(50);

        // Assert
        assertEq(dsc.balanceOf(address(this)), 50, "Not enough");
    }

    function testFunctionBurnOnlyOwnerCanCall() public {
        // Arrange
        address user = makeAddr("USER");
        dsc.mint(address(this), 100);

        // Act/Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        dsc.burn(50);
    }

    function testFunctionBurnRevertIfAmountLowerEqualZero() public {
        // Arrange
        dsc.mint(address(this), 100);

        // Act/Assert
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnMustBeMoreThanZero.selector);
        dsc.burn(0);
    }

    function testFunctionBurnRevertIfBalanceLowerThanAmount() public {
        // Arrange
        dsc.mint(address(this), 100);

        // Act/Assert
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(101);
    }
}
