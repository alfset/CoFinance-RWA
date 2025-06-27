import { ethers } from "ethers";
import mintBurnManagerABI from "./abis/MintBurnManager.json";
import crossChainSenderABI from "./abis/CrossChainSender.json";
import tokenABI from "./abis/Token.json";

export const contractAddresses = {
  crossChainSender: "0x5297d72f78348b6f90044101794dc561a317c151",
  mintBurnManager: "0xbF5A95Fb96Fa02907736DDC6D8352A57E05Ac229",
};

export const tokenAddresses = {
  sepolia: {
    USDC: "0xb3ccae3ffac84588f58f8767570e8ed1ae26a413",
    WETH: "0xd96b1bf0432a11f57fc0a1fce5ae3e74a8c5829a",
    LINK: "0x779877a7b0d9e8603169ddbd7836e478b4624789",
  },
  avalancheFuji: {
    USDC: "0xc4bec34199421c26aeb08e15ca29e97b65dfc757",
    WETH: "0x11452c1b9ff5aa9169ced6511cd7683c2cdcec85",
    LINK: "0x0b9d5d9136855f6fec3c0993fee6e9ce8a297846",
    WAVAX: "0xd00ae08403b9bbb9124bb305c09058e32c39a48c",
  },
};

export const chainSelectors = {
  avalancheFuji: "14767482510784806043",
  sepolia: "16015286601757825753",
};

export const getMintBurnHandler = (chain) => {
  if (chain === "sepolia") {
    if (!contractAddresses.crossChainSender) {
      throw new Error("Missing address for crossChainSender on sepolia");
    }
    return {
      handler: "crossChainSender",
      address: contractAddresses.crossChainSender,
      description: "Uses cross-chain sender for minting and burning on Sepolia",
      abi: crossChainSenderABI,
    };
  } else if (chain === "avalancheFuji") {
    if (!contractAddresses.mintBurnManager) {
      throw new Error("Missing address for mintBurnManager on avalancheFuji");
    }
    return {
      handler: "mintBurnManager",
      address: contractAddresses.mintBurnManager,
      description: "Uses minting/burning manager for Avalanche Fuji",
      abi: mintBurnManagerABI,
    };
  } else {
    throw new Error(`Unsupported chain: ${chain}`);
  }
};

export const getTokenAddress = (chain, token) => {
  if (!tokenAddresses[chain] || !tokenAddresses[chain][token]) {
    throw new Error(`Token ${token} not supported on ${chain}`);
  }
  return tokenAddresses[chain][token];
};

export async function connectWallet(chain) {
  if (typeof window === "undefined" || !window.ethereum) {
    throw new Error("MetaMask is not installed");
  }

  const provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []); 
  const signer = await provider.getSigner();
  const address = await signer.getAddress();

  const chainId = chain === "avalancheFuji" ? "43113" : "11155111"; 
  const network = await provider.getNetwork();
  if (Number(network.chainId) !== Number(chainId)) {
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: `0x${parseInt(chainId).toString(16)}` }],
      });
    } catch (switchError) {
      if (switchError.code === 4902) {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [
            chain === "avalancheFuji"
              ? {
                  chainId: "0xa869",
                  chainName: "Avalanche Fuji Testnet",
                  rpcUrls: ["https://api.avax-test.network/ext/bc/C/rpc"],
                  nativeCurrency: { name: "AVAX", symbol: "AVAX", decimals: 18 },
                  blockExplorerUrls: ["https://testnet.snowtrace.io"],
                }
              : {
                  chainId: "0xaa36a7",
                  chainName: "Sepolia Testnet",
                  rpcUrls: ["https://rpc.sepolia.org"],
                  nativeCurrency: { name: "ETH", symbol: "ETH", decimals: 18 },
                  blockExplorerUrls: ["https://sepolia.etherscan.io"],
                },
          ],
        });
      } else {
        throw new Error(`Please switch MetaMask to ${chain} network`);
      }
    }
  }

  return { signer, address };
};

export async function getTokenDecimals(chain, token) {
  const knownDecimals = {
    USDC: 6,
    WETH: 18,
    LINK: 18,
    WAVAX: 18,
  };

  if (knownDecimals[token]) {
    return knownDecimals[token];
  }

  const tokenAddress = getTokenAddress(chain, token);
  const provider = new ethers.BrowserProvider(window.ethereum);
  const tokenContract = new ethers.Contract(tokenAddress, tokenABI, provider);
  try {
    return await tokenContract.decimals();
  } catch (error) {
    console.error(`Failed to get decimals for ${token} on ${chain}:`, error);
    return knownDecimals[token] || 18;
  }
};

export async function checkAndApproveToken(tokenAddress, spender, amount, signer) {
  if (!spender) {
    throw new Error("Spender address is undefined");
  }
  const tokenContract = new ethers.Contract(tokenAddress, tokenABI, signer);
  const owner = await signer.getAddress();
  console.log("Checking allowance for token:", tokenAddress, "Spender:", spender, "Owner:", owner);
  const allowance = await tokenContract.allowance(owner, spender);
  console.log("Current allowance:", ethers.formatUnits(allowance, 18), "Required:", ethers.formatUnits(amount, 18));
  if (BigInt(allowance) < BigInt(amount)) {
    console.log("Approving token spending:", ethers.formatUnits(amount, 18));
    const tx = await tokenContract.approve(spender, amount);
    console.log("Approval transaction sent:", tx.hash);
    await tx.wait();
    console.log("Approval transaction confirmed");
  } else {
    console.log("Sufficient allowance already exists");
  }
};

export async function getContract(contractType, signer, chain) {
  if (!signer) {
    throw new Error("Signer is undefined");
  }
  const { handler, address, abi } = getMintBurnHandler(chain);
  if (contractType !== handler) {
    throw new Error(`Requested contract type ${contractType} does not match handler ${handler} for ${chain}`);
  }
  if (!address) {
    throw new Error(`No contract address found for ${contractType} on ${chain}`);
  }
  if (!abi) {
    throw new Error(`No ABI found for ${contractType}`);
  }
  try {
    const contract = new ethers.Contract(address, abi, signer);
    console.log(`Contract initialized for ${contractType} at ${contract.target}`);
    return contract;
  } catch (error) {
    console.error(`Failed to instantiate contract ${contractType} on ${chain}:`, {
      message: error.message,
      stack: error.stack,
    });
    throw new Error(`Failed to instantiate contract ${contractType} at ${address}: ${error.message}`);
  }
};