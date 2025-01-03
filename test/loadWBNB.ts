import axios from "axios"

interface WETH10Artifact {
    abi: string
    bytecode: string
    address: string
}

export async function loadWBNBArtifact(): Promise<WETH10Artifact> {
    const url = "https://raw.githubusercontent.com/WETH10/WETH10/main/deployments/mainnet/WETH10.json"

    try {
        const response = await axios.get(url)
        const artifact = response.data as WETH10Artifact
        return artifact
    } catch (error) {
        console.error("Error loading artifact:", error)
        throw error
    }
}
