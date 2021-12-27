let addresses = {
  sNORO_ADDRESS: '0xAAc144Dc08cE39Ed92182dd85ded60E5000C9e67',
  NORO_ADDRESS: '0xC250e9987A032ACAC293d838726C511E6E1C029d',
  MAI_ADDRESS: '0xa3Fa99A148fA48D14Ed51d610c367C61876997F1',
  TREASURY_ADDRESS: '0x8ce47D56EAa1299d3e06FF3E04637449fFb01C9C',
  NORO_BONDING_CALC_ADDRESS: '0x651125e097D7e691f3Df5F9e5224f0181E3A4a0E',
  STAKING_ADDRESS: '0xC8B0243F350AA5F8B979b228fAe522DAFC61221a',
  STAKING_HELPER_ADDRESS: '0x76B38319483b570B4BCFeD2D35d191d3c9E01691',
  MIGRATOR: '0xDaa1f5036eC158fca9E5ce791ab3e213cD1c41df',
  RESERVES: {
    MAI: '0xa3Fa99A148fA48D14Ed51d610c367C61876997F1',
    MAI_NORO: '0x1581802317f32A2665005109444233ca6E3e2D68',
  },
  BONDS: {
    MAI: '0x603A74Fd527b85E0A1e205517c1f24aC71f5C263',
    MAI_NORO: '0x706587BD39322A6a78ddD5491cDbb783F8FD983E',
  },
  NORO_CIRCULATING_SUPPLY: '0x99ee91871cf39A44E3Fc842541274d7eA05AE4b3',
}

const zeroAddress = '0x0000000000000000000000000000000000000000'

await hre.network.provider.request({ method: 'hardhat_impersonateAccount', params: ['0x929A27c46041196e1a49C7B459d63eC9A20cd879'] })
await hre.network.provider.request({ method: 'hardhat_impersonateAccount', params: ['0x63B0fB7FE68342aFad3D63eF743DE4A74CDF462B'] })
let deployer = await ethers.getSigner('0x63B0fB7FE68342aFad3D63eF743DE4A74CDF462B')
let multisig = await ethers.getSigner( '0x929A27c46041196e1a49C7B459d63eC9A20cd879')

const Treasury = await ethers.getContractFactory('CunoroTreasury')

let newTreasury = Treasury.attach('0x8ce47D56EAa1299d3e06FF3E04637449fFb01C9C').connect(deployer)

const Migrator = await ethers.getContractFactory('NoroTokenMigrator')
let migrator = Migrator.attach( '0xDaa1f5036eC158fca9E5ce791ab3e213cD1c41df').connect(deployer)

const ERC20 = await ethers.getContractFactory('CunoroNoroERC20V2')
let noro = ERC20.attach(addresses.OLD_NORO_ADDRESS)
let noro2 = ERC20.attach(addresses.NORO_ADDRESS)
let mai = ERC20.attach(addresses.MAI_ADDRESS)

const StakedCunoroNoroERC20V2 = await ethers.getContractFactory('StakedCunoroNoroERC20V2')
let sNoro = StakedCunoroNoroERC20V2.attach(addresses.OLD_SNORO_ADDRESS).connect(deployer)
let sNoro2 = StakedCunoroNoroERC20V2.attach(addresses.sNORO_ADDRESS).connect(deployer)

const Staking = await ethers.getContractFactory('CunoroStaking')
let staking = Staking.attach(addresses.STAKING_ADDRESS).connect(deployer)

// await oldTreasury.queue('1', migrator.address)
// await oldTreasury.queue('3', migrator.address)
// await oldTreasury.queue('6', migrator.address)
// await newTreasury.queue('0', migrator.address)
// await newTreasury.queue('4', migrator.address)
// await newTreasury.queue('8', migrator.address)

// await hre.network.provider.request({ method: 'evm_setNextBlockTimestamp', params:[''] })
await hre.network.provider.request({ method: 'evm_increaseTime', params:[86400/3] })

// for (var i = 0; i < 5000; i++) { await hre.network.provider.request({ method: 'evm_mine' }); console.log(i); }
await hre.network.provider.request({ method: 'evm_mine' });

// await oldTreasury.toggle('1', migrator.address, zeroAddress)
// await oldTreasury.toggle('3', migrator.address, zeroAddress)
// await oldTreasury.toggle('6', migrator.address, zeroAddress)
// await newTreasury.toggle('0', migrator.address, zeroAddress)
// await newTreasury.toggle('4', migrator.address, zeroAddress)
// await newTreasury.toggle('8', migrator.address, zeroAddress)

// await newTreasury.toggle('8', '0x0Dd015889df6F50d39e9D7A52711D0B86E43FC62', zeroAddress)

// await migrator.migrateContracts({ gasLimit: '30000000' })
// await sNoro2.setIndex(sNoro.index())

await hre.network.provider.request({ method: 'hardhat_impersonateAccount', params: ['0x63B0fB7FE68342aFad3D63eF743DE4A74CDF462B'] })
let deployer = await ethers.getSigner('0x63B0fB7FE68342aFad3D63eF743DE4A74CDF462B')
const Bond = await ethers.getContractFactory('CunoroBondDepository')
let maiBond = Bond.attach('0x603A74Fd527b85E0A1e205517c1f24aC71f5C263').connect(deployer)
let lpBond = Bond.attach('0x706587BD39322A6a78ddD5491cDbb783F8FD983E').connect(deployer)

const maiMinPrice = '5000'
const lpMinPrice = '600'

await maiBond.initializeBondTerms( '120', 5 * 24 * 3600, maiMinPrice, '50', '10000', '8000000000000000','0')
await lpBond.initializeBondTerms( '100', 5 * 24 * 3600, lpMinPrice, '50', '10000', '8000000000000000', '0')

await newTreasury.toggle('0', addresses.BONDS.MAI, zeroAddress)
await newTreasury.toggle('4', addresses.BONDS.MAI_NORO, zeroAddress)
