import { ethers } from "hardhat"
import { InvestProvider } from "../typechain-types/contracts/InvestProvider"
import { LockDealNFT } from "../typechain-types"
import { ERC20Token } from "../typechain-types/contracts/mocks"

async function main() {
    const [owner] = await ethers.getSigners()

    const investProvider = await getContractInstance<InvestProvider>(
        "InvestProvider",
        "0x9D5901180eD6CaFC2502a9b43F994A6113B854FB"
    )
    const lockDealNFT = await getContractInstance<LockDealNFT>(
        "LockDealNFT",
        "0xe42876a77108E8B3B2af53907f5e533Cba2Ce7BE"
    )

    // Invest parameters
    const poolAmount = ethers.parseEther("1000000000")
    const sourcePoolID = 10457n
    const signerAddress = await owner.getAddress()
    const dispenserSigner = await owner.getAddress()
    const investAmount = ethers.parseEther("10000000")
    const validUntil = Math.floor(Date.now() / 1000) + 60 * 60
    const poolId = await lockDealNFT.totalSupply()

    // Create new pools
    await investProvider["createNewPool(uint256,uint256)"](poolAmount, sourcePoolID, {
        gasLimit: 1000000,
    })
    await investProvider["createNewPool(uint256,address,address,uint256)"](
        poolAmount,
        signerAddress,
        dispenserSigner,
        sourcePoolID,
        {
            gasLimit: 1000000,
        }
    )

    // Approve tokens for investing
    const tokenAddress = await lockDealNFT.tokenOf(poolId)
    const token = await getContractInstance<ERC20Token>("ERC20Token", tokenAddress)
    await token.approve(await investProvider.getAddress(), investAmount, {
        gasLimit: 100000,
    })

    // Perform investment
    const packedData = createPackedData(poolId, await owner.getAddress(), validUntil, investAmount)
    const tokenSignature = await owner.signMessage(ethers.getBytes(packedData))

    await investProvider.invest(poolId, investAmount, validUntil, tokenSignature, {
        gasLimit: 1000000,
    })
}

async function getContractInstance<T>(contractName: string, address: string): Promise<T> {
    const factory = await ethers.getContractFactory(contractName)
    return factory.attach(address) as T
}

function createPackedData(poolId: bigint, ownerAddress: string, validUntil: number, investAmount: bigint): string {
    return ethers.solidityPackedKeccak256(
        ["uint256", "address", "uint256", "uint256"],
        [poolId, ownerAddress, validUntil, investAmount]
    )
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
