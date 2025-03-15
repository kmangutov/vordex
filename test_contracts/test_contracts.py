import subprocess
import json
import time
import os
from dotenv import load_dotenv
from web3 import Web3
from eth_account import Account

# Load environment variables
load_dotenv()

# ---------------- Configuration ----------------
RPC_URL = os.getenv("RPC_URL", "http://127.0.0.1:8545")
PRIVATE_KEY_SELLER = os.getenv("PRIVATE_KEY_SELLER")
PRIVATE_KEY_BUYER = os.getenv("PRIVATE_KEY_BUYER")

SELLER = Account.from_key(PRIVATE_KEY_SELLER).address
BUYER = Account.from_key(PRIVATE_KEY_BUYER).address

VORDEX_PATH = "../vordex"

w3 = Web3(Web3.HTTPProvider(RPC_URL))

def run_command(command):
    """Executes a shell command and logs output"""
    print(f"\n🔹 Running: {command}")
    result = subprocess.run(command, shell=True, capture_output=True, text=True, cwd=VORDEX_PATH)
    
    print("🔸 STDOUT:")
    print(result.stdout)
    
    if result.stderr:
        print("🔸 STDERR:")
        print(result.stderr)
    
    return result.stdout.strip()

def get_contract_address_from_tx(tx_hash):
    """Retrieves the deployed contract address from a transaction hash"""
    print(f"\n🔍 Fetching contract address from TX: {tx_hash} ...")
    
    time.sleep(5)  # Wait for transaction to be mined

    # Fetch transaction receipt using cast
    receipt_json = run_command(f"cast receipt {tx_hash} --json --rpc-url {RPC_URL}")

    try:
        receipt = json.loads(receipt_json)
        contract_address = receipt.get("contractAddress")

        if contract_address:
            print(f"✅ Contract deployed at: {contract_address}")
            return contract_address
        else:
            print("❌ Error: No contract address found in receipt!")
            print(json.dumps(receipt, indent=2))
            exit(1)
    except json.JSONDecodeError:
        print("❌ Error parsing transaction receipt JSON.")
        exit(1)

def extract_tx_hash(deploy_output):
    """Extracts transaction hash from Forge output, with fallback to recent transactions"""
    try:
        deploy_data = json.loads(deploy_output)
        tx_hash = deploy_data.get("transaction", {}).get("hash")

        if not tx_hash:
            print("\n⚠️ Forge didn't return a transaction hash. Checking latest transactions...")

            # Fetch the latest block transactions
            latest_block = w3.eth.get_block("latest", full_transactions=True)

            if not latest_block or "transactions" not in latest_block:
                print("\n❌ Error: Could not retrieve recent transactions from the latest block.")
                return None
            
            if len(latest_block["transactions"]) == 0:
                print("\n❌ No transactions found in the latest block. Contract deployment might have failed.")
                return None

            # Assume last transaction in block is the deploy transaction
            tx_hash = latest_block["transactions"][-1]["hash"].hex()
            print(f"\n✅ Found latest transaction: {tx_hash}")

        return tx_hash
    except json.JSONDecodeError:
        print("\n❌ Failed to parse contract deployment output.")
        return None


def send_tx(txn, private_key):
    """Signs and sends a transaction"""
    signed_txn = w3.eth.account.sign_transaction(txn, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)

    return w3.to_hex(tx_hash)

# ---------------- Step 1: Start Anvil ----------------
print("\n🚀 Starting Anvil...")
subprocess.Popen(["anvil"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(3)

# ---------------- Step 2: Compile & Deploy Contract ----------------
print("\n🛠️ Compiling Solidity Contracts...")
run_command(f"forge build --root {VORDEX_PATH}")

print("\n📜 Deploying CoveredCallEscrow...")
deploy_output = run_command(f"forge create src/CoveredCallEscrow.sol:CoveredCallEscrow --rpc-url {RPC_URL} --private-key {PRIVATE_KEY_SELLER} --json --root {VORDEX_PATH}")

# Extract transaction hash
tx_hash = extract_tx_hash(deploy_output)
if not tx_hash:
    print("\n❌ Deployment failed: No transaction hash found.")
    exit(1)

# Get contract address from the transaction receipt
CONTRACT_ADDRESS = get_contract_address_from_tx(tx_hash)

# ---------------- Step 3: Load ABI ----------------
ABI_PATH = os.path.join(VORDEX_PATH, "out", "CoveredCallEscrow.sol", "CoveredCallEscrow.json")

if not os.path.exists(ABI_PATH):
    print(f"\n❌ ABI file not found at {ABI_PATH}. Ensure `forge build` runs successfully.")
    exit(1)

with open(ABI_PATH, "r") as abi_file:
    contract_abi = json.load(abi_file)["abi"]

# Ensure the contract address is in checksum format
CONTRACT_ADDRESS = Web3.to_checksum_address(CONTRACT_ADDRESS)

# Create contract instance
contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=contract_abi)


# ---------------- Step 4: Covered Call Workflow ----------------
# 4.1 Create a Covered Call
print("\n🛠️ Creating Covered Call...")
tx = contract.functions.createCall(3000000000, int(time.time()) + 600, 10**18).build_transaction({
    "from": SELLER,
    "gas": 3000000,
    "nonce": w3.eth.get_transaction_count(SELLER)
})
tx_hash = send_tx(tx, PRIVATE_KEY_SELLER)
print(f"\n✅ Call Created! TX: {tx_hash}")

# 4.2 Lock the Call
time.sleep(5)
print("\n🔒 Buyer locking call...")
tx = contract.functions.lockCall(0, 5000000).build_transaction({
    "from": BUYER,
    "gas": 3000000,
    "nonce": w3.eth.get_transaction_count(BUYER)
})
tx_hash = send_tx(tx, PRIVATE_KEY_BUYER)
print(f"\n✅ Call Locked! TX: {tx_hash}")

# 4.3 Check the Call State
time.sleep(5)
call_details = contract.functions.calls(0).call()
print(f"\n📌 Call State: {call_details}")

# 4.4 Exercise the Call (if ITM)
time.sleep(5)
print("\n⚖️ Exercising the call if ITM...")
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
        print(f"\n✅ Call Exercised! TX: {tx_hash}")
    else:
        print("\n⚠️ Market price is below strike price. Cannot exercise.")
except Exception as e:
    print(f"\n❌ Error while exercising: {e}")

# 4.5 Expire the Call (if necessary)
time.sleep(5)
print("\n⏳ Checking expiration...")
if call_details[3] <= time.time():
    tx = contract.functions.expire(0).build_transaction({
        "from": SELLER,
        "gas": 3000000,
        "nonce": w3.eth.get_transaction_count(SELLER)
    })
    tx_hash = send_tx(tx, PRIVATE_KEY_SELLER)
    print(f"\n✅ Call Expired! TX: {tx_hash}")
else:
    print("\n⚠️ Call not yet expired.")

# ---------------- Final Balances ----------------
print("\n💰 Checking final balances...")
seller_weth_balance = contract.functions.balanceOf(SELLER).call()
buyer_usdc_balance = contract.functions.balanceOf(BUYER).call()
print(f"\n✅ Seller WETH Balance: {seller_weth_balance}")
print(f"\n✅ Buyer USDC Balance: {buyer_usdc_balance}")

print("\n✅ End-to-End Test Complete!")
