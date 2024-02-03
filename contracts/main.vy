#pragma version ^0.3.0

MAX_GRAFFITI_LENGTH: constant(uint256) = 32
NUM_ACCEPTED_TOKENS: constant(uint256) = 8
MAX_ENCRYPTED_KEY_BYTES: constant(uint256) = 64
PUBKEY_BYTES: constant(uint256) = 48

interface ERC20:
 def transfer(_to: address, _value: uint256) -> bool: nonpayable
 def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

interface WETH:
  def deposit(): payable

# configuration state:

admin: public(address)
# the first token is assumed to be WETH
acceptedTokens: immutable(address[NUM_ACCEPTED_TOKENS])

@external
def __init__(tokens: address[NUM_ACCEPTED_TOKENS]):
  acceptedTokens = tokens
  self.admin = msg.sender

# state:

struct Validator:
  claimedBy: address
  enabled: bool
  exited: bool
  graffiti: String[MAX_GRAFFITI_LENGTH]
  feeRecipient: address
  feeToken: ERC20

validators: public(HashMap[Bytes[PUBKEY_BYTES], Validator])

struct User:
  paid: uint256[NUM_ACCEPTED_TOKENS]
  charged: uint256[NUM_ACCEPTED_TOKENS]
  pendingRefund: uint256[NUM_ACCEPTED_TOKENS]

users: public(HashMap[address, User])

# admin actions:

event SetAdmin:
  old: indexed(address)
  new: indexed(address)

event Withdraw:
  token: indexed(ERC20)
  amount: indexed(uint256)

event Charge:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

event Refund:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

event ClaimKey:
  user: indexed(address)
  pubkey: Bytes[PUBKEY_BYTES]

@external
def setAdmin(_newAdmin: address):
  assert msg.sender == self.admin, "auth"
  self.admin = _newAdmin
  log SetAdmin(msg.sender, _newAdmin)

@external
def withdraw(_tokenIndex: uint256, _amount: uint256):
  assert msg.sender == self.admin, "auth"
  token: ERC20 = ERC20(acceptedTokens[_tokenIndex])
  assert token.transfer(msg.sender, _amount), "tfr"
  log Withdraw(token, _amount)

@external
def charge(_user: address, _tokenIndex: uint256, _amount: uint256):
  assert msg.sender == self.admin, "auth"
  self.users[_user].charged[_tokenIndex] += _amount
  log Charge(_user, ERC20(acceptedTokens[_tokenIndex]), _amount)

@external
def refund(_user: address, _tokenIndex: uint256, _amount: uint256):
  assert msg.sender == self.admin, "auth"
  self.users[_user].pendingRefund[_tokenIndex] += _amount
  log Refund(_user, ERC20(acceptedTokens[_tokenIndex]), _amount)

@external
def confirmKey(_pubkey: Bytes[PUBKEY_BYTES], _user: address):
  assert msg.sender == self.admin, "auth"
  self.validators[_pubkey].claimedBy = _user
  log ClaimKey(_user, _pubkey)

# user actions:

event SubmitKey:
  user: indexed(address)
  pubkey: Bytes[PUBKEY_BYTES]
  privkey: Bytes[MAX_ENCRYPTED_KEY_BYTES]

event SetEnabled:
  pubkey: Bytes[PUBKEY_BYTES]
  enabled: indexed(bool)

event SetGraffiti:
  pubkey: Bytes[PUBKEY_BYTES]
  graffiti: String[MAX_GRAFFITI_LENGTH]

event SetFeeRecipient:
  pubkey: Bytes[PUBKEY_BYTES]
  feeRecipient: indexed(address)

event SetFeeToken:
  pubkey: Bytes[PUBKEY_BYTES]
  feeToken: indexed(ERC20)

event Exit:
  pubkey: Bytes[PUBKEY_BYTES]

event ClaimRefund:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

event Pay:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

@external
def submitKey(_pubkey: Bytes[PUBKEY_BYTES], _privkey: Bytes[MAX_ENCRYPTED_KEY_BYTES]):
  log SubmitKey(msg.sender, _pubkey, _privkey)

@external
def setEnabled(_pubkey: Bytes[PUBKEY_BYTES], _enabled: bool):
  assert self.validators[_pubkey].claimedBy == msg.sender, "auth"
  self.validators[_pubkey].enabled = _enabled
  log SetEnabled(_pubkey, _enabled)

@external
def setGraffiti(_pubkey: Bytes[PUBKEY_BYTES], _graffiti: String[MAX_GRAFFITI_LENGTH]):
  assert self.validators[_pubkey].claimedBy == msg.sender, "auth"
  self.validators[_pubkey].graffiti = _graffiti
  log SetGraffiti(_pubkey, _graffiti)

@external
def setFeeRecipient(_pubkey: Bytes[PUBKEY_BYTES], _feeRecipient: address):
  assert self.validators[_pubkey].claimedBy == msg.sender, "auth"
  self.validators[_pubkey].feeRecipient = _feeRecipient
  log SetFeeRecipient(_pubkey, _feeRecipient)

@external
def setFeeToken(_pubkey: Bytes[PUBKEY_BYTES], _tokenIndex: uint256):
  assert self.validators[_pubkey].claimedBy == msg.sender, "auth"
  token: ERC20 = ERC20(acceptedTokens[_tokenIndex])
  self.validators[_pubkey].feeToken = token
  log SetFeeToken(_pubkey, token)

@external
def exit(_pubkey: Bytes[PUBKEY_BYTES]):
  assert self.validators[_pubkey].claimedBy == msg.sender, "auth"
  self.validators[_pubkey].exited = True
  log Exit(_pubkey)

@external
def claimRefund(_tokenIndex: uint256, _amount: uint256):
  token: ERC20 = ERC20(acceptedTokens[_tokenIndex])
  self.users[msg.sender].pendingRefund[_tokenIndex] -= _amount
  assert token.transfer(msg.sender, _amount), "tfr"
  log ClaimRefund(msg.sender, token, _amount)

@external
def payToken(_tokenIndex: uint256, _amount: uint256):
  token: ERC20 = ERC20(acceptedTokens[_tokenIndex])
  assert token.transferFrom(msg.sender, self, _amount), "tfr"
  self.users[msg.sender].paid[_tokenIndex] += _amount
  log Pay(msg.sender, token, _amount)

@external
@payable
def payEther():
  WETH(acceptedTokens[0]).deposit(value = msg.value)
  self.users[msg.sender].paid[0] += msg.value
  log Pay(msg.sender, ERC20(acceptedTokens[0]), msg.value)
