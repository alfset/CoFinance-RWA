# CoFi RWA

The **CoFi RWA** is a decentralized trading platform built on Ethereum (Sepolia) and Avalanche Fuji testnets, designed to simplify and secure the process of buying and selling tokenized real-world assets (RWAs) like stocks or commodities. By abstracting blockchain complexities and enabling cross-chain functionality, it makes investing in tokenized assets accessible, efficient, and safe, especially for users unfamiliar with decentralized finance (DeFi).



## Overview
CoFi RWA Minter empowers users to:
- **Buy** tokenized assets (e.g., AAPL) using stablecoins (e.g., USDC, WETH, LINK) on Avalanche Fuji or via cross-chain buying from Sepolia.
- **Sell** tokens to redeem underlying assets on Avalanche Fuji, ensuring trust and transparency.
- **Interact** with blockchain contracts through a simple, user-friendly interface — no deep technical knowledge required.
- **Safely manage** wallet connections and transactions with robust error handling.
- **Track** transaction statuses and histories in real-time, reducing uncertainty.
- **View** real-time market data via TradingView charts.
- **Trade within market hours** (9:30 AM to 4:00 PM ET, Monday to Friday) using Chainlink Functions to enforce compliance with traditional financial market standards.

The application integrates with MetaMask for wallet connectivity, uses Ethers.js for blockchain interactions, leverages Chainlink Functions for market status and liquidity checks, and employs Material-UI for a responsive user interface.

## Problems It Solves
CoFi RWA Minter addresses key challenges in RWA tokenization:
1. **Complexity of Tokenization**: Simplifies multi-step processes into a seamless UI, enabling buying and selling without technical expertise.
2. **Centralized Intermediaries**: Eliminates reliance on brokers or custodians using decentralized smart contracts for trustless operations.
3. **Accessibility Barriers**: Offers an intuitive interface with MetaMask integration, making DeFi accessible to non-technical users.
4. **Cross-Chain Limitations**: Supports buying across Sepolia and Avalanche Fuji via Chainlink CCIP, enhancing flexibility.
5. **Lack of Transparency**: Provides real-time transaction tracking and history, with links to blockchain explorers (Snowtrace, Etherscan, CCIP) for verification.
6. **Market Timing**: Restricts trading to U.S. market hours (9:30 AM–4:00 PM ET, Mon–Fri) using Chainlink Functions, ensuring compliance and pricing reliability.
7. **Security Risks**: Implements robust error handling and user guidance to minimize transaction failures and enhance security.

## Challenges and Solutions
During development, the following challenges were encountered, with solutions implemented to ensure a robust platform:

1. **Cross-Chain Buying and Chainlink Automation Limitations**  
   **Context**: Cross-chain buying relies on Chainlink CCIP for messaging between Sepolia and Avalanche Fuji, with Chainlink Automation handling off-chain processes, introducing delays and potential inconsistencies.  
   **Challenge**: Delays in Chainlink Automation or network messaging latency can cause pending or failed transaction confirmations, leading to user uncertainty 

2. **User Experience Around Async Cross-Chain Transactions**  
   **Context**: Cross-chain workflows involve multiple steps and delayed finality due to Chainlink CCIP and automation processes.  
   **Challenge**: Ensuring users understand that buy/sell actions may take time and that errors may stem from external services like Chainlink.  
   **Solution**: Added detailed modal messages explaining each transaction step and potential delays. Integrated a transaction history table (`Recent Transactions`) to track status updates, improving user confidence and clarity.

3. **Market Status Restrictions**  
   **Context**: Buying and selling should be restricted to U.S. market hours (9:30 AM–4:00 PM ET, Mon–Fri) to align with traditional markets.  
   **Challenge**: Accurately determining market status in a decentralized manner.  
   **Solution**: Implemented a Chainlink Functions-based handler to fetch real-time market status from an external API (e.g., Alpha Vantage), restricting buy/sell actions when the market is closed. The UI displays a clear error message when transactions are attempted outside market hours.

