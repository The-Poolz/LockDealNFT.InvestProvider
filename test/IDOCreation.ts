import { VaultManagerMock, InvestedProviderMock, InvestProvider } from "../typechain-types"
import { IInvestProvider } from "../typechain-types/contracts/InvestProvider"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO creation tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: string
    let mockVaultManager: VaultManagerMock
    let investProvider: InvestProvider
    let investedMock: InvestedProviderMock
    let signature = ethers.toUtf8Bytes("signature")
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let lockDealNFT: LockDealNFT
    let amount = ethers.parseUnits("100", 18)
    let IDOSettings: IInvestProvider.PoolStruct
    let poolId: string

    before(async () => {
        [owner, user] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        mockVaultManager = await (await ethers.getContractFactory("VaultManagerMock")).deploy()
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
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
            maxAmount: amount,
            whiteListId: 0,
            investedProvider: await investedMock.getAddress(),
        }
        // create source pool
        await investedMock.createNewPool([await user.getAddress(), await USDT.getAddress()], [amount], signature)
        sourcePoolId = "0"
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.connect(owner).createNewPool(IDOSettings, ethers.toUtf8Bytes(""), sourcePoolId)
    })

    it("should create new IDO", async () => {
        const data = await investProvider.poolIdToPool(poolId)
        expect(data.pool.maxAmount).to.equal(amount)
        expect(data.leftAmount).to.equal(amount)
        expect(data.pool.whiteListId).to.equal(0)
        expect(data.pool.investedProvider).to.equal(IDOSettings.investedProvider)
    })

    it("should emit NewPoolCreated event", async () => {
        poolId = await lockDealNFT.totalSupply()
        const tx = await investProvider.createNewPool(IDOSettings, ethers.toUtf8Bytes(""), sourcePoolId)
        await tx.wait()
        const events = await investProvider.queryFilter(investProvider.filters.NewPoolCreated())
        await expect(events[events.length - 1].args.poolId).to.equal(poolId)
        await expect(events[events.length - 1].args.pool.pool.maxAmount).to.equal(IDOSettings.maxAmount)
        await expect(events[events.length - 1].args.pool.leftAmount).to.equal(IDOSettings.maxAmount)
        await expect(events[events.length - 1].args.pool.pool.whiteListId).to.equal(IDOSettings.whiteListId)
        await expect(events[events.length - 1].args.pool.pool.investedProvider).to.equal(IDOSettings.investedProvider)
    })

    it("should revert zero max amount", async () => {
        await expect(
            investProvider.createNewPool(
                { ...IDOSettings, maxAmount: ethers.toBigInt(0) },
                ethers.toUtf8Bytes(""),
                sourcePoolId
            )
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAmount")
    })

    it("should revert zero invested provider address", async () => {
        await expect(
            investProvider.createNewPool(
                { ...IDOSettings, investedProvider: ethers.ZeroAddress },
                ethers.toUtf8Bytes(""),
                sourcePoolId
            )
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAddress")
    })

    it("should support IInvestProvider interface", async () => {
        expect(await investProvider.supportsInterface("0xa358958c")).to.equal(true)
    })

    it("should revert invalid investedProvider", async () => {
        await expect(
            investProvider.createNewPool(
                { ...IDOSettings, investedProvider: await owner.getAddress() },
                ethers.toUtf8Bytes(""),
                sourcePoolId
            )
        ).to.be.revertedWithCustomError(investProvider, "InvalidInvestedProvider")
    })

    // @dev withdraw is not implemented in the contract right now
    it("should revert withdraw", async () => {
        await expect(
            lockDealNFT
                .connect(owner)
                [
                    "safeTransferFrom(address,address,uint256)"
                ](await owner.getAddress(), await lockDealNFT.getAddress(), poolId)
        ).to.be.rejected
    })

    it("should revert withdraw not from LockDealNFT", async () => {
        await expect(investProvider.connect(owner).withdraw(poolId)).to.be.revertedWithCustomError(
            investProvider,
            "OnlyLockDealNFT"
        )
    })

    it("should revert split not from LockDealNFT", async () => {
        await expect(investProvider.connect(owner).split(poolId, poolId, poolId)).to.be.revertedWithCustomError(
            investProvider,
            "OnlyLockDealNFT"
        )
    })

    it("should call register from another provider", async () => {
        await investedMock.callRegister(await investProvider.getAddress(), poolId, [0, 0, 0])
        const updatedData = await investProvider.getParams(poolId)
        expect(updatedData[0]).to.be.equal(0)
        expect(updatedData[1]).to.be.equal(0)
        expect(updatedData[2]).to.be.equal(0)
    })

    it("should revert call register not from approved provider", async () => {
        await expect(investProvider.connect(owner).registerPool(poolId, [0, 0, 0])).to.be.revertedWithCustomError(
            investProvider,
            "InvalidProvider"
        )
    })
})
