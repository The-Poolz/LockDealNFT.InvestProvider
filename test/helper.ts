import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import { IDispenserProvider } from "../typechain-types/contracts/DispenserProvider"
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

// Function to create EIP-712 signature using signTypedData
export async function createDispenserEIP712Signature(
    poolId: bigint,
    receiver: string,
    validUntil: number,
    signer: SignerWithAddress,
    contractAddress: string,
    data: IDispenserProvider.BuilderStruct[]
): Promise<string> {
    const domain = {
        name: "DispenserProvider",
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: contractAddress,
    }
    const types = {
        Builder: [
            { name: "simpleProvider", type: "address" },
            { name: "params", type: "uint256[]" },
        ],
        MessageStruct: [
            { name: "poolId", type: "uint256" },
            { name: "receiver", type: "address" },
            { name: "validUntil", type: "uint256" },
            { name: "data", type: "Builder[]" },
        ],
    }
    const value = {
        poolId: poolId.toString(),
        receiver: receiver,
        validUntil: validUntil,
        data: data,
    }

    // Use signTypedData to create the signature
    return await signer.signTypedData(domain, types, value)
}
