import fs from "fs"
import path from "path"
import axios from "axios"
import { exit } from "process"

// Load environment variables
const STRAPI_API_URL = process.env.STRAPI_API_URL || ""
const STRAPI_TOKEN = process.env.STRAPI_TOKEN
const GIT_LINK = process.env.GIT_LINK || ""
const RELEASE_VERSION = process.env.RELEASE_VERSION || "0.0.0"

if (!STRAPI_API_URL || !STRAPI_TOKEN) {
    console.error("❌ Missing STRAPI_API_URL or STRAPI_TOKEN in environment variables")
    exit(1)
}

const CONTRACT_NAME = "InvestProvider"

async function main() {
    const artifactPath = path.join(__dirname, `../artifacts/contracts/${CONTRACT_NAME}.sol/${CONTRACT_NAME}.json`)
    const metadataPath = path.join(__dirname, `../cache/solidity-files-cache.json`)

    if (!fs.existsSync(artifactPath)) {
        console.error(`❌ Artifact not found at ${artifactPath}`)
        return
    }
    if (!fs.existsSync(metadataPath)) {
        console.error(`❌ Metadata cache not found at ${metadataPath}`)
        return
    }

    // Read the artifact (for abi, bytecode)
    const artifactRaw = fs.readFileSync(artifactPath, "utf8")
    const artifact = JSON.parse(artifactRaw)
    const { abi, bytecode } = artifact

    // Read the solidity-files-cache.json
    const cacheRaw = fs.readFileSync(metadataPath, "utf8")
    const cacheJson = JSON.parse(cacheRaw)

    // Type assertion: output.contracts is a nested record
    type ContractMetadata = { metadata: string }
    const outputContracts = (cacheJson.output?.contracts ?? {}) as Record<string, Record<string, ContractMetadata>>

    // Find the contract metadata by filename and contract name
    const contractCacheEntry = Object.entries(outputContracts).find(([file, contracts]) => {
        return file.endsWith(`${CONTRACT_NAME}.sol`) && contracts[CONTRACT_NAME] !== undefined
    })

    if (!contractCacheEntry) {
        console.error(`❌ Metadata for ${CONTRACT_NAME} not found in solidity-files-cache.json`)
        return
    }

    const [, contractsObj] = contractCacheEntry
    const contractMetadataRaw = contractsObj[CONTRACT_NAME].metadata
    if (!contractMetadataRaw) {
        console.error(`❌ Missing metadata JSON string in solidity-files-cache.json for contract ${CONTRACT_NAME}`)
        return
    }

    let parsedMetadata: any
    try {
        parsedMetadata = JSON.parse(contractMetadataRaw)
    } catch (e) {
        console.error("❌ Failed to parse metadata JSON:", e)
        return
    }

    const compilerSettings = {
        evm_version: parsedMetadata.settings?.evmVersion || "default",
        supported_pragma_version: parsedMetadata.compiler?.version || "unknown",
        optimizerEnabled: parsedMetadata.settings?.optimizer?.enabled ?? false,
        runs: parsedMetadata.settings?.optimizer?.runs ?? 0,
        viaIR: !!parsedMetadata.settings?.viaIR,
    }

    const payload = {
        data: {
            NameVersion: `${CONTRACT_NAME}@${RELEASE_VERSION}`,
            ABI: abi,
            ByteCode: bytecode,
            ReleaseNotes: "Initial release",
            GitLink: GIT_LINK,
            CompilerSetting: compilerSettings,
        },
    }

    try {
        const res = await axios.post(STRAPI_API_URL, payload, {
            headers: {
                Authorization: `Bearer ${STRAPI_TOKEN}`,
                "Content-Type": "application/json",
            },
        })

        console.log("✅ Contract uploaded to Strapi:", res.data)
    } catch (err: any) {
        console.error("❌ Failed to upload to Strapi:", err.response?.data || err.message)
    }
}

main()
