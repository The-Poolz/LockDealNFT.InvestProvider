import { VaultManager, InvestWrappedProvider, IWBNB } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"
import WBNBArtifact from "./WBNB/WBNB.json"

describe("IDO with wrapped tokens", function () {
    let token: ERC20Token
    let sourcePoolId: bigint
    let vaultManager: VaultManager
    let investWrapped: InvestWrappedProvider
    let owner: SignerWithAddress
    let signer: SignerWithAddress
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    const amount = ethers.parseUnits("10", 18)
    const maxAmount = ethers.parseUnits("1000", 18)
    const validUntil = Math.floor(Date.now() / 1000) + 60 * 60 // 1 hour
    let poolId: bigint
    let packedData: string
    let signature: string
    let wBNB: IWBNB

    before(async () => {
        [owner, signer] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        const WBNB = await ethers.getContractFactory(WBNBArtifact.abi, WBNBArtifact.bytecode)
        wBNB = (await WBNB.deploy()) as IWBNB
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        vaultManager = await (await ethers.getContractFactory("VaultManager")).deploy()
        lockDealNFT = (await LockDealNFTFactory.deploy(await vaultManager.getAddress(), "")) as LockDealNFT
        const DispenserProvider = await ethers.getContractFactory("DispenserProvider")
        const dispenserProvider = await DispenserProvider.deploy(await lockDealNFT.getAddress())
        const InvestWrapped = await ethers.getContractFactory("InvestWrappedProvider")
        investWrapped = await InvestWrapped.deploy(
            await lockDealNFT.getAddress(),
            await dispenserProvider.getAddress()
        )
        await lockDealNFT.setApprovedContract(await investWrapped.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
        // set trustee
        await vaultManager.setTrustee(await lockDealNFT.getAddress())
        // create vault with token
        const tokenAddress = await wBNB.getAddress()
        await vaultManager["createNewVault(address)"](tokenAddress)
        // create source pool
        sourcePoolId = await lockDealNFT.totalSupply()
        const nounce = await vaultManager.nonces(owner)
        const params = [amount]
        const addresses = [await signer.getAddress(), tokenAddress]
        await wBNB.approve(await vaultManager.getAddress(), amount)
        const packedData = ethers.solidityPackedKeccak256(
            ["address", "uint256", "uint256"],
            [tokenAddress, amount, nounce]
        )
        const tokenSignature = await owner.signMessage(ethers.getBytes(packedData))
        // create source pool
        // wrap some tokens
        await wBNB.deposit({ value: amount })
        await dispenserProvider.connect(owner).createNewPool(addresses, params, tokenSignature)

        await token.approve(await investWrapped.getAddress(), maxAmount)
        await wBNB.approve(await investWrapped.getAddress(), maxAmount)
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investWrapped.createNewETHPool(maxAmount, signerAddress, signerAddress, sourcePoolId)
        const nonce = await investWrapped.getNonce(poolId, await owner.getAddress())
        packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount, nonce]
        )
        signature = await signer.signMessage(ethers.getBytes(packedData))
    })

    it("should create wrapped token invest pool", async () => {
        expect(await lockDealNFT.tokenOf(poolId)).to.be.equal(await wBNB.getAddress())
    })

    it("should deacrease left amount after wrapped token invest", async () => {
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
})
