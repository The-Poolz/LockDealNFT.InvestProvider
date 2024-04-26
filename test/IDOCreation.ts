import { VaultManagerMock, InvestedProviderMock, InvestProvider, WhiteList } from "../typechain-types"
import { IInvestProvider } from "../typechain-types/contracts/InvestProvider"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import LockDealNFTArtifact from "@poolzfinance/lockdeal-nft/artifacts/contracts/LockDealNFT/LockDealNFT.sol/LockDealNFT.json"

describe("IDO creation tests", function () {
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
    let lockDealNFT: Contract
    let amount = ethers.parseUnits("100", 18)
    let IDOSettings: IInvestProvider.IDOStruct
    let poolId: string

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
        const startTime = Math.floor(Date.now() / 1000) + 1000
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await investedMock.getAddress(), true)
        // startTime + 24 hours
        const endTime = startTime + 86400
        IDOSettings = {
            maxAmount: amount,
            collectedAmount: 0,
            startTime: startTime,
            endTime: endTime,
            FCFSTime: 0,
            whiteListId: 0,
            investedProvider: await investedMock.getAddress(),
        }
        // create source pool
        await investedMock.createNewPool([await user.getAddress(), await USDT.getAddress()], [amount], signature)
        sourcePoolId = "0"
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
    })

    it("should create new IDO", async () => {
        await investProvider.createNewPool(IDOSettings, ethers.toUtf8Bytes(""), sourcePoolId)
        const data = await investProvider.poolIdToPool(poolId)
        expect(data.maxAmount).to.equal(amount)
        expect(data.collectedAmount).to.equal(0)
        expect(data.startTime).to.equal(IDOSettings.startTime)
        expect(data.endTime).to.equal(IDOSettings.endTime)
        expect(data.FCFSTime).to.equal(0)
        expect(data.whiteListId).to.equal(0)
        expect(data.investedProvider).to.equal(IDOSettings.investedProvider)
    })

    it("should emit NewPoolCreated event", async () => {
        const tx = await investProvider.createNewPool(IDOSettings, ethers.toUtf8Bytes(""), sourcePoolId)
        await tx.wait()
        const events = await investProvider.queryFilter(investProvider.filters.NewPoolCreated())
        await expect(events[events.length - 1].args.poolId).to.equal(poolId)
        await expect(events[events.length - 1].args.pool[0]).to.equal(IDOSettings.maxAmount)
        await expect(events[events.length - 1].args.pool[1]).to.equal(IDOSettings.collectedAmount)
        await expect(events[events.length - 1].args.pool[2]).to.equal(IDOSettings.startTime)
        await expect(events[events.length - 1].args.pool[3]).to.equal(IDOSettings.endTime)
        await expect(events[events.length - 1].args.pool[4]).to.equal(IDOSettings.FCFSTime)
        await expect(events[events.length - 1].args.pool[5]).to.equal(IDOSettings.whiteListId)
        await expect(events[events.length - 1].args.pool[6]).to.equal(IDOSettings.investedProvider)
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

    it("start time should be less than end time", async () => {
        await expect(
            investProvider.createNewPool(
                { ...IDOSettings, startTime: IDOSettings.endTime },
                ethers.toUtf8Bytes(""),
                sourcePoolId
            )
        ).to.be.revertedWithCustomError(investProvider, "InvalidTime")
    })

    it("start time should be greater than current time", async () => {
        await expect(
            investProvider.createNewPool(
                { ...IDOSettings, startTime: Math.floor(Date.now() / 1000) - 1000 },
                ethers.toUtf8Bytes(""),
                sourcePoolId
            )
        ).to.be.revertedWithCustomError(investProvider, "InvalidTime")
    })

    it("should revert if FCFS time is greater than end time", async () => {
        await expect(
            investProvider.createNewPool(
                { ...IDOSettings, FCFSTime: IDOSettings.endTime + "1" },
                ethers.toUtf8Bytes(""),
                sourcePoolId
            )
        ).to.be.revertedWithCustomError(investProvider, "InvalidTime")
    })
})
