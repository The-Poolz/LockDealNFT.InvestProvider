import { VaultManagerMock, InvestedProviderMock, InvestProvider } from "../typechain-types"
import { IInvestProvider } from "../typechain-types/contracts/InvestProvider"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO split tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: string
    let mockVaultManager: VaultManagerMock
    let investProvider: InvestProvider
    let investedMock: InvestedProviderMock
    let signature = ethers.toUtf8Bytes("signature")
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let signer: SignerWithAddress
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    let amount = ethers.parseUnits("100", 18)
    let maxAmount = ethers.parseUnits("1000", 18)
    let IDOSettings: IInvestProvider.PoolStruct
    let poolId: bigint
    let ratio: bigint
    let packedData: string
    let vaultId: string
    const whiteListId = 1

    before(async () => {
        [owner, user, signer] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        mockVaultManager = await (await ethers.getContractFactory("VaultManagerMock")).deploy()
        lockDealNFT = (await LockDealNFTFactory.deploy(await mockVaultManager.getAddress(), "")) as LockDealNFT
        investedMock = await (
            await ethers.getContractFactory("InvestedProviderMock")
        ).deploy(await lockDealNFT.getAddress())
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        investProvider = await InvestProvider.deploy(await lockDealNFT.getAddress())
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await investedMock.getAddress(), true)
        // startTime + 24 hours
        IDOSettings = {
            maxAmount: maxAmount,
            investedProvider: await investedMock.getAddress(),
        }
        // create token pool
        await investedMock
            .connect(owner)
            .createNewPool([await user.getAddress(), await token.getAddress()], [amount], signature)
        // create USDT pool
        await investedMock
            .connect(owner)
            .createNewPool([await user.getAddress(), await USDT.getAddress()], [amount], signature)
        vaultId = "2"
        sourcePoolId = "1"
        ratio = ethers.parseUnits("1", 21) / 2n // half of the amount
        await lockDealNFT.approvePoolTransfers(true)
        packedData = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "address"], [ratio, await user.getAddress()])
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.createNewPool(IDOSettings, signerAddress, ethers.toUtf8Bytes(""), sourcePoolId)
    })

    it("should update old pool data after split", async () => {
        await lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"]
            (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(poolId)
        expect(data).to.deep.equal([
            await investProvider.getAddress(),
            "InvestProvider",
            poolId,
            vaultId,
            await owner.getAddress(),
            await USDT.getAddress(),
            [maxAmount / 2n, maxAmount / 2n],
        ])
    })

    it("should create new pool after split", async () => {
        await lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"]
            (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(poolId + 2n)
        expect(data).to.deep.equal([
            await investProvider.getAddress(),
            "InvestProvider",
            poolId + 2n,
            vaultId,
            await user.getAddress(),
            await USDT.getAddress(),
            [maxAmount / 2n, maxAmount / 2n],
        ])
    })

    it("should emit PoolSplit event", async () => {
        const tx = await lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"]
            (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        await tx.wait()
        const event = await lockDealNFT.queryFilter(lockDealNFT.filters.PoolSplit())
        const data = event[event.length - 1].args
        expect(data.poolId).to.equal(poolId)
        expect(data.newPoolId).to.equal(poolId + 2n)
        expect(data.owner).to.equal(await owner.getAddress())
        expect(data.newOwner).to.equal(await user.getAddress())
        expect(data.splitLeftAmount).to.equal(maxAmount / 2n)
        expect(data.newSplitLeftAmount).to.equal(maxAmount / 2n)
    })

    it("should revert invalid ratio", async () => {
        ratio = ethers.parseUnits("2", 21)
        packedData = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "address"], [ratio, await user.getAddress()])
        await expect(lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"]
                (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        ).to.be.revertedWith('split amount exceeded');
    })
})
