import { VaultManager, InvestWrapped, IWBNB, DispenserProvider } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"
import { loadWBNBArtifact } from "./loadWBNB"

describe("IDO with wrapped tokens", function () {
    let token: ERC20Token
    let vaultManager: VaultManager
    let investWrapped: InvestWrapped
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
        ;[owner, signer] = await ethers.getSigners()
        await deployContracts()
        await setupInitialConditions()
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        signature = await createInvestPool()
    })

    it("should create wrapped token invest pool", async () => {
        expect(await lockDealNFT.tokenOf(poolId)).to.equal(await wBNB.getAddress())
    })

    it("should decrease left amount after wrapped token invest", async () => {
        await investWrapped.invest(poolId, amount, validUntil, signature, { value: amount })
        const poolData = await investWrapped.getParams(poolId)
        expect(poolData[1]).to.equal(maxAmount - amount)
    })

    it("should emit Invested event after wrapped token invest", async () => {
        const tx = await investWrapped.invest(poolId, amount, validUntil, signature, { value: amount })
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
        await investWrapped.invest(poolId, amount, validUntil, signature, { value: amount })
        expect(await wBNB.balanceOf(vault)).to.equal(balanceBefore + amount)
    })

    it("should handle regular tokens if not wrapped", async () => {
        sourcePoolId = await createSourcePool()
        signature = await createInvestPool("createNewPool")
        const { balanceBefore, balanceAfter } = await investInPool({ poolId, amount, validUntil, signature })
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
            investWrapped.invest(poolId, amount, validUntil, signature, { value: 0 })
        ).to.be.revertedWithCustomError(investWrapped, "NoZeroAmount")
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

        const InvestWrapped = await ethers.getContractFactory("InvestWrapped")
        investWrapped = await InvestWrapped.deploy(await lockDealNFT.getAddress(), await dispenserProvider.getAddress())
    }

    async function setupInitialConditions() {
        await lockDealNFT.setApprovedContract(await investWrapped.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
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

    async function createInvestPool(functionName = "createNewETHPool"): Promise<string> {
        poolId = await lockDealNFT.totalSupply()
        const method = functionName + "(uint256,address,address,uint256)"
        await investWrapped[method](maxAmount, signerAddress, signerAddress, sourcePoolId)
        const nonce = await investWrapped.getNonce(poolId, await owner.getAddress())
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount, nonce]
        )
        return signer.signMessage(ethers.getBytes(packedData))
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
    }: {
        poolId: bigint
        amount: bigint
        validUntil: number
        signature: string
    }): Promise<{ balanceBefore: bigint; balanceAfter: bigint }> {
        await token.approve(await investWrapped.getAddress(), amount)

        const vaultId = await vaultManager.getCurrentVaultIdByToken(await token.getAddress())
        const balanceBefore = await token.balanceOf(await vaultManager.vaultIdToVault(vaultId))

        await investWrapped.invest(poolId, amount, validUntil, signature)

        const vault = await vaultManager.vaultIdToVault(vaultId)
        const balanceAfter = await token.balanceOf(vault)

        return { balanceBefore, balanceAfter }
    }
})
