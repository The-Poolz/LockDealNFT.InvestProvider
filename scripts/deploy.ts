import { ethers } from "hardhat"

async function main() {
    // InvestProvider constructor parameters
    const lockDealNFTAddress = "0xe42876a77108E8B3B2af53907f5e533Cba2Ce7BE"
    const dispenserProvider = "0x55eB3e27355c09854f7F85371600C360Bd95d42F"
    const vaultManager = "0xF0A8AAc3deB7596527A61697D0a9728E3A67D3B7"
    // Deploy InvestProvider contract
    const InvestProviderFactory = await ethers.getContractFactory("InvestProvider")
    const investProvider = await InvestProviderFactory.deploy(lockDealNFTAddress, vaultManager, dispenserProvider)

    console.log("InvestProvider deployed to:", await investProvider.getAddress())
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
