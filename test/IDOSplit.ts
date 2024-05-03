import { VaultManagerMock, InvestedProviderMock, InvestProvider, WhiteList } from "../typechain-types"
import { IInvestProvider } from "../typechain-types/contracts/InvestProvider"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import LockDealNFTArtifact from "@poolzfinance/lockdeal-nft/artifacts/contracts/LockDealNFT/LockDealNFT.sol/LockDealNFT.json"

describe("IDO split tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: string
    let mockVaultManager: VaultManagerMock
    let investProvider: InvestProvider
    let whiteList: WhiteList
    let investedMock: InvestedProviderMock
    let signature = ethers.toUtf8Bytes("signature")
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let lockDealNFT: LockDealNFT
    let amount = ethers.parseUnits("100", 18)
    let maxAmount = ethers.parseUnits("1000", 18)
    let IDOSettings: IInvestProvider.PoolStruct
    let poolId: string
    let ratio: bigint
    let packedData: string
    let vaultId: string
    const whiteListId = 1

    before(async () => {
        [owner, user] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        const LockDealNFT = await ethers.getContractFactory(LockDealNFTArtifact.abi, LockDealNFTArtifact.bytecode)
        mockVaultManager = await (await ethers.getContractFactory("VaultManagerMock")).deploy()
        lockDealNFT = await LockDealNFT.deploy(await mockVaultManager.getAddress(), "")
        investedMock = await (
            await ethers.getContractFactory("InvestedProviderMock")
        ).deploy(await lockDealNFT.getAddress())
        const WhiteList = await ethers.getContractFactory("WhiteList")
        whiteList = await WhiteList.deploy()
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        investProvider = await InvestProvider.deploy(await lockDealNFT.getAddress(), await whiteList.getAddress())
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await investedMock.getAddress(), true)
        // startTime + 24 hours
        IDOSettings = {
            maxAmount: maxAmount,
            whiteListId: whiteListId,
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
        packedData = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "address"], [ratio, await user.getAddress()])
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.connect(owner).createNewPool(IDOSettings, ethers.toUtf8Bytes(""), sourcePoolId)
    })

    it("should update old pool data after split", async () => {
        await lockDealNFT.connect(owner)["safeTransferFrom(address,address,uint256,bytes)"]
            (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(poolId)
        expect(data).to.deep.equal([
            await investProvider.getAddress(),
            "InvestProvider",
            poolId,
            vaultId,
            await owner.getAddress(),
            await USDT.getAddress(),
            [maxAmount / 2n, maxAmount / 2n, whiteListId],
        ])
    })

    it("should create new pool after split", async () => {
        await lockDealNFT.connect(owner)["safeTransferFrom(address,address,uint256,bytes)"]
            (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(parseInt(poolId) + 1)
        expect(data).to.deep.equal([
            await investProvider.getAddress(),
            "InvestProvider",
            parseInt(poolId) + 1,
            vaultId,
            await user.getAddress(),
            await USDT.getAddress(),
            [maxAmount / 2n, maxAmount / 2n, whiteListId],
        ])
    })

    it("should emit PoolSplit event", async () => {
        const tx = await lockDealNFT.connect(owner)["safeTransferFrom(address,address,uint256,bytes)"]
            (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        await tx.wait()
        const event = await lockDealNFT.queryFilter(lockDealNFT.filters.PoolSplit())
        const data = event[event.length - 1].args
        expect(data.poolId).to.equal(poolId)
        expect(data.newPoolId).to.equal(parseInt(poolId) + 1)
        expect(data.owner).to.equal(await owner.getAddress())
        expect(data.newOwner).to.equal(await user.getAddress())
        expect(data.splitLeftAmount).to.equal(maxAmount / 2n)
        expect(data.newSplitLeftAmount).to.equal(maxAmount / 2n)
    })

    it("should revert invalid ratio", async () => {
        ratio = ethers.parseUnits("2", 21)
        packedData = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "address"], [ratio, await user.getAddress()])
        await expect(lockDealNFT.connect(owner)["safeTransferFrom(address,address,uint256,bytes)"]
                (await owner.getAddress(), await lockDealNFT.getAddress(), poolId, packedData)
        ).to.be.revertedWith('split amount exceeded');
    })
})
