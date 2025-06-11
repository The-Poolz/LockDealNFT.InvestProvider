import fs from "fs"
import path from "path"
import axios from "axios"
import { exit } from "process"

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
    const cachePath = path.join(__dirname, `../cache/solidity-files-cache.json`)

    if (!fs.existsSync(artifactPath)) {
        console.error(`❌ Artifact not found at ${artifactPath}`)
        return
    }
    if (!fs.existsSync(cachePath)) {
        console.error(`❌ Cache not found at ${cachePath}`)
        return
    }

    // Read artifact JSON (has ABI, bytecode, metadata)
    const artifactRaw = fs.readFileSync(artifactPath, "utf8")
    const artifact = JSON.parse(artifactRaw)
    const { abi, bytecode } = artifact

    // Read cache JSON to get compiler settings
    const cacheRaw = fs.readFileSync(cachePath, "utf8")
    const cacheJson = JSON.parse(cacheRaw)

    // Find the cache file entry that corresponds to this contract's source file
    // We look for a key in cacheJson.files that ends with the contract's source file name
    const sourceFileName = `${CONTRACT_NAME}.sol`
    const cacheFileEntryKey = Object.keys(cacheJson.files || {}).find((filePath) => filePath.endsWith(sourceFileName))

    if (!cacheFileEntryKey) {
        console.error(`❌ Source file ${sourceFileName} not found in cache files`)
        return
    }

    const solcConfig = cacheJson.files[cacheFileEntryKey].solcConfig
    const compilerSettings = {
        supported_pragma_version: solcConfig?.version || "unknown",
        optimizerEnabled: solcConfig?.settings?.optimizer?.enabled ?? false,
        runs: solcConfig?.settings?.optimizer?.runs ?? 0,
        viaIR: !!solcConfig?.settings?.viaIR,
    }

    const graphqlEndpoint = STRAPI_API_URL.replace(/\/$/, "") + "/graphql"

    // GraphQL mutation
    const mutation = `
mutation CreateContract($data: ContractInput!) {
  createContract(data: $data) {
    NameVersion
    ABI
    ByteCode
    ReleaseNotes
    GitLink
    CompilerSetting {
      optimizerEnabled
      runs
      viaIR
    }
  }
}
`

    const variables = {
        data: {
            NameVersion: `${CONTRACT_NAME}@${RELEASE_VERSION}`,
            ABI: abi,
            ByteCode: { bytecode: bytecode },
            ReleaseNotes: "Initial release",
            GitLink: GIT_LINK,
            CompilerSetting: compilerSettings,
            // Optionally add publishedAt, e.g., new Date().toISOString()
            // publishedAt: new Date().toISOString(),
        },
    }

    try {
        const res = await axios.post(
            graphqlEndpoint,
            {
                query: mutation,
                variables,
            },
            {
                headers: {
                    Authorization: `Bearer ${STRAPI_TOKEN}`,
                    "Content-Type": "application/json",
                },
            }
        )

        if (res.data.errors) {
            console.error("❌ GraphQL errors:", res.data.errors)
            return
        }

        console.log("✅ Contract uploaded to Strapi:", res.data.data.createContract)
    } catch (error) {
        if (axios.isAxiosError(error)) {
            console.error("❌ Axios error:", error.response?.data || error.message)
        } else {
            console.error("❌ Unexpected error:", error)
        }
    }
}

main()
