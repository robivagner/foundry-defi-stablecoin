// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// 1. The total supply of DSC should be less than the total collateral value
// 2. Getter view functions should never revert

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDCS} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDCS deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDCS();
        (dsc, engine, config) = deployer.run();
        (,, weth, wbtc) = config.activeNetworkConfig();

        // targetContract(address(dsce));
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalDscSupply() public view {
        // get value of all the collateral in the protocol
        // compare it to all the debt (dsc)

        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("wbtc value: ", wbtcValue);
        console.log("total supply: ", totalSupply);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNeverRevert() public view {
        engine.getAdditionalFeedPricison();
        engine.getPrecision();
        engine.getLiquidationThreshold();
        engine.getLiquidationPrecision();
        engine.getMinHealthFactor();
        engine.getLiquidationBonus();
        engine.getPriceFeed(weth);
        engine.getPriceFeed(wbtc);
        engine.getCollateralTokensAddresses();
        engine.getDscAddress();
    }
}
