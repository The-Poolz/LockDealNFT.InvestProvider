import { VaultManagerMock, InvestedProviderMock, InvestProvider } from "../typechain-types"
import { IInvestProvider } from "../typechain-types/contracts/InvestProvider"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO investment tests", function () {
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
    let validUntil = Math.floor(Date.now() / 1000) + 60 * 60
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
        await USDT.approve(await investProvider.getAddress(), maxAmount)
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.createNewPool(IDOSettings, signerAddress, ethers.toUtf8Bytes(""), sourcePoolId)
    })

    it("should deacrease left amount after invest", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount / 2n]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await investProvider.invest(poolId, amount / 2n, validUntil, signature, ethers.toUtf8Bytes(""))
        const poolData = await investProvider.getParams(poolId)
        expect(poolData[1]).to.equal(maxAmount - amount / 2n)
    })

    it("should emit Invested event", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        const tx = await investProvider.invest(poolId, amount, validUntil, signature, ethers.toUtf8Bytes(""))
        await tx.wait()
        const events = await investProvider.queryFilter(investProvider.filters.Invested())
        expect(events[events.length - 1].args.poolId).to.equal(poolId)
        expect(events[events.length - 1].args.user).to.equal(await owner.getAddress())
        expect(events[events.length - 1].args.amount).to.equal(amount)
    })

    it("should transfer ERC20 tokens", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        const before = await USDT.balanceOf(await investedMock.getAddress())
        await investProvider.invest(poolId, amount, validUntil, signature, ethers.toUtf8Bytes(""))
        const after = await USDT.balanceOf(await investedMock.getAddress())
        expect(after).to.equal(before + amount)
    })

    it("should revert if no allowance", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await user.getAddress(), validUntil, amount]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await expect(
            investProvider.connect(user).invest(poolId, amount, validUntil, signature, ethers.toUtf8Bytes(""))
        ).to.be.revertedWithCustomError(USDT, "ERC20InsufficientAllowance")
    })

    it("should revert if invested amount is more than left amount", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, maxAmount + 1n]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await expect(
            investProvider.invest(poolId, maxAmount + 1n, validUntil, signature, ethers.toUtf8Bytes(""))
        ).to.be.revertedWithCustomError(investProvider, "ExceededLeftAmount")
    })

    it("should revert invalid signature", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await expect(
            investProvider.invest(poolId, amount, validUntil += 1, signature, ethers.toUtf8Bytes(""))
        ).to.be.revertedWithCustomError(investProvider, "InvalidSignature")
    })
})
