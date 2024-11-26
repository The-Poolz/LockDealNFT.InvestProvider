import { VaultManager, InvestProvider, ProviderMock } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO creation tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: string
    let vaultManager: VaultManager
    let investProvider: InvestProvider
    let providerMock: ProviderMock
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let signer: SignerWithAddress
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    let amount = ethers.parseUnits("100", 18)
    let poolId: bigint

    before(async () => {
        ;[owner, user, signer] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        vaultManager = await (await ethers.getContractFactory("VaultManager")).deploy()
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        lockDealNFT = (await LockDealNFTFactory.deploy(await vaultManager.getAddress(), "")) as LockDealNFT
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        const DispenserProvider = await ethers.getContractFactory("DispenserProvider")
        const dispenserProvider = await DispenserProvider.deploy(await lockDealNFT.getAddress())
        investProvider = await InvestProvider.deploy(
            await lockDealNFT.getAddress(),
            await dispenserProvider.getAddress()
        )
        const ProviderMock = await ethers.getContractFactory("ProviderMock")
        providerMock = await ProviderMock.deploy(await lockDealNFT.getAddress())
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await providerMock.getAddress(), true)
        // create source pool
        signerAddress = await signer.getAddress()
        sourcePoolId = "0"
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.connect(owner).createNewPool(amount, signerAddress, signerAddress, sourcePoolId)
    })

    it("should create new IDO", async () => {
        const data = await investProvider.poolIdToPool(poolId)
        expect(data.maxAmount).to.equal(amount)
        expect(data.leftAmount).to.equal(amount)
    })

    it("should emit NewPoolCreated event", async () => {
        poolId = await lockDealNFT.totalSupply()
        const tx = await investProvider.createNewPool(amount, signerAddress, signerAddress, sourcePoolId)
        await tx.wait()
        const events = await investProvider.queryFilter(investProvider.filters.NewPoolCreated())
        await expect(events[events.length - 1].args.poolId).to.equal(poolId)
        await expect(events[events.length - 1].args.pool.maxAmount).to.equal(amount)
        await expect(events[events.length - 1].args.pool.leftAmount).to.equal(amount)
    })

    it("should set msg.sender as the owner of the investProvider NFT after creating a new pool", async () => {
        const ownerAdress = await owner.getAddress()
        const poolId = await lockDealNFT.totalSupply()
        // create new pool
        await investProvider.createNewPool(amount, sourcePoolId)
        expect(await lockDealNFT.ownerOf(poolId)).to.equal(ownerAdress)
    })

    it("should set msg.sender as the owner of the dispenserProvider NFT after creating a new pool", async () => {
        const ownerAdress = await owner.getAddress()
        const poolId = await lockDealNFT.totalSupply()
        // create new pool
        await investProvider.createNewPool(amount, sourcePoolId)
        expect(await lockDealNFT.ownerOf(poolId + 1n)).to.equal(ownerAdress)
    })

    it("should call register from another provider", async () => {
        const maxAmount = 10n
        const leftAmount = 5n
        await providerMock.callRegister(await investProvider.getAddress(), poolId, [maxAmount, leftAmount])
        const updatedData = await investProvider.getParams(poolId)
        expect(updatedData[0]).to.be.equal(maxAmount)
        expect(updatedData[1]).to.be.equal(leftAmount)
    })

    it("should revert register with non valid params length", async () => {
        const maxAmount = 10n
        await expect(
            providerMock.callRegister(await investProvider.getAddress(), poolId, [maxAmount])
        ).to.be.revertedWithCustomError(investProvider, "InvalidParamsLength")
    })

    it("should revert zero max amount", async () => {
        await expect(
            investProvider.createNewPool(ethers.toBigInt(0), signerAddress, signerAddress, sourcePoolId)
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAmount")
    })

    it("should support IInvestProvider interface", async () => {
        expect(await investProvider.supportsInterface("0x16615bcc")).to.equal(true)
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

    it("should revert call register not from approved provider", async () => {
        await expect(investProvider.connect(owner).registerPool(poolId, [0, 0])).to.be.revertedWithCustomError(
            investProvider,
            "InvalidProvider"
        )
    })
})
