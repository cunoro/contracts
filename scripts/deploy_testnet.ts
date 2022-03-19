// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts on TESTNET with the account: " + deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
    console.log("===================================================================");

    const INIT_INDEX = Math.pow(10, 9);
    const EPOCH_LEGNTH = 900;
    const FIRST_EPOCH_NUM = 1;
    const FIRST_EPOCH_TIME = 1647705600;
    const REWARD_RATE = 2188;

    const CONTROL_VARIABLE = 40;
    const MIN_PRICE = 100;
    const MAX_PAYOUT = 1000;
    const BOND_FEE = 0;
    const MAX_DEBT = Math.pow(10, 15);
    const VESTING_TERM = 5*24*3600;

    const DAO = "0x0E8125aE8373b79DB639196529bbF6dA8a366891";
    const BEND = "0x19a1165A79AFAAeFd805969B32a0640d4Db9f131";
    const WAVAX = "0xd00ae08403B9bbb9124bB305C09058E32C39A48c";
    const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
    const AVAX_FEED = "0x5498BB86BC934c8D34FDA08E81D444153d0D06aD";

// NORO token deploy
    const Cunoro = await ethers.getContractFactory("CunoroERC20Token");
    const cunoro = await Cunoro.deploy();
    await cunoro.deployed();

    console.log("Cunoro Deployed.", cunoro.address);

// sNORO token deploy
    const sCunoro = await ethers.getContractFactory("sCunoroERC20Token");
    const scunoro = await sCunoro.deploy();
    await scunoro.deployed();
    // setIndex
    await scunoro.setIndex(INIT_INDEX);

    console.log("sCunoro Deployed.", scunoro.address);

// Treasury deploy
    const Treasury = await ethers.getContractFactory("CunoroTreasury");
    console.log('1');
    const treasury = await Treasury.deploy(cunoro.address, BEND, 0);
    console.log('2');
    await treasury.deployed();
    console.log('3');
    // add reserve token, dao
    await treasury.queue(2, WAVAX);
    console.log('4');
    await treasury.toggle(2, WAVAX, ZERO_ADDRESS);
    console.log('5');

    await treasury.queue(3, DAO);
    console.log('6');
    await treasury.toggle(3, DAO, ZERO_ADDRESS);
    console.log('7');
    // Cunoro.setVault
    await cunoro.setVault(treasury.address);

    console.log("Treasury Deployed.", treasury.address);

// Staking deploy
    const Staking = await ethers.getContractFactory("CunoroStaking");
    const staking = await Staking.deploy(
        cunoro.address,
        scunoro.address,
        EPOCH_LEGNTH,
        FIRST_EPOCH_NUM,
        FIRST_EPOCH_TIME
    );
    await staking.deployed();
    //sCunoro.initialize
    await scunoro.initialize(staking.address);

    console.log("Staking Deployed.", staking.address);

// StakingDistributor deploy
    const Distributor = await ethers.getContractFactory("Distributor");
    const distributor = await Distributor.deploy(
        treasury.address,
        cunoro.address,
        EPOCH_LEGNTH,
        FIRST_EPOCH_TIME
    );
    await distributor.deployed();
    // addRecipient
    await distributor.addRecipient(staking.address, REWARD_RATE);
    // add reward manager to treasury
    await treasury.queue(8, distributor.address);
    await treasury.toggle(8, distributor.address, ZERO_ADDRESS);
    // staking.setContract
    await staking.setContract(0, distributor.address);

    console.log("Distributor Deployed.", distributor.address);

// StakingHelper deploy
    const Helper = await ethers.getContractFactory("StakingHelper");
    const helper = await Helper.deploy(staking.address, cunoro.address);
    await helper.deployed();

    console.log("Helper Deployed.", helper.address);

// StakingWarmup deploy
    const Warmup = await ethers.getContractFactory("StakingWarmup");
    const warmup = await Warmup.deploy(staking.address, scunoro.address);
    await warmup.deployed();
    // staking.setContract
    await staking.setContract(1, warmup.address);

    console.log("Warmup Deployed.", warmup.address);

// BondDepository_BEND deploy
    const BondDepository = await ethers.getContractFactory("CunoroBondDepository");
    const bonddepository = await BondDepository.deploy(
        cunoro.address,
        BEND,
        treasury.address,
        DAO,
        ZERO_ADDRESS
    );
    await bonddepository.deployed();
    // initializeBondTerms
    await bonddepository.initializeBondTerms(
        CONTROL_VARIABLE,
        MIN_PRICE,
        MAX_PAYOUT,
        BOND_FEE,
        MAX_DEBT,
        VESTING_TERM
    );
    // add depositor to treasury
    await treasury.queue(0, bonddepository.address);
    await treasury.toggle(0, bonddepository.address, ZERO_ADDRESS);
    // setStaking
    await bonddepository.setStaking(helper.address, true);

    console.log("BondDepository_BEND Deployed.", bonddepository.address);

// BondDepository_AVAX deploy
    const AvaxBondDepository = await ethers.getContractFactory("AvaxBondDepository");
    const avaxbonddepository = await AvaxBondDepository.deploy(
        cunoro.address,
        WAVAX,
        treasury.address,
        DAO,
        AVAX_FEED
    );
    await avaxbonddepository.deployed();
    // initializeBondTerms
    await avaxbonddepository.initializeBondTerms(
        CONTROL_VARIABLE,
        MIN_PRICE,
        MAX_PAYOUT,
        MAX_DEBT,
        VESTING_TERM
    );
    // add depositor to treasury
    await treasury.queue(0, avaxbonddepository.address);
    await treasury.toggle(0, avaxbonddepository.address, ZERO_ADDRESS);
    // setStaking
    await avaxbonddepository.setStaking(helper.address, true);

    console.log("BondDepository_AVAX Deployed.", avaxbonddepository.address);

// StandardBondingCalculator deploy
    const BondingCalculator = await ethers.getContractFactory("CunoroBondingCalculator");
    const bondingcalculator = await BondingCalculator.deploy(cunoro.address);
    await bondingcalculator.deployed();

    console.log("BondingCalculator Deployed.", bondingcalculator.address);

// wsNORO deploy
    const wsNORO = await ethers.getContractFactory("wsNORO");
    const wsnoro = await wsNORO.deploy(scunoro.address);
    await wsnoro.deployed();

    console.log("wsNORO Deployed.", wsnoro.address);
    console.log("===================================================================");

    console.log("NORO: " + cunoro.address);
    console.log("sNORO: " + scunoro.address);
    console.log("Treasury: " + treasury.address);
    console.log("Staking: " + staking.address);
    console.log("Distributor: " + distributor.address);
    console.log("Helper: " + helper.address);
    console.log("Warmup: " + warmup.address);
    console.log("BondDepository(BEND): " + bonddepository.address);
    console.log("BondDepository(AVAX): " + avaxbonddepository.address);
    console.log("BondingCalculator: " + bondingcalculator.address);
    console.log("wsNORO: " + wsnoro.address);
}

main()
    .then(() => process.exit())
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
