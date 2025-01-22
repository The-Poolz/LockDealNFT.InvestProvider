import { VaultManager, InvestWrapped, IWBNB, DispenserProvider, InvestedProvider } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"
import { loadWBNBArtifact } from "./loadWBNB"
import {createEIP712Signature} from "./helper"

describe("IDO with wrapped tokens", function () {
    let token: ERC20Token
    let vaultManager: VaultManager
    let investWrapped: InvestWrapped
    let investedProvider: InvestedProvider
    let lockDealNFT: LockDealNFT
    let dispenserProvider: DispenserProvider
    let wBNB: IWBNB
    let owner: SignerWithAddress
    let signer: SignerWithAddress
    let sourcePoolId: bigint
    let poolId: bigint
    const amount = ethers.parseUnits("10", 18)
    const maxAmount = ethers.parseUnits("1000", 18)
    const validUntil = Math.floor(Date.now() / 1000) + 60 * 60 // 1 hour
    let signerAddress: string
    let signature: string

    before(async () => {
        [owner, signer] = await ethers.getSigners()
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        await deployContracts()
        await setupInitialConditions()
        signature = await createInvestPool()
    })

    it("should create wrapped token invest pool", async () => {
        expect(await lockDealNFT.tokenOf(poolId)).to.equal(await wBNB.getAddress())
    })

    it("should decrease left amount after wrapped token invest", async () => {
        await investWrapped.investETH(poolId, validUntil, signature, { value: amount })
        const poolData = await investWrapped.getParams(poolId)
        expect(poolData[1]).to.equal(maxAmount - amount)
    })

    it("should emit Invested event after wrapped token invest", async () => {
        const tx = await investWrapped.investETH(poolId, validUntil, signature, { value: amount })
        await tx.wait()
        const events = await investWrapped.queryFilter(investWrapped.filters.Invested())
        expect(events[events.length - 1].args.poolId).to.equal(poolId)
        expect(events[events.length - 1].args.user).to.equal(await owner.getAddress())
        expect(events[events.length - 1].args.amount).to.equal(amount)
    })

    it("should transfer erc20 tokens to wrapped vault", async () => {
        const vaultId = await vaultManager.getCurrentVaultIdByToken(await wBNB.getAddress())
        const vault = await vaultManager.vaultIdToVault(vaultId)
        const balanceBefore = await wBNB.balanceOf(vault)
        await investWrapped.investETH(poolId, validUntil, signature, { value: amount })
        expect(await wBNB.balanceOf(vault)).to.equal(balanceBefore + amount)
    })

    it("should handle regular tokens if not wrapped", async () => {
        sourcePoolId = await createSourcePool()
        signature = await createInvestPool(false)
        const { balanceBefore, balanceAfter } = await investInPool({ poolId, amount, validUntil, signature, isWrapped: false })
        await expect(balanceAfter).to.equal(balanceBefore + amount)
    })

    it("should revert direct split call", async () => {
        await expect(investWrapped.split(poolId, poolId, amount)).to.be.revertedWithCustomError(
            investWrapped,
            "OnlyLockDealNFT"
        )
    })

    it("should revert zero amount invest", async () => {
        await expect(
            investWrapped.investETH(poolId, validUntil, signature, { value: 0 })
        ).to.be.revertedWithCustomError(investWrapped, "NoZeroValue")
    })


    it("should revert wrapped tokens if call invest", async () => {
        await expect(investWrapped.invest(poolId, amount, validUntil, signature)).to.be.revertedWithCustomError(
            investWrapped,
            "InvalidERC20Token"
        )
    })

    it("should update left amount after ETH refund", async () => {
        // Invest tokens.
        await investWrapped.investETH(poolId, validUntil, signature, { value: amount })
        const leftAmountBefore = (await investWrapped.getParams(poolId))[1]
        // Refund tokens.
        await investWrapped.refundETH(poolId, amount, validUntil, signature)
        // Check left amount.
        const leftAmountAfter = (await investWrapped.getParams(poolId))[1]
        expect(leftAmountAfter).to.equal(leftAmountBefore + amount)
    })

    it("should emit Refunded event after ETH refund", async () => {
        await investWrapped.investETH(poolId, validUntil, signature, { value: amount })
        const tx = await investWrapped.refundETH(poolId, amount, validUntil, signature)
        await tx.wait()
        const events = await investWrapped.queryFilter(investWrapped.filters.Refunded())
        expect(events[events.length - 1].args.poolId).to.equal(poolId)
        expect(events[events.length - 1].args.user).to.equal(await owner.getAddress())
        expect(events[events.length - 1].args.amount).to.equal(amount)
    })

    it("should revert not valid provider pool id in refundETH", async () => {
        await expect(investWrapped.refundETH(0, amount, validUntil, signature)).to.be.revertedWithCustomError(
            investWrapped,
            "InvalidProvider"
        )
    })

    it("should revert not wrapped tokens if call refundETH", async () => {
        sourcePoolId = await createSourcePool()
        await createInvestPool(false)
        await expect(investWrapped.refundETH(poolId, amount, validUntil, signature)).to.be.revertedWithCustomError(
            investWrapped,
            "InvalidWrappedToken"
        )
    })

    it("should revert invalid time in refundETH", async () => {
        await expect(investWrapped.refundETH(poolId, amount, 0, signature)).to.be.revertedWithCustomError(
            investWrapped,
            "InvalidTime"
        )
    })

    it("should revert zero amount refundETH", async () => {
        await expect(investWrapped.refundETH(poolId, 0, validUntil, signature)).to.be.revertedWithCustomError(
            investWrapped,
            "NoZeroAmount"
        )
    })

    // Helper Functions
    async function deployContracts() {
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        const data = await loadWBNBArtifact()
        const WBNB = await ethers.getContractFactory(data.abi, data.bytecode)
        wBNB = (await WBNB.deploy()) as IWBNB

        vaultManager = await (await ethers.getContractFactory("VaultManager")).deploy()

        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        lockDealNFT = await LockDealNFTFactory.deploy(await vaultManager.getAddress(), "")

        const DispenserProvider = await ethers.getContractFactory("DispenserProvider")
        dispenserProvider = await DispenserProvider.deploy(await lockDealNFT.getAddress())

        const InvestedProvider = await ethers.getContractFactory("InvestedProvider")
        investedProvider = await InvestedProvider.deploy(await lockDealNFT.getAddress())

        const InvestWrapped = await ethers.getContractFactory("InvestWrapped")
        investWrapped = await InvestWrapped.deploy(await lockDealNFT.getAddress(), await dispenserProvider.getAddress(), await investedProvider.getAddress())
    }

    async function setupInitialConditions() {
        await lockDealNFT.setApprovedContract(await investWrapped.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await investedProvider.getAddress(), true)
        await vaultManager.setTrustee(await lockDealNFT.getAddress())

        // Initialize vaults
        const tokenAddress = await wBNB.getAddress()
        await vaultManager["createNewVault(address)"](tokenAddress)
        await vaultManager["createNewVault(address)"](await token.getAddress())

        // Create source pool
        sourcePoolId = await lockDealNFT.totalSupply()
        const nounce = await vaultManager.nonces(owner)
        const packedData = ethers.solidityPackedKeccak256(
            ["address", "uint256", "uint256"],
            [tokenAddress, amount, nounce]
        )
        const tokenSignature = await owner.signMessage(ethers.getBytes(packedData))

        await wBNB.approve(await vaultManager.getAddress(), amount)
        await wBNB.deposit({ value: amount })

        const addresses = [await signer.getAddress(), tokenAddress]
        await dispenserProvider.connect(owner).createNewPool(addresses, [amount], tokenSignature)

        await token.approve(await investWrapped.getAddress(), maxAmount)
        await wBNB.approve(await investWrapped.getAddress(), maxAmount)
    }

    async function createInvestPool(isWrapped = true): Promise<string> {
        poolId = await lockDealNFT.totalSupply()
        await investWrapped["createNewPool(uint256,address,address,uint256,bool)"](
            maxAmount,
            signerAddress,
            signerAddress,
            sourcePoolId,
            isWrapped
        )
        const nonce = await investWrapped.getNonce(poolId, await owner.getAddress())
        return await createEIP712Signature(
            poolId,
            await owner.getAddress(),
            validUntil,
            amount,
            nonce,
            signer,
            await investWrapped.getAddress()
        )
    }

    async function createSourcePool() {
        const nonce = await vaultManager.nonces(owner)
        const addresses = [await signer.getAddress(), await token.getAddress()]
        const packedData = ethers.solidityPackedKeccak256(
            ["address", "uint256", "uint256"],
            [await token.getAddress(), amount, nonce]
        )
        const tokenSignature = await owner.signMessage(ethers.getBytes(packedData))

        await token.approve(await vaultManager.getAddress(), amount)
        await vaultManager["createNewVault(address)"](await token.getAddress())

        const sourcePoolId = await lockDealNFT.totalSupply()
        await dispenserProvider.connect(owner).createNewPool(addresses, [amount], tokenSignature)
        return sourcePoolId
    }

    async function investInPool({
        poolId,
        amount,
        validUntil,
        signature,
        isWrapped = true,
    }: {
        poolId: bigint
        amount: bigint
        validUntil: number
        signature: string,
        isWrapped: boolean
    }): Promise<{ balanceBefore: bigint; balanceAfter: bigint }> {
        await token.approve(await investWrapped.getAddress(), amount)

        const vaultId = await vaultManager.getCurrentVaultIdByToken(await token.getAddress())
        const balanceBefore = await token.balanceOf(await vaultManager.vaultIdToVault(vaultId))

        if (isWrapped) {
            await investWrapped.investETH(poolId, validUntil, signature, { value: amount })
        }
        else {
            await investWrapped.invest(poolId, amount, validUntil, signature)
        }

        const vault = await vaultManager.vaultIdToVault(vaultId)
        const balanceAfter = await token.balanceOf(vault)

        return { balanceBefore, balanceAfter }
    }
})
