import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy(CONTRACTS.sNoro, {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.noro, "staking", "tokens"];
export default func;
