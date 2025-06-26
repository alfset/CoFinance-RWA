"use client";

const WalletDetails = ({ connected, account, handleCopy, copySuccess, handleDisconnectWallet, loading }) => {
  return (
    <div className="p-4 bg-[#1a1a1a] rounded-lg">
      <p className="text-lg mb-2">Connected Account: {account.slice(0, 6)}...{account.slice(-4)}</p>
      <button
        className="bg-blue-500 text-white px-4 py-2 rounded mr-2"
        onClick={handleCopy}
        disabled={loading}
      >
        {copySuccess || "Copy Address"}
      </button>
      <button
        className="bg-red-500 text-white px-4 py-2 rounded"
        onClick={handleDisconnectWallet}
        disabled={loading}
      >
        {loading ? "Disconnecting..." : "Disconnect"}
      </button>
    </div>
  );
};

export default WalletDetails;