import { VaultManager, InvestProvider } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { LockDealNFT } from "../typechain-types/@poolzfinance/lockdeal-nft/contracts/LockDealNFT/LockDealNFT"
import { ERC20Token } from "../typechain-types/contracts/mocks/ERC20Token"

describe("IDO data tests", function () {
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
    const maxAmount = ethers.parseUnits("1000", 18)
    const amount = ethers.parseUnits("100", 18)
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
        investProvider = await InvestProvider.deploy(await lockDealNFT.getAddress(), await dispenserProvider.getAddress())
        await lockDealNFT.setApprovedContract(await investProvider.getAddress(), true)
        await lockDealNFT.setApprovedContract(await dispenserProvider.getAddress(), true)
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
        await investProvider.createNewPool(maxAmount, signer, signer, sourcePoolId)
    })

    it("should return currentParamsTargetLength", async () => {
        expect(await investProvider.currentParamsTargetLength()).to.equal(2)
    })

    it("should return getSubProvidersPoolIds", async () => {
        expect(await investProvider.getSubProvidersPoolIds(poolId)).to.deep.equal([poolId + 1n])
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
