import { VaultManager, InvestProvider, ProviderMock, DispenserProvider, InvestedProvider } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO creation tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: bigint
    let vaultManager: VaultManager
    let investProvider: InvestProvider
    let providerMock: ProviderMock
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let signer: SignerWithAddress
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    const amount = ethers.parseUnits("100", 18)
    let poolId: bigint
    let dispenserProvider: DispenserProvider
    let investedProvider: InvestedProvider

    before(async () => {
        [owner, user, signer] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        vaultManager = await (await ethers.getContractFactory("VaultManager")).deploy()
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        lockDealNFT = (await LockDealNFTFactory.deploy(await vaultManager.getAddress(), "")) as LockDealNFT
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        const InvestedProvider = await ethers.getContractFactory("InvestedProvider")
        investedProvider = await InvestedProvider.deploy(await lockDealNFT.getAddress())
        const DispenserProvider = await ethers.getContractFactory("DispenserProvider")
        dispenserProvider = await DispenserProvider.deploy(await lockDealNFT.getAddress())
        investProvider = await InvestProvider.deploy(
            await lockDealNFT.getAddress(),
            await dispenserProvider.getAddress(),
            await investedProvider.getAddress()
        )
        const ProviderMock = await ethers.getContractFactory("ProviderMock")
        providerMock = await ProviderMock.deploy(await lockDealNFT.getAddress())
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await providerMock.getAddress(), true)
        await lockDealNFT.setApprovedContract(await investedProvider.getAddress(), true)
        // create source pool
        // set trustee
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
        await expect(events[events.length - 1].args.owner).to.equal(signerAddress)
        await expect(events[events.length - 1].args.poolAmount).to.equal(amount)
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
        await expect(investProvider.createNewPool(0n, sourcePoolId)).to.be.revertedWithCustomError(
            investProvider,
            "NoZeroAmount"
        )
    })

    it("should revert zero max amount with two signers", async () => {
        await expect(
            investProvider.createNewPool(0n, signerAddress, signerAddress, sourcePoolId)
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAmount")
    })

    it("should support IInvestProvider interface", async () => {
        expect(await investProvider.supportsInterface("0x16615bcc")).to.equal(true)
    })

    // @dev withdraw is not implemented in the contract right now
    it("should revert withdraw", async () => {
        await expect(
            lockDealNFT
                .connect(owner)[
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

    it("should revert zero lockDealNFT address", async () => {
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        await expect(
            InvestProvider.deploy(ethers.ZeroAddress, await dispenserProvider.getAddress(), await investedProvider.getAddress())
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAddress")
    })

    it("should revert zero dispenserProvider address", async () => {
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        await expect(
            InvestProvider.deploy(await lockDealNFT.getAddress(), ethers.ZeroAddress, await investedProvider.getAddress())
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAddress")
    })

    it("should revert zero investedProvider address", async () => {
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        await expect(
            InvestProvider.deploy(await lockDealNFT.getAddress(), await dispenserProvider.getAddress(), ethers.ZeroAddress)
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAddress")
    })

    it("should revert zero invest signer address", async () => {
        await expect(
            investProvider.createNewPool(amount, ethers.ZeroAddress, signerAddress, sourcePoolId)
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAddress")
    })

    it("should revert zero dispenser signer address", async () => {
        await expect(
            investProvider.createNewPool(amount, signerAddress, ethers.ZeroAddress, sourcePoolId)
        ).to.be.revertedWithCustomError(investProvider, "NoZeroAddress")
    })

    it("should revert invalid sourcePoolId with two signers", async () => {
        await expect(investProvider.createNewPool(amount, signerAddress, signerAddress, "99999")).to.be.revertedWithCustomError(
            investProvider,
            "InvalidSourcePoolId"
        )
    })

    it("should revert invalid sourcePoolId", async () => {
        await expect(investProvider.createNewPool(amount, "99999")).to.be.revertedWithCustomError(investProvider, "InvalidSourcePoolId")
    })
})
