import { VaultManager, InvestProvider, DispenserProvider } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO split tests", function () {
    let token: ERC20Token
    let USDT: ERC20Token
    let sourcePoolId: bigint
    let vaultManager: VaultManager
    let investProvider: InvestProvider
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let signer: SignerWithAddress
    let dispenserProvider: DispenserProvider
    let signerAddress: string
    let lockDealNFT: LockDealNFT
    const amount = ethers.parseUnits("100", 18)
    const maxAmount = ethers.parseUnits("1000", 18)
    let poolId: bigint
    let ratio: bigint
    let packedData: string
    let vaultId: bigint
    let investData: string
    let signature: string
    const validUntil = Math.floor(Date.now() / 1000) + 60 * 60

    before(async () => {
        [owner, user, signer] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        USDT = await Token.deploy("USDT", "USDT")
        const LockDealNFTFactory = await ethers.getContractFactory("LockDealNFT")
        vaultManager = await (await ethers.getContractFactory("VaultManager")).deploy()
        lockDealNFT = (await LockDealNFTFactory.deploy(await vaultManager.getAddress(), "")) as LockDealNFT
        const DispenserProvider = await ethers.getContractFactory("DispenserProvider")
        dispenserProvider = await DispenserProvider.deploy(await lockDealNFT.getAddress())
        const InvestProvider = await ethers.getContractFactory("InvestProvider")
        investProvider = await InvestProvider.deploy(
            await lockDealNFT.getAddress(),
            await dispenserProvider.getAddress()
        )
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
        // set trustee
        await vaultManager.setTrustee(await lockDealNFT.getAddress())
        // create vaults with token and USDT
        await vaultManager["createNewVault(address)"](await token.getAddress())
        await vaultManager["createNewVault(address)"](await USDT.getAddress())
        // create source pool
        let nounce = await vaultManager.nonces(await owner.getAddress())
        const tokenAddress = await token.getAddress()

        await token.approve(await vaultManager.getAddress(), amount)
        const tokenPackedData = ethers.solidityPackedKeccak256(
            ["address", "uint256", "uint256"],
            [tokenAddress, amount, nounce]
        )
        const tokenSignature = await owner.signMessage(ethers.getBytes(tokenPackedData))
        // create token pool
        await dispenserProvider.createNewPool(
            [await user.getAddress(), await token.getAddress()],
            [amount],
            tokenSignature
        )
        await USDT.approve(await vaultManager.getAddress(), maxAmount)
        nounce = await vaultManager.nonces(await owner.getAddress())
        const usdtPackedData = ethers.solidityPackedKeccak256(
            ["address", "uint256", "uint256"],
            [await USDT.getAddress(), amount, nounce]
        )
        const usdtSignature = await owner.signMessage(ethers.getBytes(usdtPackedData))
        sourcePoolId = await lockDealNFT.totalSupply()
        // create USDT pool
        await dispenserProvider
            .connect(owner)
            .createNewPool([await user.getAddress(), await USDT.getAddress()], [amount], usdtSignature)

        ratio = ethers.parseUnits("1", 21) / 2n // half of the amount
        await lockDealNFT.approvePoolTransfers(true)
        await lockDealNFT.connect(signer).approvePoolTransfers(true)
        packedData = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "address"], [ratio, await owner.getAddress()])
        signerAddress = await signer.getAddress()
        vaultId = await vaultManager.getCurrentVaultIdByToken(await USDT.getAddress())
    })

    beforeEach(async () => {
        poolId = await lockDealNFT.totalSupply()
        const nonce = await investProvider["getNonce(uint256)"](poolId)
        await investProvider["createNewPool(uint256,address,address,uint256)"](maxAmount, signer, signer, sourcePoolId)
        investData = ethers.solidityPackedKeccak256(
            ["uint256", "address", "uint256", "uint256", "uint256"],
            [poolId, await owner.getAddress(), validUntil, amount, nonce]
        )
        signature = await signer.signMessage(ethers.getBytes(investData))
    })

    it("should update old pool data after split", async () => {
        await lockDealNFT
            .connect(signer)[
                "safeTransferFrom(address,address,uint256,bytes)"
            ](signerAddress, await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(poolId)
        expect(data).to.deep.equal([
            await investProvider.getAddress(),
            "InvestProvider",
            poolId,
            vaultId,
            await signer.getAddress(),
            await USDT.getAddress(),
            [maxAmount / 2n, maxAmount / 2n],
        ])
    })

    it("should create new pool after split", async () => {
        await lockDealNFT
            .connect(signer)[
                "safeTransferFrom(address,address,uint256,bytes)"
            ](signerAddress, await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(poolId + 2n)
        expect(data).to.deep.equal([
            await investProvider.getAddress(),
            "InvestProvider",
            poolId + 2n,
            vaultId,
            await owner.getAddress(),
            await USDT.getAddress(),
            [maxAmount / 2n, maxAmount / 2n],
        ])
    })

    it("should emit PoolSplit event", async () => {
        const tx = await lockDealNFT
            .connect(signer)[
                "safeTransferFrom(address,address,uint256,bytes)"
            ](signerAddress, await lockDealNFT.getAddress(), poolId, packedData)
        await tx.wait()
        const event = await lockDealNFT.queryFilter(lockDealNFT.filters.PoolSplit())
        const data = event[event.length - 1].args
        expect(data.poolId).to.equal(poolId)
        expect(data.newPoolId).to.equal(poolId + 2n)
        expect(data.owner).to.equal(signerAddress)
        expect(data.newOwner).to.equal(await owner.getAddress())
        expect(data.splitLeftAmount).to.equal(maxAmount / 2n)
        expect(data.newSplitLeftAmount).to.equal(maxAmount / 2n)
    })

    it("should revert invalid ratio", async () => {
        const ratio = ethers.parseUnits("2", 21)
        const packedData = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "address"], [ratio, await user.getAddress()])
        await expect(
            lockDealNFT
                .connect(signer)[
                    "safeTransferFrom(address,address,uint256,bytes)"
                ](signerAddress, await lockDealNFT.getAddress(), poolId, packedData)
        ).to.be.revertedWith("split amount exceeded")
    })

    it("should mint dispenser provider after split", async () => {
        await lockDealNFT
            .connect(signer)[
                "safeTransferFrom(address,address,uint256,bytes)"
            ](signerAddress, await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(poolId + 3n)
        expect(data).to.deep.equal([
            await dispenserProvider.getAddress(),
            "DispenserProvider",
            poolId + 3n,
            vaultId,
            await signer.getAddress(),
            await USDT.getAddress(),
            [0],
        ])
    })

    it("should not update the old dispenser amount after the split", async () => {
        await USDT.approve(await investProvider.getAddress(), amount)
        await investProvider.invest(poolId, amount, validUntil, signature)
        await lockDealNFT
            .connect(signer)[
                "safeTransferFrom(address,address,uint256,bytes)"
            ](signerAddress, await lockDealNFT.getAddress(), poolId, packedData)
        const data = await lockDealNFT.getData(poolId + 1n)
        expect(data).to.deep.equal([
            await dispenserProvider.getAddress(),
            "DispenserProvider",
            poolId + 1n,
            vaultId,
            await signer.getAddress(),
            await USDT.getAddress(),
            [amount],
        ])
    })
})
