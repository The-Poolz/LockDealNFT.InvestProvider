import { VaultManager, InvestProvider, InvestedProvider } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO data tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: bigint
    let vaultManager: VaultManager
    let investProvider: InvestProvider
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let signer: SignerWithAddress
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    const maxAmount = ethers.parseUnits("1000", 18)
    const amount = ethers.parseUnits("100", 18)
    const validUntil = Math.floor(Date.now() / 1000) + 60 * 60 // 1 hour
    let poolId: bigint
    let signature: string
    let investedProvider: InvestedProvider

    before(async () => {
        [owner, user, signer] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        vaultManager = await (await ethers.getContractFactory("VaultManager")).deploy()
        lockDealNFT = (await LockDealNFTFactory.deploy(await vaultManager.getAddress(), "")) as LockDealNFT
        const InvestedProvider = await ethers.getContractFactory("InvestedProvider")
        investedProvider = await InvestedProvider.deploy(await lockDealNFT.getAddress())
        const DispenserProvider = await ethers.getContractFactory("DispenserProvider")
        const dispenserProvider = await DispenserProvider.deploy(await lockDealNFT.getAddress())
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        investProvider = await InvestProvider.deploy(await lockDealNFT.getAddress(), await dispenserProvider.getAddress(), await investedProvider.getAddress())
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await investedProvider.getAddress(), true)
        await vaultManager.setTrustee(await lockDealNFT.getAddress())
        // create vault with token
        await vaultManager["createNewVault(address)"](await USDT.getAddress())
        // create source pool
        sourcePoolId = await lockDealNFT.totalSupply()
        const nounce = await vaultManager.nonces(owner)
        const tokenAddress = await USDT.getAddress()
        const params = [amount]
        const addresses = [await signer.getAddress(), tokenAddress]

        await USDT.approve(await vaultManager.getAddress(), amount)
        await USDT.approve(await investProvider.getAddress(), maxAmount)

        const packedData = ethers.solidityPackedKeccak256(
            ["address", "uint256", "uint256"],
            [tokenAddress, amount, nounce]
        )
        const tokenSignature = await owner.signMessage(ethers.getBytes(packedData))
        // create source pool
        await dispenserProvider.connect(owner).createNewPool(addresses, params, tokenSignature)
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.createNewPool(maxAmount, signer, signer, sourcePoolId)
        const nonce = await investProvider.getNonce(poolId, await owner.getAddress())
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount, nonce]
        )
        signature = await signer.signMessage(ethers.getBytes(packedData))
    })

    it("should return currentParamsTargetLength", async () => {
        expect(await investProvider.currentParamsTargetLength()).to.equal(2)
    })

    it("should return getSubProvidersPoolIds", async () => {
        expect(await investProvider.getSubProvidersPoolIds(poolId)).to.deep.equal([poolId + 1n])
    })

    it("should return getParams", async () => {
        const poolData = await investProvider.getParams(poolId)
        expect(poolData[0]).to.equal(maxAmount)
        expect(poolData[1]).to.equal(maxAmount)
    })

    it("should return getWithdrawableAmount", async () => {
        expect(await investProvider.getWithdrawableAmount(poolId)).to.equal(0)
    })

    // Helper function to fetch the latest block timestamp
    const getLatestTimestamp = async (): Promise<number> => {
        const block = await ethers.provider.getBlock('latest')
        if (block === null) {
            throw new Error('Failed to fetch the latest block.')
        }
        return block.timestamp
    }

    // Helper function to generate a signature for investment
    const generateSignature = async (
        poolId: bigint,
        amount: bigint,
        validUntil: number,
        signer: SignerWithAddress
    ): Promise<string> => {
        const nonce = await investProvider.getNonce(poolId, await owner.getAddress())
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount, nonce]
        )
        return signer.signMessage(ethers.getBytes(packedData))
    }

    // Helper function to perform an investment and record the timestamp
    const performInvestment = async (
        poolId: bigint,
        amount: bigint,
        validUntil: number,
        signer: SignerWithAddress,
        timestamps: number[]
    ): Promise<void> => {
        const signature = await generateSignature(poolId, amount, validUntil, signer)
        await investProvider.invest(poolId, amount, validUntil, signature)
        timestamps.push(await getLatestTimestamp())
    }

    it("should return an array of user investments", async () => {
        const timestamps: number[] = [];

        // Perform 3 investments
        await performInvestment(poolId, amount, validUntil, signer, timestamps)
        await performInvestment(poolId, amount, validUntil, signer, timestamps)
        await performInvestment(poolId, amount, validUntil, signer, timestamps)

        // Prepare expected investments array
        const expectedInvestments = timestamps.flatMap((timestamp) => [timestamp.toString(), amount.toString()])

        // Fetch actual investments and compare
        const actualInvestments = (await investProvider.getUserInvests(poolId, await owner.getAddress())).map(String)

        expect(actualInvestments.toString()).to.equal(expectedInvestments.toString())
    })
})
