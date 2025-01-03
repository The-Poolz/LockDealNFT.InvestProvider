import { VaultManager, InvestWrapped } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO investment tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: bigint
    let vaultManager: VaultManager
    let investProvider: InvestWrapped
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let signer: SignerWithAddress
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    const amount = ethers.parseUnits("100", 18)
    const maxAmount = ethers.parseUnits("1000", 18)
    const validUntil = Math.floor(Date.now() / 1000) + 60 * 60 // 1 hour
    let poolId: bigint
    let packedData: string
    let signature: string

    before(async () => {
        [owner, user, signer] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        vaultManager = await (await ethers.getContractFactory("VaultManager")).deploy()
        lockDealNFT = (await LockDealNFTFactory.deploy(await vaultManager.getAddress(), "")) as LockDealNFT
        const DispenserProvider = await ethers.getContractFactory("DispenserProvider")
        const dispenserProvider = await DispenserProvider.deploy(await lockDealNFT.getAddress())
        const InvestProvider = await ethers.getContractFactory("InvestWrapped")
        investProvider = await InvestProvider.deploy(
            await lockDealNFT.getAddress(),
            await dispenserProvider.getAddress()
        )
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
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

        await token.approve(await investProvider.getAddress(), maxAmount * 10n)
        await USDT.approve(await investProvider.getAddress(), maxAmount * 10n)
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.createNewPool(maxAmount, signerAddress, signerAddress, sourcePoolId, false)
        const nonce = await investProvider.getNonce(poolId, await owner.getAddress())
        packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount, nonce]
        )
        signature = await signer.signMessage(ethers.getBytes(packedData))
    })

    it("should deacrease left amount after invest", async () => {
        await investProvider.invest(poolId, amount, validUntil, signature)
        const poolData = await investProvider.getParams(poolId)
        expect(poolData[1]).to.equal(maxAmount - amount)
    })

    it("should emit Invested event", async () => {
        const tx = await investProvider.invest(poolId, amount, validUntil, signature)
        await tx.wait()
        const events = await investProvider.queryFilter(investProvider.filters.Invested())
        expect(events[events.length - 1].args.poolId).to.equal(poolId)
        expect(events[events.length - 1].args.user).to.equal(await owner.getAddress())
        expect(events[events.length - 1].args.amount).to.equal(amount)
    })

    it("should transfer erc20 tokens to vault", async () => {
        const vaultId = await vaultManager.getCurrentVaultIdByToken(await USDT.getAddress())
        const vault = await vaultManager.vaultIdToVault(vaultId)
        const balanceBefore = await USDT.balanceOf(vault)
        await investProvider.invest(poolId, amount, validUntil, signature)
        expect(await USDT.balanceOf(vault)).to.equal(balanceBefore + amount)
    })

    it("should revert if no allowance", async () => {
        const nonce = await investProvider.getNonce(poolId, await owner.getAddress())
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await user.getAddress(), validUntil, amount, nonce]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await expect(
            investProvider.connect(user).invest(poolId, amount, validUntil, signature)
        ).to.be.revertedWithCustomError(USDT, "ERC20InsufficientAllowance")
    })

    it("should revert if invested amount is more than left amount", async () => {
        const nonce = await investProvider.getNonce(poolId, await owner.getAddress())
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, maxAmount + 1n, nonce]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await expect(
            investProvider.invest(poolId, maxAmount + 1n, validUntil, signature)
        ).to.be.revertedWithCustomError(investProvider, "ExceededLeftAmount")
    })

    it("should revert invalid signature", async () => {
        await expect(investProvider.invest(poolId, amount, validUntil + 1, signature)).to.be.revertedWithCustomError(
            investProvider,
            "InvalidSignature"
        )
    })

    it("should revert investment if the pool is closed", async () => {
        await lockDealNFT
            .connect(signer)[
                "safeTransferFrom(address,address,uint256)"
            ](await signer.getAddress(), await lockDealNFT.getAddress(), poolId)
            await expect(investProvider.invest(poolId, amount, validUntil, signature)).to.be.revertedWithCustomError(
                investProvider,
                "InactivePool"
            )
    })

    it("should revert if set invalid poolID", async () => {
        const invalidPoolId = poolId + 1n
        await expect(investProvider.invest(invalidPoolId, amount, validUntil, signature)).to.be.revertedWithCustomError(
            investProvider,
            "InvalidProvider"
        )
    })

    it("should revert if zero amount", async () => {
        await expect(investProvider.invest(poolId, 0, validUntil, signature)).to.be.revertedWithCustomError(
            investProvider,
            "NoZeroAmount"
        )
    })

    it("should revert past time", async () => {
        const pastTime = Math.floor(Date.now() / 1000) - 1
        await expect(investProvider.invest(poolId, amount, pastTime, signature)).to.be.revertedWithCustomError(
            investProvider,
            "InvalidTime"
        )
    })

    it("should revert if signer is not valid", async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider["createNewPool(uint256,address,address,uint256,bool)"](
            maxAmount,
            signerAddress,
            await owner.getAddress(),
            sourcePoolId,
            false
        )
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, maxAmount]
        )
        const signature = await owner.signMessage(ethers.getBytes(packedData))
        await expect(investProvider.invest(poolId, maxAmount, validUntil, signature)).to.be.revertedWithCustomError(
            investProvider,
            "InvalidSignature"
        )
    })

    it("should revert double invest", async () => {
        await investProvider.invest(poolId, amount, validUntil, signature)
        await expect(investProvider.invest(poolId, amount, validUntil, signature)).to.be.revertedWithCustomError(
            investProvider,
            "InvalidSignature"
        )
    })
})
