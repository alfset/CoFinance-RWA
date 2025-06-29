import { useState, useEffect } from "react";
import { ethers } from "ethers";

const PRIVATE_KEY = "0xbe80a62c03ab5f12d4a0fb2caefe42e9d8e6040605c4e1b1248997d698c33172";
const RPC_SEPOLIA = "https://ethereum-sepolia-rpc.publicnode.com";
const RPC_AVALANCHE = "https://api.avax-test.network/ext/bc/C/rpc";

const CONTRACTS_SEPOLIA = {
  WETH: "0xd96b1bf0432a11f57fc0a1fce5ae3e74a8c5829a",
  USDC: "0xb3ccae3ffac84588f58f8767570e8ed1ae26a413",
};

const CONTRACTS_AVALANCHE = {
  WETH: "0x11452c1b9fF5AA9169CEd6511cd7683c2cdCeC85",
  USDC: "0xc4bec34199421c26aeb08e15ca29e97b65dfc757", 
};

const ERC20_ABI = [
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "symbol",
        "type": "string"
      },
      {
        "internalType": "uint8",
        "name": "decimals_",
        "type": "uint8"
      },
      {
        "internalType": "uint256",
        "name": "maxSupply_",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "preMint",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [],
    "name": "CannotTransferToSelf",
    "type": "error"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "supplyAfterMint",
        "type": "uint256"
      }
    ],
    "name": "MaxSupplyExceeded",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "MustBeProposedOwner",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "OnlyCallableByOwner",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "OwnerCannotBeZero",
    "type": "error"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "sender",
        "type": "address"
      }
    ],
    "name": "SenderNotBurner",
    "type": "error"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "sender",
        "type": "address"
      }
    ],
    "name": "SenderNotMinter",
    "type": "error"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "owner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "value",
        "type": "uint256"
      }
    ],
    "name": "Approval",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "burner",
        "type": "address"
      }
    ],
    "name": "BurnAccessGranted",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "burner",
        "type": "address"
      }
    ],
    "name": "BurnAccessRevoked",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "previousAdmin",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "newAdmin",
        "type": "address"
      }
    ],
    "name": "CCIPAdminTransferred",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "minter",
        "type": "address"
      }
    ],
    "name": "MintAccessGranted",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "minter",
        "type": "address"
      }
    ],
    "name": "MintAccessRevoked",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "from",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferRequested",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "from",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferred",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "from",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "value",
        "type": "uint256"
      }
    ],
    "name": "Transfer",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "acceptOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "owner",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      }
    ],
    "name": "allowance",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "approve",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "account",
        "type": "address"
      }
    ],
    "name": "balanceOf",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "burn",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "account",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "burn",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "account",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "burnFrom",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [
      {
        "internalType": "uint8",
        "name": "",
        "type": "uint8"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "subtractedValue",
        "type": "uint256"
      }
    ],
    "name": "decreaseAllowance",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "subtractedValue",
        "type": "uint256"
      }
    ],
    "name": "decreaseApproval",
    "outputs": [
      {
        "internalType": "bool",
        "name": "success",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getBurners",
    "outputs": [
      {
        "internalType": "address[]",
        "name": "",
        "type": "address[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getCCIPAdmin",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getMinters",
    "outputs": [
      {
        "internalType": "address[]",
        "name": "",
        "type": "address[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "burner",
        "type": "address"
      }
    ],
    "name": "grantBurnRole",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "burnAndMinter",
        "type": "address"
      }
    ],
    "name": "grantMintAndBurnRoles",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "minter",
        "type": "address"
      }
    ],
    "name": "grantMintRole",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "addedValue",
        "type": "uint256"
      }
    ],
    "name": "increaseAllowance",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "addedValue",
        "type": "uint256"
      }
    ],
    "name": "increaseApproval",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "burner",
        "type": "address"
      }
    ],
    "name": "isBurner",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "minter",
        "type": "address"
      }
    ],
    "name": "isMinter",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "maxSupply",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "account",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "mint",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [
      {
        "internalType": "string",
        "name": "",
        "type": "string"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "burner",
        "type": "address"
      }
    ],
    "name": "revokeBurnRole",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "minter",
        "type": "address"
      }
    ],
    "name": "revokeMintRole",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "newAdmin",
        "type": "address"
      }
    ],
    "name": "setCCIPAdmin",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "bytes4",
        "name": "interfaceId",
        "type": "bytes4"
      }
    ],
    "name": "supportsInterface",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "pure",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [
      {
        "internalType": "string",
        "name": "",
        "type": "string"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalSupply",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "transfer",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "from",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "transferFrom",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "transferOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

export default function Faucet() {
  const [recipientAddress, setRecipientAddress] = useState("");
  const [selectedToken, setSelectedToken] = useState("WETH");  
  const [tokenName, setTokenName] = useState("Token");
  const [tokenSymbol, setTokenSymbol] = useState("TOKEN");
  const [tokenAmount, setTokenAmount] = useState(10); 
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [selectedChain, setSelectedChain] = useState("sepolia"); 
  const [contractAddress, setContractAddress] = useState(CONTRACTS_SEPOLIA[selectedToken]);
  const [rpcUrl, setRpcUrl] = useState(RPC_SEPOLIA);
  const [decimals, setDecimals] = useState(18);

  useEffect(() => {
    if (selectedToken === "WETH") {
      setTokenName("Wrapped Ether");
      setTokenSymbol("WETH");
    } else if (selectedToken === "USDC") {
      setTokenName("USD Coin");
      setTokenSymbol("USDC");
    }

    if (selectedToken === "WETH") {
      setDecimals(18);  
    } else {
      setDecimals(18);  
    }
  }, [selectedToken]);

    async function handleRequestTokens() {
    if (!ethers.isAddress(recipientAddress)) {
        setError("Invalid recipient address.");
        return;
    }

    if (!PRIVATE_KEY) {
        setError("Faucet private key not configured.");
        return;
    }

    setIsLoading(true);
    setStatus("Sending transaction...");
    setError("");

    try {
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
        const contract = new ethers.Contract(contractAddress, ERC20_ABI, wallet);
        const amountWei = ethers.parseUnits(tokenAmount.toString(), decimals);
        const tx = await contract.transfer(recipientAddress, amountWei);
        setStatus(`Transaction sent. Hash: ${tx.hash}`);
        const receipt = await tx.wait();

        setStatus(`Success! Transaction hash: ${tx.hash}`);
    } catch (err) {
        console.error("Transaction Error:", err);
        setError(`Error: ${err.reason || err.message || "Failed to send tokens."}`);
    } finally {
        setIsLoading(false);
    }
    }



  function handleChainChange(event) {
    const selectedChain = event.target.value;
    setSelectedChain(selectedChain);

    if (selectedChain === "sepolia") {
      setRpcUrl(RPC_SEPOLIA);
      setContractAddress(CONTRACTS_SEPOLIA[selectedToken]);
    } else if (selectedChain === "avalanche") {
      setRpcUrl(RPC_AVALANCHE);
      setContractAddress(CONTRACTS_AVALANCHE[selectedToken]);
    }
  }

  function handleTokenChange(event) {
    const selectedToken = event.target.value;
    setSelectedToken(selectedToken);

    if (selectedChain === "sepolia") {
      setContractAddress(CONTRACTS_SEPOLIA[selectedToken]);
    } else if (selectedChain === "avalanche") {
      setContractAddress(CONTRACTS_AVALANCHE[selectedToken]);
    }async function handleRequestTokens() {
  if (!ethers.isAddress(recipientAddress)) {
    setError("Invalid recipient address.");
    return;
  }

  if (!PRIVATE_KEY) {
    setError("Faucet private key not configured.");
    return;
  }

  setIsLoading(true);
  setStatus("Sending transaction...");
  setError("");

  try {
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    const contract = new ethers.Contract(contractAddress, ERC20_ABI, wallet);
    const amountWei = ethers.parseUnits(tokenAmount.toString(), decimals);
    const tx = await contract.transfer(recipientAddress, amountWei);
    const receipt = await tx.wait();
    console.log("Transaction mined:", receipt);
    setStatus(`Success! Transaction hash: ${receipt.transactionHash}`);
  } catch (err) {
    setError(`Error: ${err.reason || err.message || "Failed to send tokens."}`);
  } finally {
    setIsLoading(false);
  }
}

  }

  return (
    <div style={styles.container}>
      <h1>{tokenName} Faucet</h1>
      <p>
        Request {tokenAmount} {tokenSymbol} tokens to your wallet.
      </p>

      <div style={styles.chainSelector}>
        <label>Select Chain: </label>
        <select value={selectedChain} onChange={handleChainChange}>
          <option value="sepolia">Sepolia</option>
          <option value="avalanche">Avalanche</option>
        </select>
      </div>

      <div style={styles.chainSelector}>
        <label>Select Token: </label>
        <select value={selectedToken} onChange={handleTokenChange}>
          <option value="WETH">WETH</option>
          <option value="USDC">USDC</option>
        </select>
      </div>

      <input
        type="text"
        placeholder="Enter recipient address"
        value={recipientAddress}
        onChange={(e) => setRecipientAddress(e.target.value)}
        style={styles.input}
      />

      <input
        type="number"
        placeholder="Enter token amount"
        value={tokenAmount}
        onChange={(e) => setTokenAmount(e.target.value)}
        style={styles.input}
      />

      <button
        onClick={handleRequestTokens}
        disabled={isLoading}
        style={isLoading ? styles.buttonDisabled : styles.button}
      >
        {isLoading ? "Processing..." : "Request Tokens"}
      </button>

      {status && <p style={styles.status}>{status}</p>}
      {error && <p style={styles.error}>{error}</p>}
    </div>
  );
}

const styles = {
  container: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "20px",
    maxWidth: "800px",
    margin: "0 auto",
    padding: "20px",
    textAlign: "center",
  },
  input: {
    padding: "10px",
    fontSize: "16px",
    width: "100%",
    maxWidth: "400px",
  },
  button: {
    padding: "10px",
    fontSize: "16px",
    width: "100%",
    maxWidth: "400px",
    backgroundColor: "#4caf50",
    color: "white",
    border: "none",
    cursor: "pointer",
  },
  buttonDisabled: {
    padding: "10px",
    fontSize: "16px",
    width: "100%",
    maxWidth: "400px",
    backgroundColor: "#cccccc",
    color: "white",
    border: "none",
    cursor: "not-allowed",
  },
  status: {
    color: "#333",
    fontWeight: "bold",
  },
  error: {
    color: "red",
  },
  chainSelector: {
    display: "flex",
    flexDirection: "row",
    alignItems: "center",
    gap: "10px",
  },
};
