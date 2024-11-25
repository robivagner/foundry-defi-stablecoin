# About

This is a defi stablecoin protocol where people can deposit collateral like WETH and WBTC in exchange of a token that is pegged to the USD.

# Getting started

## Requirements
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge x.x.x`

## Quickstart
```
git clone https://github.com/robivagner/foundry-defi-stablecoin
cd foundry-defi-stablecoin
```

# Usage

## Testing

I have done 3 types of testing(unit, integration, fuzzing).

For running every test
```
forge test
```

If you want to see the coverage of the testing scripts

```
forge coverage
```

# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file, like this

```
SEPOLIA_RPC_URL=EXAMPLE_URL
PRIVATE_KEY=EXAMPLE_PRIVATE_KEY
ETHERSCAN_API_KEY=EXAMPLE_ETHERSCAN_API_KEY
```

Then you can type:

```
source .env
```

to use them in the command line after you saved the .env file.


!!PLEASE do NOT put your actual private key in the .env file it is NOT good practice. 
!!EITHER put the private key of a wallet you won't have actual money in OR use this command to store your private key interactively in a encrypted form:
```
cast wallet import <NAME_OF_ENCRYPTED_PRIVATE_KEY_WALLET> --interactive
```

2. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

3. Deploy

If you are using a encrypted wallet:
```
forge script script/DeployDSC.s.sol --rpc-url $SEPOLIA_RPC_URL --account <NAME_OF_ENCRYPTED_PRIVATE_KEY_WALLET> --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

If you are using a .env file for the private key:
```
forge script script/DeployDSC.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

To get the etherscan api key go to their [site](https://etherscan.io/), sign in, hover over your name and go to api keys. 
Then u can click add, give it a name, copy the API key token and put it in an enviromental variable in the .env file like shown above.

## Scripts

After deploying to a testnet(for example Sepolia), you can run the scripts.

Using cast send example(keep in mind if you want to use encrypted wallet use --account instead of --private-key):

Get WETH
```
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "deposit()" --value 0.001ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Approve WETH
```
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "approve(address,uint256)" <DSCEngine_CONTRACT_ADDRESS> 0.001ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Deposit and Mint DSC
```
cast send <DSCEngine_CONTRACT_ADDRESS> "depositCollateralAndMintDsc(address,uint256,uint256)" 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 0.001ether 0.0001ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

After you have sent the transactions you can import the token by going to your metamask wallet, in the tokens tab press import and paste the DecentralizedStableCoin contract address and you should see the DSC in your wallet.

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`

# Thank you!

This is a very important project for my journey. It was difficult to code and understand it but I am grateful i have gotten this far.