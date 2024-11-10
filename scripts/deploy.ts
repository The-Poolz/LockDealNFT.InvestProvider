import { ethers } from "hardhat"

async function main() {
    // InvestProvider constructor parameters
    const lockDealNFTAddress = "0x3d2C83bbBbfB54087d46B80585253077509c21AE"
    const whiteListRouterAddress = "0x06eD6E9A15D1bae5835544E305e43f5cAB5DB525"
    // Deploy InvestProvider contract
    const InvestProviderFactory = await ethers.getContractFactory("InvestProvider")
    const investProvider = await InvestProviderFactory.deploy(lockDealNFTAddress, whiteListRouterAddress)

    console.log("InvestProvider deployed to:", await investProvider.getAddress())
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
