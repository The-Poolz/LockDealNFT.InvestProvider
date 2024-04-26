import { VaultManagerMock, InvestedProviderMock, InvestProvider, WhiteList } from "../typechain-types"
import { IInvestProvider } from "../typechain-types/contracts/InvestProvider"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import LockDealNFTArtifact from "@poolzfinance/lockdeal-nft/artifacts/contracts/LockDealNFT/LockDealNFT.sol/LockDealNFT.json"
import { time } from '@nomicfoundation/hardhat-network-helpers';

describe("IDO investment tests", function () {
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
    const startTime = Math.floor(Date.now() / 1000) + 1000
    let halfTime: number
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
        halfTime = (endTime - startTime) / 2;
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.createNewPool(IDOSettings, ethers.toUtf8Bytes(""), sourcePoolId)
    })

    it("should emit Invested event", async () => {
        await time.setNextBlockTimestamp(startTime + halfTime / 2)
        const tx = await investProvider.invest(poolId, amount, ethers.toUtf8Bytes(""))
        await tx.wait()
        const events = await investProvider.queryFilter(investProvider.filters.Invested())
        expect(events.length).to.equal(1)
        expect(events[0].args.poolId).to.equal(poolId)
        expect(events[0].args.user).to.equal(await owner.getAddress())
        expect(events[0].args.amount).to.equal(amount)
    })
})