4. **Liquidity Provisioning**  
   **Context**: Sufficient liquidity in the custody account is required to facilitate buying.  
   **Challenge**: Ensuring the custody account has enough tokens (e.g., USDC) to cover buy transactions.  
   **Solution**: Integrated Chainlink Functions to fetch the custody account’s balance before each buy transaction. If the balance is below the required notional value, a top-up handler is triggered to sell tokens on the `BuySellManager` contract and transfer funds to the custody account, ensuring seamless transactions.

5. **Modular Buy/Sell Consumer Implementation**  
   **Context**: Third parties need to interact with the platform’s buy and sell functions programmatically.  
   **Challenge**: Creating modular, secure functions that verified third parties can call without compromising the system.  
   **Solution**: Developed `buyConsumer` and `sellConsumer` modular functions in the `BuySellManager` contract, accessible via an allowlist using role-based access control (e.g., OpenZeppelin’s `AccessControl`). Integrated a `TokenPaymentHandler` contract to manage token approvals and transfers, enabling secure third-party interactions.

## Technology Stack
- **Frontend**:
  - **React**: JavaScript library for building the user interface.
  - **Next.js**: Framework for server-side rendering and static site generation.
  - **Material-UI**: Component library for responsive and styled UI elements.
  - **TradingView Widget**: Embedded for real-time market data visualization.
- **Blockchain**:
  - **Ethereum (Sepolia Testnet)**: For cross-chain buying operations.
  - **Avalanche Fuji Testnet**: For buying and selling operations.
  - **Solidity**: Smart contract development language.
  - **Ethers.js**: Library for interacting with Ethereum and Avalanche blockchains.
  - **MetaMask**: Wallet for user authentication and transaction signing.
- **Smart Contracts**:
  - **BuySellManager**: Handles buying and selling on Avalanche Fuji, with modular `buyConsumer` and `sellConsumer` functions for third-party access.
  - **CrossChainSender**: Facilitates cross-chain buying from Sepolia to Avalanche Fuji via Chainlink CCIP.
  - **FunctionsConsumer**: Executes Chainlink Functions requests for market status and custody balance checks.
  - **TokenPaymentHandler**: Manages token approvals and transfers for buy/sell operations, including third-party calls.
- **Chainlink**:
  - **Chainlink CCIP**: Enables cross-chain communication between Sepolia and Avalanche Fuji.
  - **Chainlink Functions**: Fetches real-time market status and custody balance data from external APIs.
  - **Chainlink Automation**: Handles off-chain processes for cross-chain buying.
- **Tools**:
  - **Hardhat**: Development environment for compiling, deploying, and testing smart contracts.
  - **Node.js**: Runtime for running the application and scripts.


## Application Flow
1. **User Authentication**:
   - Users connect their MetaMask wallet, selecting Sepolia or Avalanche Fuji.
2. **Market Status Check**:
   - Chainlink Functions queries an external API to verify if the U.S. market is open (9:30 AM–4:00 PM ET, Mon–Fri).
3. **Token Selection**:
   - Users choose the asset to buy/sell (e.g., AAPL), payment token (e.g., USDC), and destination chain.
4. **Liquidity Check**:
   - Chainlink Functions checks the custody account’s balance. If insufficient, a top-up is triggered via `BuySellManager` to sell tokens and transfer funds.
5. **Transaction Initiation**:
   - **Buy**: Approve token spending and buy via `BuySellManager` (Avalanche Fuji) or `CrossChainSender` (Sepolia).
   - **Sell**: Approve and sell tokens via `BuySellManager` (Avalanche Fuji only).
   - **Cross-Chain Buy**: Lock tokens on Sepolia and send a CCIP message to buy on Avalanche Fuji.
   - **Third-Party Access**: Verified third parties call `buyConsumer` or `sellConsumer` via `TokenPaymentHandler`.
6. **Transaction Status**:
   - Real-time updates via a modal and transaction history table, with links to Snowtrace, Etherscan, or CCIP explorers.
7. **Market Data**:
   - TradingView widget displays real-time price charts for the selected asset.
