import { ethers } from "hardhat"

async function main() {
    const TemplateContract = await ethers.getContractFactory("TemplateContract")
    const templateContract = await TemplateContract.deploy()

    await templateContract.deployed()

    console.log("TemplateContract deployed to:", templateContract.address)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
