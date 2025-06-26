"use client";

const WalletOption = ({ name, img, onClick, disabled, soon, loading }) => {
  return (
    <li>
      <button
        className={`flex items-center p-2 w-full text-left ${disabled ? "opacity-50 cursor-not-allowed" : "hover:bg-gray-700"}`}
        onClick={onClick}
        disabled={disabled || loading}
      >
        <img src={img} alt={`${name} logo`} className="w-8 h-8 mr-3" />
        <span className="text-lg">{name}</span>
        {soon && <span className="ml-auto text-sm text-gray-400">Coming Soon</span>}
        {loading && <span className="ml-auto text-sm text-blue-400">Loading...</span>}
      </button>
    </li>
  );
};

export default WalletOption;