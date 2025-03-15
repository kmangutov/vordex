import subprocess
import json
import time
import os
from dotenv import load_dotenv
from web3 import Web3
from eth_account import Account

# Load environment variables from .env
load_dotenv()

# ---------------- Configuration ----------------
RPC_URL = os.getenv("RPC_URL")
PRIVATE_KEY_SELLER = os.getenv("PRIVATE_KEY_SELLER")
PRIVATE_KEY_BUYER = os.getenv("PRIVATE_KEY_BUYER")

SELLER = Account.from_key(PRIVATE_KEY_SELLER).address
BUYER = Account.from_key(PRIVATE_KEY_BUYER).address

WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

# Ensure paths are relative to the monorepo
VORDEX_PATH = "../vordex"  # Adjust if needed

# ---------------- Helper Functions ----------------
w3 = Web3(Web3.HTTPProvider(RPC_URL))

def run_command(command):
    """Executes a shell command and logs output"""
    print(f"\nRunning: {command}")
    result = subprocess.run(command, shell=True, capture_output=True, text=True, cwd=VORDEX_PATH)
    print(result.stdout)
    if result.stderr:
        print(f"Error: {result.stderr}")
    return result.stdout.strip()

def send_tx(txn, private_key):
    """Signs and sends a transaction"""
    signed_txn = w3.eth.account.sign_transaction(txn, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    return w3.to_hex(tx_hash)

# ---------------- Step 1: Start Anvil ----------------
print("Starting Anvil...")
subprocess.Popen(["anvil"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(3)  # Wait for Anvil to fully start

# ---------------- Step 2: Deploy Contract ----------------
print("Deploying CoveredCallEscrow...")
deploy_output = run_command(f"forge create src/CoveredCallEscrow.sol:CoveredCallEscrow --rpc-url {RPC_URL} --private-key {PRIVATE_KEY_SELLER} --json --root {VORDEX_PATH}")
try:
    deploy_data = json.loads(deploy_output)
    CONTRACT_ADDRESS = deploy_data['deployedTo']
    print(f"✅ Contract deployed at: {CONTRACT_ADDRESS}")
except json.JSONDecodeError:
    print("❌ Failed to parse contract deployment output. Check the error above.")
    exit(1)

# ---------------- Step 3: Fund Accounts ----------------
print("Funding accounts with WETH and USDC...")

# Mint WETH for Seller
run_command(f'cast send {WETH} "deposit()" --value 10ether --rpc-url {RPC_URL} --private-key {PRIVATE_KEY_SELLER}')

# Mint USDC for Buyer
run_command(f'cast send {USDC} "mint(address,uint256)" {BUYER} 1000000000 --rpc-url {RPC_URL} --private-key {PRIVATE_KEY_SELLER}')

# ---------------- Step 4: Covered Call Workflow ----------------
# Load ABI
ABI_PATH = os.path.join(VORDEX_PATH, "out", "CoveredCallEscrow.sol", "CoveredCallEscrow.json")
if not os.path.exists(ABI_PATH):
    print(f"❌ ABI file not found at {ABI_PATH}. Ensure `forge build` runs successfully.")
    exit(1)

with open(ABI_PATH, "r") as abi_file:
    contract_abi = json.load(abi_file)["abi"]

contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=contract_abi)

# 4.1 Create a Covered Call
print("Creating Covered Call...")
tx = contract.functions.createCall(3000000000, int(time.time()) + 600, 10**18).build_transaction({
    "from": SELLER,
    "gas": 3000000,
    "nonce": w3.eth.get_transaction_count(SELLER)
})
tx_hash = send_tx(tx, PRIVATE_KEY_SELLER)
print(f"✅ Call Created! TX: {tx_hash}")

# 4.2 Lock the Call
time.sleep(5)
print("Buyer locking call...")
tx = contract.functions.lockCall(0, 5000000).build_transaction({
    "from": BUYER,
    "gas": 3000000,
    "nonce": w3.eth.get_transaction_count(BUYER)
})
tx_hash = send_tx(tx, PRIVATE_KEY_BUYER)
print(f"✅ Call Locked! TX: {tx_hash}")

# 4.3 Check the Call State
time.sleep(5)
call_details = contract.functions.calls(0).call()
print(f"📌 Call State: {call_details}")

# 4.4 Exercise the Call (if ITM)
time.sleep(5)
print("Exercising the call if ITM...")
try:
    current_price = contract.functions.latestAnswer().call()
    strike_price = call_details[2]
    if current_price >= strike_price:
        tx = contract.functions.exercise(0).build_transaction({
            "from": BUYER,
            "gas": 3000000,
            "nonce": w3.eth.get_transaction_count(BUYER)
        })
        tx_hash = send_tx(tx, PRIVATE_KEY_BUYER)
        print(f"✅ Call Exercised! TX: {tx_hash}")
    else:
        print("⚠️ Market price is below strike price. Cannot exercise.")
except Exception as e:
    print(f"❌ Error while exercising: {e}")

# 4.5 Expire the Call (if necessary)
time.sleep(5)
print("Checking expiration...")
if call_details[3] <= time.time():
    tx = contract.functions.expire(0).build_transaction({
        "from": SELLER,
        "gas": 3000000,
        "nonce": w3.eth.get_transaction_count(SELLER)
    })
    tx_hash = send_tx(tx, PRIVATE_KEY_SELLER)
    print(f"✅ Call Expired! TX: {tx_hash}")
else:
    print("⚠️ Call not yet expired.")

# ---------------- Final Balances ----------------
print("Checking final balances...")
seller_weth_balance = contract.functions.balanceOf(SELLER).call()
buyer_usdc_balance = contract.functions.balanceOf(BUYER).call()
print(f"✅ Seller WETH Balance: {seller_weth_balance}")
print(f"✅ Buyer USDC Balance: {buyer_usdc_balance}")

print("✅ End-to-End Test Complete!")
