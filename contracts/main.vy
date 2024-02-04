#pragma version ^0.3.0

MAX_GRAFFITI_LENGTH: constant(uint256) = 32
MAX_ENCRYPTED_KEY_BYTES: constant(uint256) = 256
PUBKEY_BYTES: constant(uint256) = 48

interface ERC20:
 def transfer(_to: address, _value: uint256) -> bool: nonpayable
 def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

interface WETH:
  def deposit(): payable

# configuration state:

admin: public(address)
weth: public(immutable(WETH))
acceptedTokens: public(HashMap[ERC20, bool])

@external
def __init__(_weth: address):
  weth = WETH(_weth)
  self.acceptedTokens[ERC20(_weth)] = True
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

paid: public(HashMap[address, HashMap[ERC20, uint256]])
charged: public(HashMap[address, HashMap[ERC20, uint256]])
pendingRefund: public(HashMap[address, HashMap[ERC20, uint256]])

# admin actions:

event SetAdmin:
  old: indexed(address)
  new: indexed(address)

event SetToken:
  token: indexed(ERC20)
  accepted: indexed(bool)

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
  pubkey: indexed(Bytes[PUBKEY_BYTES])

@external
def setAdmin(_newAdmin: address):
  assert msg.sender == self.admin, "auth"
  self.admin = _newAdmin
  log SetAdmin(msg.sender, _newAdmin)

@external
def setToken(_token: ERC20, _accepted: bool):
  assert msg.sender == self.admin, "auth"
  self.acceptedTokens[_token] = _accepted
  log SetToken(_token, _accepted)

@external
def withdraw(_token: ERC20, _amount: uint256):
  assert msg.sender == self.admin, "auth"
  assert _token.transfer(msg.sender, _amount), "tfr"
  log Withdraw(_token, _amount)

@external
def charge(_user: address, _token: ERC20, _amount: uint256):
  assert msg.sender == self.admin, "auth"
  self.charged[_user][_token] += _amount
  log Charge(_user, _token, _amount)

@external
def refund(_user: address, _token: ERC20, _amount: uint256):
  assert msg.sender == self.admin, "auth"
  self.pendingRefund[_user][_token] += _amount
  log Refund(_user, _token, _amount)

@external
def confirmKey(_pubkey: Bytes[PUBKEY_BYTES], _user: address):
  assert msg.sender == self.admin, "auth"
  self.validators[_pubkey].claimedBy = _user
  log ClaimKey(_user, _pubkey)

# user actions:

event SubmitKey:
  user: indexed(address)
  pubkey: indexed(Bytes[PUBKEY_BYTES])
  privkey: Bytes[MAX_ENCRYPTED_KEY_BYTES]

event SetEnabled:
  pubkey: indexed(Bytes[PUBKEY_BYTES])
  enabled: indexed(bool)

event SetGraffiti:
  pubkey: indexed(Bytes[PUBKEY_BYTES])
  graffiti: String[MAX_GRAFFITI_LENGTH]

event SetFeeRecipient:
  pubkey: indexed(Bytes[PUBKEY_BYTES])
  feeRecipient: indexed(address)

event SetFeeToken:
  pubkey: indexed(Bytes[PUBKEY_BYTES])
  feeToken: indexed(ERC20)

event Exit:
  pubkey: indexed(Bytes[PUBKEY_BYTES])

event ClaimRefund:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

event Pay:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

@external
def submitKey(_pubkey: Bytes[PUBKEY_BYTES], _privkey: Bytes[MAX_ENCRYPTED_KEY_BYTES],
              _v: uint256, _r: bytes32, _s: bytes32):
  assert ecrecover(keccak256(_privkey), _v, _r, _s) == msg.sender, "sig"
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
def setFeeToken(_pubkey: Bytes[PUBKEY_BYTES], _token: ERC20):
  assert self.validators[_pubkey].claimedBy == msg.sender, "auth"
  assert self.acceptedTokens[_token], "token"
  self.validators[_pubkey].feeToken = _token
  log SetFeeToken(_pubkey, _token)

@external
def exit(_pubkey: Bytes[PUBKEY_BYTES]):
  assert self.validators[_pubkey].claimedBy == msg.sender, "auth"
  self.validators[_pubkey].exited = True
  log Exit(_pubkey)

@external
def claimRefund(_token: ERC20, _amount: uint256):
  self.pendingRefund[msg.sender][_token] -= _amount
  assert _token.transfer(msg.sender, _amount), "tfr"
  log ClaimRefund(msg.sender, _token, _amount)

@external
def payToken(_token: ERC20, _amount: uint256):
  assert self.acceptedTokens[_token], "token"
  assert _token.transferFrom(msg.sender, self, _amount), "tfr"
  self.paid[msg.sender][_token] += _amount
  log Pay(msg.sender, _token, _amount)

@external
@payable
def payEther():
  weth.deposit(value = msg.value)
  self.paid[msg.sender][ERC20(weth.address)] += msg.value
  log Pay(msg.sender, ERC20(weth.address), msg.value)
