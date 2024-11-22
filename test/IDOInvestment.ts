import { VaultManager, InvestProvider } from "../typechain-types"
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
    let investProvider: InvestProvider
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let signer: SignerWithAddress
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    let amount = ethers.parseUnits("100", 18)
    let maxAmount = ethers.parseUnits("1000", 18)
    let validUntil = Math.floor(Date.now() / 1000) + 60 * 60
    let poolId: bigint

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
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        investProvider = await InvestProvider.deploy(
            await lockDealNFT.getAddress(),
            await dispenserProvider.getAddress()
        )
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
        // set trustee
        await vaultManager.setTrustee(await lockDealNFT.getAddress())
        // create vault with token
        await vaultManager["createNewVault(address)"](await token.getAddress())
        // create source pool
        sourcePoolId = await lockDealNFT.totalSupply()
        let nounce = await vaultManager.nonces(owner)
        let tokenAddress = await token.getAddress()
        const params = [amount]
        const addresses = [await signer.getAddress(), tokenAddress]

        poolId = await lockDealNFT.totalSupply()
        await token.approve(await vaultManager.getAddress(), amount)
        const packedData = ethers.solidityPackedKeccak256(
            ["address", "uint256", "uint256"],
            [tokenAddress, amount, nounce]
        )
        const tokenSignature = await owner.signMessage(ethers.getBytes(packedData))
        // create source pool
        await dispenserProvider.connect(owner).createNewPool(addresses, params, tokenSignature)

        await USDT.approve(await investProvider.getAddress(), maxAmount)
        signerAddress = await signer.getAddress()
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        await investProvider.createNewPool(maxAmount, signerAddress, signerAddress, sourcePoolId)
    })

    it("should deacrease left amount after invest", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount / 2n]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await investProvider.invest(poolId, amount / 2n, validUntil, signature)
        const poolData = await investProvider.getParams(poolId)
        expect(poolData[1]).to.equal(maxAmount - amount / 2n)
    })

    it("should emit Invested event", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        const tx = await investProvider.invest(poolId, amount, validUntil, signature)
        await tx.wait()
        const events = await investProvider.queryFilter(investProvider.filters.Invested())
        expect(events[events.length - 1].args.poolId).to.equal(poolId)
        expect(events[events.length - 1].args.user).to.equal(await owner.getAddress())
        expect(events[events.length - 1].args.amount).to.equal(amount)
    })

    // TODO: add transfer ERC20 implementation
    // it("should revert if no allowance", async () => {
    //     const packedData = ethers.solidityPackedKeccak256(
    //         ["uint256", "address", "uint256", "uint256"],
    //         [poolId, await user.getAddress(), validUntil, amount]
    //     )
    //     const signature = await signer.signMessage(ethers.getBytes(packedData))
    //     await expect(
    //         investProvider.connect(user).invest(poolId, amount, validUntil, signature)
    //     ).to.be.revertedWithCustomError(USDT, "ERC20InsufficientAllowance")
    // })

    it("should revert if invested amount is more than left amount", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, maxAmount + 1n]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await expect(
            investProvider.invest(poolId, maxAmount + 1n, validUntil, signature)
        ).to.be.revertedWithCustomError(investProvider, "ExceededLeftAmount")
    })

    it("should revert invalid signature", async () => {
        const packedData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount]
        )
        const signature = await signer.signMessage(ethers.getBytes(packedData))
        await expect(investProvider.invest(poolId, amount, (validUntil += 1), signature)).to.be.revertedWithCustomError(
            investProvider,
            "InvalidSignature"
        )
    })

    it("should revert if call withdraw", async () => {
        //await expect(investProvider.withdraw(poolId)).to.be.reverted
        await expect(
            lockDealNFT
                .connect(signer)
                [
                    "safeTransferFrom(address,address,uint256)"
                ](await signer.getAddress(), await lockDealNFT.getAddress(), poolId)
        ).to.be.reverted
    })
})
