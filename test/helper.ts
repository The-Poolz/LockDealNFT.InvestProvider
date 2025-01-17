import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { ethers } from "hardhat"

export async function createEIP712Signature(
    poolId: bigint,
    user: string,
    validUntil: number,
    amount: bigint,
    nonce: bigint,
    signer: SignerWithAddress,
    contractAddress: string
): Promise<string> {
    const domain = {
        name: "InvestProvider",
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: contractAddress,
    }
    const types = {
        InvestMessage: [
            { name: "poolId", type: "uint256" },
            { name: "user", type: "address" },
            { name: "amount", type: "uint256" },
            { name: "validUntil", type: "uint256" },
            { name: "nonce", type: "uint256" },
        ],
    }
    const value = {
        poolId: poolId,
        user: user,
        amount: amount.toString(),
        validUntil: validUntil,
        nonce: nonce,
    }

    // Use signTypedData to create the signature
    return await signer.signTypedData(domain, types, value)
}
