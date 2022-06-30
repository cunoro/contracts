const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account: " + deployer.address);

    const DAI = "0xB2180448f8945C8Cc8AE9809E67D6bd27d8B2f2C";
    const oldOHM = "0xC0b491daBf3709Ee5Eb79E603D73289Ca6060932";
    const oldsOHM = "0x1Fecda1dE7b6951B248C0B62CaeBD5BAbedc2084";
    const oldStaking = "0xC5d3318C0d74a72cD7C55bdf844e24516796BaB2";
    const oldwsOHM = "0xe73384f11Bb748Aa0Bc20f7b02958DF573e6E2ad";
    const sushiRouter = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
    const uniRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
    const oldTreasury = "0x0d722D813601E48b7DAcb2DF9bae282cFd98c6E7";

    const FRAX = "0x2f7249cb599139e560f0c81c269ab9b04799e453";
    const LUSD = "0x45754df05aa6305114004358ecf8d04ff3b84e26";

    const Authority = await ethers.getContractFactory("CunoroAuthority");
    const authority = await Authority.deploy(
        deployer.address,
        deployer.address,
        deployer.address,
        deployer.address
    );

    const Migrator = await ethers.getContractFactory("CunoroTokenMigrator");
    const migrator = await Migrator.deploy(
        oldOHM,
        oldsOHM,
        oldTreasury,
        oldStaking,
        oldwsOHM,
        sushiRouter,
        uniRouter,
        "0",
        authority.address
    );

    const firstEpochNumber = "550";
    const firstBlockNumber = "9505000";

    const OHM = await ethers.getContractFactory("CunoroERC20Token");
    const noro = await OHM.deploy(authority.address);

    const SOHM = await ethers.getContractFactory("sCunoro");
    const sOHM = await SOHM.deploy();

    const GOHM = await ethers.getContractFactory("gOHM");
    const gOHM = await GOHM.deploy(migrator.address, sOHM.address);

    await migrator.setgOHM(gOHM.address);

    const CunoroTreasury = await ethers.getContractFactory("CunoroTreasury");
    const cunoroTreasury = await CunoroTreasury.deploy(noro.address, "0", authority.address);

    await cunoroTreasury.queueTimelock("0", migrator.address, migrator.address);
    await cunoroTreasury.queueTimelock("8", migrator.address, migrator.address);
    await cunoroTreasury.queueTimelock("2", DAI, DAI);
    await cunoroTreasury.queueTimelock("2", FRAX, FRAX);
    await cunoroTreasury.queueTimelock("2", LUSD, LUSD);

    await authority.pushVault(cunoroTreasury.address, true); // replaces noro.setVault(treasury.address)

    const CunoroStaking = await ethers.getContractFactory("CunoroStaking");
    const staking = await CunoroStaking.deploy(
        noro.address,
        sOHM.address,
        gOHM.address,
        "2200",
        firstEpochNumber,
        firstBlockNumber,
        authority.address
    );

    const Distributor = await ethers.getContractFactory("Distributor");
    const distributor = await Distributor.deploy(
        cunoroTreasury.address,
        noro.address,
        staking.address,
        authority.address
    );

    // Initialize snoro
    await sOHM.setIndex("7675210820");
    await sOHM.setgOHM(gOHM.address);
    await sOHM.initialize(staking.address, cunoroTreasury.address);

    await staking.setDistributor(distributor.address);

    await cunoroTreasury.execute("0");
    await cunoroTreasury.execute("1");
    await cunoroTreasury.execute("2");
    await cunoroTreasury.execute("3");
    await cunoroTreasury.execute("4");

    console.log("Cunoro Authority: ", authority.address);
    console.log("OHM: " + noro.address);
    console.log("sNoro: " + sOHM.address);
    console.log("gOHM: " + gOHM.address);
    console.log("Cunoro Treasury: " + cunoroTreasury.address);
    console.log("Staking Contract: " + staking.address);
    console.log("Distributor: " + distributor.address);
    console.log("Migrator: " + migrator.address);
}

main()
    .then(() => process.exit())
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
