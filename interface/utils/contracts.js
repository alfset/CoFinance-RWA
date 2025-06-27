
export const contractAddresses = {
  crossChainSender: "0x5297d72f78348b6f90044101794dc561a317c151",
  mintBurnManager: "0x860a1205fd00fbdde591d7c9822b80ac713944ed",
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