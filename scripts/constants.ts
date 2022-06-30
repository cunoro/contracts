export const CONTRACTS: Record<string, string> = {
    noro: "CunoroERC20Token",
    sNoro: "sCunoro",
    gNoro: "gOHM",
    staking: "CunoroStaking",
    distributor: "Distributor",
    treasury: "CunoroTreasury",
    bondDepo: "CunoroBondDepository",
    teller: "BondTeller",
    bondingCalculator: "CunoroBondingCalculator",
    authority: "CunoroAuthority",
    migrator: "CunoroTokenMigrator",
    FRAX: "Frax",
    DAI: "DAI",
    lusdAllocator: "LUSDAllocator",
};

// Constructor Arguments
export const TREASURY_TIMELOCK = 0;

// Constants
export const LARGE_APPROVAL = "100000000000000000000000000000000";
export const EPOCH_LENGTH_IN_BLOCKS = "1000";
export const FIRST_EPOCH_NUMBER = "767";
export const FIRST_EPOCH_TIME = "1639430907";
export const INITIAL_REWARD_RATE = "4000";
export const INITIAL_INDEX = "45000000000";
export const INITIAL_MINT = "60000" + "0".repeat(18); // 60K deposit.
export const BOUNTY_AMOUNT = "100000000";
export const INITIAL_MINT_PROFIT = "1000000000000";
