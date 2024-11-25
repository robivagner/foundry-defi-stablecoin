// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployDCS} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDCS deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public user = makeAddr("USER");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant LIQUIDATOR_COLLATERAL = 100 ether;
    uint256 public constant LIQUIDATOR_STARTING_BALANCE_WETH = 1000 ether;
    uint256 public constant STARTING_BALANCE_WETH = 100 ether;
    uint256 public constant STARTING_BALANCE_WBTC = 100 ether;
    uint256 public constant ETH_USD_PRICE = 2000;
    uint256 public constant BTC_USD_PRICE = 1000;
    uint256 public constant AMOUNT_DSC = 100e18;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    function setUp() public {
        deployer = new DeployDCS();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_BALANCE_WETH);
        ERC20Mock(wbtc).mint(user, STARTING_BALANCE_WBTC);
    }

    // Constructor Tests
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    // Price Tests

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = ethAmount * ETH_USD_PRICE; //15e18*2000
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100e18;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWeth, actualWeth);
    }

    function testGetAccountCollateralValueInUsd() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        ERC20Mock(wbtc).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(wbtc, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 expectedAccountCollateralValueInUsd =
            (AMOUNT_COLLATERAL * ETH_USD_PRICE) + (AMOUNT_COLLATERAL * BTC_USD_PRICE);
        uint256 actualAccountCollateralValueInUsd = engine.getAccountCollateralValueInUsd(user);

        assertEq(expectedAccountCollateralValueInUsd, actualAccountCollateralValueInUsd);
    }

    function testGetAccountCollateralValueInUsdIsZero() public view {
        uint256 expectedAccountCollateralValueInUsd = 0;
        uint256 actualAccountCollateralValueInUsd = engine.getAccountCollateralValueInUsd(user);

        assertEq(expectedAccountCollateralValueInUsd, actualAccountCollateralValueInUsd);
    }

    // Deposit Collateral Tests

    function testDepositCollateralRevertsIfAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testDepositCollateralRevertsWithUnapprovedCollateral() public {
        ERC20Mock token = new ERC20Mock("TOKEN", "TOK", user, AMOUNT_COLLATERAL);
        vm.prank(user);
        vm.expectRevert(DSCEngine.DCSEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(token), AMOUNT_COLLATERAL);
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testDepositCollateralAndGetAccountInfoWorks() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(user);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testDepositCollateralAndMintDscWorks() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSC);
        vm.stopPrank();

        uint256 expectedDscMinted = AMOUNT_DSC;
        uint256 expectedCollateralInUsd = AMOUNT_COLLATERAL * ETH_USD_PRICE;
        (uint256 actualDscMinted, uint256 actualCollateralInUsd) = engine.getAccountInformation(user);

        assertEq(expectedDscMinted, actualDscMinted);
        assertEq(expectedCollateralInUsd, actualCollateralInUsd);
    }

    // Mint DSC Tests

    function testMintDscWorks() public depositedCollateral {
        vm.prank(user);
        engine.mintDsc(AMOUNT_DSC);

        uint256 expectedDscMinted = AMOUNT_DSC;
        (uint256 actualDscMinted,) = engine.getAccountInformation(user);

        assertEq(expectedDscMinted, actualDscMinted);
    }

    function testMintDscRevertsIfAmountIsZero() public depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDsc(0);
    }

    function testMintDscRevertsIfHealthFactorBreaks() public depositedCollateral {
        vm.prank(user);
        uint256 userHealthFactor = 5e17;
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DCSEngine__BreaksHealthFactor.selector, userHealthFactor));
        engine.mintDsc(20000e18);
    }

    // Burn DSC Tests

    function testBurnDscWorks() public depositedCollateral {
        vm.startPrank(user);
        engine.mintDsc(AMOUNT_DSC);
        dsc.approve(address(engine), AMOUNT_DSC);
        engine.burnDsc(AMOUNT_DSC);
        vm.stopPrank();

        uint256 expectedDscAmount = 0;
        (uint256 actualDscAmount,) = engine.getAccountInformation(user);

        assertEq(expectedDscAmount, actualDscAmount);
    }

    function testBurnDscRevertsIfAmountIsMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        engine.burnDsc(1e18);
    }

    function testBurnDscRevertsIfAmountIsZero() public depositedCollateral {
        vm.startPrank(user);
        engine.mintDsc(AMOUNT_DSC);
        dsc.approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }

    // Redeem Collateral Tests

    function testRedeemCollateralWorks() public depositedCollateral {
        vm.startPrank(user);
        engine.mintDsc(AMOUNT_DSC);
        engine.redeemCollateral(weth, 1e18);
        (, uint256 actualCollateralValueInUsd) = engine.getAccountInformation(user);
        vm.stopPrank();

        uint256 expectedCollateralValueInUsd = (AMOUNT_COLLATERAL - 1e18) * ETH_USD_PRICE;

        assertEq(expectedCollateralValueInUsd, actualCollateralValueInUsd);
    }

    function testRedeemCollateralRevertsIfAmountIsZero() public depositedCollateral {
        vm.startPrank(user);
        engine.mintDsc(AMOUNT_DSC);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRedeemCollateralForDscWorks() public depositedCollateral {
        vm.startPrank(user);
        engine.mintDsc(AMOUNT_DSC);
        dsc.approve(address(engine), AMOUNT_DSC);
        engine.redeemCollateralForDsc(weth, 1e18, 50e18);
        vm.stopPrank();

        uint256 expectedDscAmount = 50e18;
        uint256 expectedCollateralValueInUsd = (AMOUNT_COLLATERAL - 1e18) * ETH_USD_PRICE;
        (uint256 actualDscAmount, uint256 actualCollateralInUsd) = engine.getAccountInformation(user);

        assertEq(expectedDscAmount, actualDscAmount);
        assertEq(expectedCollateralValueInUsd, actualCollateralInUsd);
    }

    function testRedeemCollateralRevertsIfHealthFactorBreaks() public depositedCollateral {
        vm.startPrank(user);
        engine.mintDsc(AMOUNT_DSC);
        uint256 userHealthFactor = 5e17;
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DCSEngine__BreaksHealthFactor.selector, userHealthFactor));
        engine.redeemCollateral(weth, 19900e18 / ETH_USD_PRICE);
    }

    // Health Factor Tests

    function testHealthFactorWorks() public depositedCollateral {
        vm.prank(user);
        engine.mintDsc(AMOUNT_DSC);

        uint256 actualHealthFactor = engine.getHealthFactor(user);
        uint256 expectedHealthFactor = 10000e18 * 1e18 / AMOUNT_DSC;

        assertEq(expectedHealthFactor, actualHealthFactor);
    }

    function testHealthFactorIsMinimumIfNoDscWasMinted() public depositedCollateral {
        vm.prank(user);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);

        uint256 actualHealthFactor = engine.getHealthFactor(user);
        uint256 expectedHealthFactor = MIN_HEALTH_FACTOR;

        assertEq(expectedHealthFactor, actualHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateral {
        vm.prank(user);
        engine.mintDsc(AMOUNT_DSC);

        int256 ethUsdNewPrice = 10e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdNewPrice);
        uint256 healthFactor = engine.getHealthFactor(user);

        assertEq(healthFactor, 5e17);
    }

    // Liquidate Tests

    function testLiquidateRevertsIfAmountIsZero() public depositedCollateral {
        address anotherUser = makeAddr("anotherUser");

        vm.prank(anotherUser);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.liquidate(weth, user, 0);
    }

    function testLiquidateRevertsIfUserHealthFactorIsOk() public depositedCollateral {
        address anotherUser = makeAddr("anotherUser");

        vm.prank(anotherUser);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, user, 1e18);
    }

    function testLiquidateRevertsHealthFactorNotImproved() public depositedCollateral {
        vm.prank(user);
        engine.mintDsc(AMOUNT_DSC);
        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        ERC20Mock(weth).mint(liquidator, STARTING_BALANCE_WETH);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSC);
        vm.stopPrank();

        int256 ethUsdNewPrice = 10e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdNewPrice);
        vm.startPrank(liquidator);
        dsc.approve(address(engine), 10e18);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        engine.liquidate(weth, user, 10e18);
        vm.stopPrank();
    }

    function testLiquidateWorks() public depositedCollateral {
        vm.prank(user);
        engine.mintDsc(AMOUNT_DSC);
        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        ERC20Mock(weth).mint(liquidator, LIQUIDATOR_STARTING_BALANCE_WETH);
        uint256 startingLiquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 startingLiquidatedUserCollateralDeposited = engine.getUserCollateralDeposited(weth, user);
        ERC20Mock(weth).approve(address(engine), LIQUIDATOR_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, LIQUIDATOR_COLLATERAL, AMOUNT_DSC);
        vm.stopPrank();

        int256 ethUsdNewPrice = 19e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdNewPrice);
        vm.startPrank(liquidator);
        dsc.approve(address(engine), AMOUNT_DSC);
        engine.liquidate(weth, user, AMOUNT_DSC);
        vm.stopPrank();
        uint256 actualLiquidatorWethBalance =
            ERC20Mock(weth).balanceOf(liquidator) + engine.getUserCollateralDeposited(weth, liquidator);
        uint256 expectedLiquidatorWethBalance = startingLiquidatorWethBalance
            + engine.getTokenAmountFromUsd(weth, AMOUNT_DSC)
            + (engine.getTokenAmountFromUsd(weth, AMOUNT_DSC) / engine.getLiquidationBonus());
        uint256 actualLiquidatorDebt = engine.getAmountDscMinted(liquidator);
        uint256 expectedLiquidatorDebt = AMOUNT_DSC;
        uint256 actualLiquidatedUserWethBalance =
            ERC20Mock(weth).balanceOf(user) + engine.getUserCollateralDeposited(weth, user);
        uint256 expectedLiquidatedUserWethBalance = ERC20Mock(weth).balanceOf(user)
            + startingLiquidatedUserCollateralDeposited
            - (
                engine.getTokenAmountFromUsd(weth, AMOUNT_DSC)
                    + (engine.getTokenAmountFromUsd(weth, AMOUNT_DSC) / engine.getLiquidationBonus())
            );
        uint256 actualLiquidatedUserDebt = engine.getAmountDscMinted(user);
        uint256 expectedLiquidatedUserDebt = 0;

        assertEq(actualLiquidatorWethBalance, expectedLiquidatorWethBalance);
        assertEq(actualLiquidatorDebt, expectedLiquidatorDebt);
        assertEq(actualLiquidatedUserWethBalance, expectedLiquidatedUserWethBalance);
        assertEq(actualLiquidatedUserDebt, expectedLiquidatedUserDebt);
    }
}
