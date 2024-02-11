#pragma version ^0.3.0

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

# user actions:

event Pay:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

event ClaimRefund:
  user: indexed(address)
  token: indexed(ERC20)
  amount: indexed(uint256)

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

@external
def claimRefund(_token: ERC20, _amount: uint256):
  self.pendingRefund[msg.sender][_token] -= _amount
  assert _token.transfer(msg.sender, _amount), "tfr"
  log ClaimRefund(msg.sender, _token, _amount)
