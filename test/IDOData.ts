import { VaultManagerMock, InvestedProviderMock, InvestProvider } from "../typechain-types"
import { IInvestProvider } from "../typechain-types/contracts/InvestProvider"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO data tests", function () {
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
        // create source pool
        await investedMock.createNewPool([await user.getAddress(), await USDT.getAddress()], [amount], signature)
        sourcePoolId = "0"
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.createNewPool(IDOSettings, signer, ethers.toUtf8Bytes(""), sourcePoolId)
    })

    it("should return currentParamsTargetLength", async () => {
        expect(await investProvider.currentParamsTargetLength()).to.equal(2)
    })

    it("should return getSubProvidersPoolIds", async () => {
        expect(await investProvider.getSubProvidersPoolIds(poolId)).to.deep.equal([poolId])
    })

    it("should return getParams", async () => {
        const poolData = await investProvider.getParams(poolId)
        expect(poolData[0]).to.equal(maxAmount)
        expect(poolData[1]).to.equal(maxAmount)
    })

    it("should return getWithdrawableAmount", async () => {
        expect(await investProvider.getWithdrawableAmount(poolId)).to.equal(0)
    })
})
