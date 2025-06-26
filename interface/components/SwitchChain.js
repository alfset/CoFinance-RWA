"use client";

import { useState } from "react";

const SwitchChain = () => {
  const [chain, setChain] = useState("Avalanche Fuji");

  const handleSwitch = async () => {
    try {
      console.log(`Switching to ${chain === "Avalanche Fuji" ? "Sepolia" : "Avalanche Fuji"}`);
      setChain(chain === "Avalanche Fuji" ? "Sepolia" : "Avalanche Fuji");
    } catch (error) {
      console.error("Failed to switch chain:", error);
    }
  };

  return (
    <button
      className="bg-gray-700 text-white px-4 py-2 rounded"
      onClick={handleSwitch}
    >
      {chain}
    </button>
  );
};

export default SwitchChain;