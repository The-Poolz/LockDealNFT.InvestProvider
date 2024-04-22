import { InvestProvider } from "../typechain-types/"
import { MockVaultManager } from "../typechain-types"
import { expect } from "chai"
import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import LockDealNFTArtifact from "@poolzfinance/lockdeal-nft/artifacts/contracts/LockDealNFT/LockDealNFT.sol/LockDealNFT.json"

describe("InvestProvider", function () {
    let token: ERC20Token
    let mockVaultManager: MockVaultManager
    let owner: SignerWithAddress
    let user: SignerWithAddress
    let lockDealNFT: Contract

    before(async () => {
        [owner, user] = await ethers.getSigners()
        const Token = await ethers.getContractFactory("ERC20Token")
        token = await Token.deploy("TEST", "test")
        const LockDealNFT = await ethers.getContractFactory(LockDealNFTArtifact.abi, LockDealNFTArtifact.bytecode)
        lockDealNFT = await LockDealNFT.deploy(await mockVaultManager.getAddress(), "")
    })

    beforeEach(async () => {})
})
