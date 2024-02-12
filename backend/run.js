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
  const testCases = [
    {
      seed: '0x3141592653589793238462643383279502884197169399375105820974944592',
      master_SK: 29757020647961307431480504535336562678282505419141012933316116377660817309383n
    },
    {
      seed: '0xc55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04',
      master_SK: 6083874454709270928345386274498605044986640685124978867557563392430687146096n
    },
    {
      seed: '0x0099FF991111002299DD7744EE3355BBDD8844115566CC55663355668888CC00',
      master_SK: 27580842291869792442942448775674722299803720648445448686099262467207037398656n
    },
    {
      seed: '0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3',
      master_SK: 19022158461524446591288038168518313374041767046816487870552872741050760015818n
    }
  ]
  for (const [i, {seed, master_SK}] of testCases.entries()) {
    const seedBytes = ethers.getBytes(seed)
    const sk = secretKeyFromSeed(seedBytes)
    if (sk == master_SK)
      console.log(`Test case ${i} passed`)
    else {
      console.error(`Test case ${i} failed: Got ${sk} instead of ${master_SK}`)
      process.exit(1)
    }
  }
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
