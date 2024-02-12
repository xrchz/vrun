import 'dotenv/config'
import { createHash, hkdfSync, randomBytes } from 'node:crypto'
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs'
import { ethers } from 'ethers'

const chainId = parseInt(process.env.CHAIN) || 1

// ERC-2333

const sha256 = (m) => createHash('sha256').update(m).digest()
const r = 52435875175126190479447740508185965837690552500527637822603658699938581184513n

function OS2IP(a) {
  let result = 0n
  let m = 1n
  for (const x of a.toReversed()) {
    result += BigInt(x) * m
    m *= 256n
  }
  return result
}

const L = 48
const L2 = Uint8Array.from([0, L])
function secretKeyFromSeed(seed) {
  const seed0 = new Uint8Array(seed.length + 1)
  seed0.set(seed)
  let salt = "BLS-SIG-KEYGEN-SALT-"
  let SK = 0n
  while (SK == 0n) {
    salt = sha256(salt)
    const OKM = new Uint8Array(hkdfSync('sha256', seed0, salt, L2, L))
    SK = OS2IP(OKM) % r
  }
  return SK
}

// addresses are checksummed (ERC-55) hexstrings with the 0x prefix
// pubkeys are lowercase hexstrings with the 0x prefix
// timestamps are integers representing seconds since UNIX epoch
// contents are utf8 encoded unless otherwise specified
//
// filesystem database layout:
// db/${chainId}/${address}/init : timestamp
// db/${chainId}/${address}/seed : 32 bytes (no encoding)
// db/${chainId}/${address}/${pubkey}/log : JSON lines of log entries
//
// the log is an append-only record of user actions
// log entries have this format:
// { type: "setFeeRecipient" | "setGraffiti" | "setEnabled" | "exit"
// , time: timestamp
// , data: address | string | bool | undefined
// }
//
// environment variables
// CHAIN
// COMMAND
// ADDRESS
// PUBKEY
// DATA

const commands = ["init", "deposit", "setFeeRecipient", "setGraffiti", "setEnabled", "exit", "test"]

if (!commands.includes(process.env.COMMAND)) {
  console.error(`Unrecognised command ${process.env.COMMAND}: should be one of ${commands}.`)
  process.exit(1)
}

if (process.env.COMMAND == 'test') {
  const testSeed = '0xc55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04'
  const seed = ethers.getBytes(testSeed)
  const master_sk = secretKeyFromSeed(seed)
  console.log(`Got master_SK ${master_sk} from test seed`)
  process.exit()
}

const address = ethers.getAddress(process.env.ADDRESS)

if (process.env.COMMAND == 'init') {
  const dirPath = `db/${chainId}/${address}`
  mkdirSync(dirPath, {recursive: true})
  const timestamp = Math.floor(Date.now() / 1000)
  writeFileSync(`${dirPath}/init`, timestamp.toString(), {flag: 'wx'})
  writeFileSync(`${dirPath}/seed`, randomBytes(32), {flag: 'wx'})
  process.exit()
}

else if (process.env.COMMAND == 'deposit') {
  const dirPath = `db/${chainId}/${address}`
  const seed = new Uint8Array(readFileSync(`${dirPath}/seed`))
  const sk = secretKeyFromSeed(seed)

  console.error(`Not implemented yet: ${process.env.COMMAND}`)
  process.exit(1)
}

else {
  console.error(`Not implemented yet: ${process.env.COMMAND}`)
  process.exit(1)
}
