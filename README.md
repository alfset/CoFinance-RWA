# CoFi RWA - Decentralized Real-World Asset Trading Platform

**CoFi RWA** is a decentralized trading platform built on Ethereum (Sepolia) and Avalanche Fuji testnets, designed to simplify and secure the buying and selling of tokenized real-world assets (RWAs) such as stocks or commodities. By abstracting blockchain complexities and enabling cross-chain functionality, CoFi RWA makes decentralized finance (DeFi) accessible, efficient, and secure for both technical and non-technical users. The platform leverages **Chainlink Functions** for real-time market status and Proof of Reserve, **Chainlink Automation** for automated workflows, and **Chainlink CCIP** for cross-chain operations, ensuring transparency, reliability, and trust.

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Problems Solved](#problems-solved)
- [Technology Stack](#technology-stack)
- [Smart Contracts](#smart-contracts)
- [Chainlink Integration](#chainlink-integration)
  - [Chainlink Functions](#chainlink-functions)
  - [Chainlink Automation](#chainlink-automation)
  - [Chainlink CCIP](#chainlink-ccip)
- [Proof of Reserve](#proof-of-reserve)
- [Application Flow](#application-flow)

## Overview
CoFi RWA enables users to trade tokenized real-world assets (e.g., AAPL, commodities) using stablecoins (e.g., USDC, WETH, LINK) on Avalanche Fuji or via cross-chain transactions from Sepolia. The platform offers an intuitive interface, robust security, and real-time transparency. It integrates **Chainlink Functions** to fetch market status and verify asset backing, **Chainlink Automation** to manage liquidity and transaction finalization, and **Chainlink CCIP** for seamless cross-chain operations. With MetaMask for wallet connectivity and TradingView for market data, CoFi RWA bridges traditional finance and DeFi.

## Features
- **Buy/Sell Tokenized Assets**: Trade tokenized RWAs on Avalanche Fuji or cross-chain from Sepolia using stablecoins.
- **User-Friendly Interface**: Simplified UI with MetaMask integration for seamless wallet connectivity.
- **Real-Time Market Data**: Embedded TradingView widget for live price charts.
- **Market Hour Restrictions**: Trading restricted to U.S. market hours (9:30 AM–4:00 PM ET, Mon–Fri) using Chainlink Functions.
- **Cross-Chain Functionality**: Buy assets across Sepolia and Avalanche Fuji via Chainlink CCIP.
- **Transaction Tracking**: Real-time status updates and history with links to Snowtrace, Etherscan, and CCIP explorers.
- **Proof of Reserve**: Verifies that minted tokens are fully backed by assets in a custody account using Chainlink Functions.
- **Third-Party Integration**: Modular functions for verified third-party access to buy/sell operations.
- **Security**: Robust error handling and user guidance to minimize transaction failures.

## Problems Solved
1. **Complexity of Tokenization**: Simplifies buying and selling tokenized RWAs through an intuitive interface.
3. **Accessibility Barriers**: Makes DeFi approachable for non-technical users with MetaMask integration.
4. **Cross-Chain Limitations**: Enables seamless cross-chain buying via Chainlink CCIP.
5. **Lack of Transparency**: Provides real-time transaction tracking and blockchain explorer links.
6. **Market Timing Compliance**: Restricts trading to U.S. market hours using Chainlink Functions.
8. **Asset Backing Trust**: Ensures minted tokens are fully backed by real assets via Chainlink Functions for Proof of Reserve.
9. **Manual Processes**: Automates liquidity management and transaction finalization with Chainlink Automation.

## Technology Stack
- **Frontend**:
  - React: JavaScript library for building the user interface.
  - Next.js: Framework for server-side rendering and static site generation.
  - Material-UI: Component library for responsive and styled UI elements.

- **Blockchain**:
  - Ethereum (Sepolia Testnet): Supports cross-chain buying operations.
  - Avalanche Fuji Testnet: Core Handles buying and selling operations.
  - Solidity: Language for smart contract development.

- **Chainlink**:
  - Chainlink Functions: Fetches real-time market status, custody balances, and Proof of Reserve data.
  - Chainlink CCIP: Enables cross-chain communication between Sepolia and Avalanche Fuji.

## Smart Contracts
- **BuySellManager**: Manages buy and sell operations on Avalanche Fuji, with modular functions for third-party access.
- **CrossChainSender**: Facilitates cross-chain buying from Sepolia to Avalanche Fuji using Chainlink CCIP.
- **FunctionsConsumer**: Handles Chainlink Functions requests for market status, custody balance, and Proof of Reserve checks.
- **TokenPaymentHandler**: Manages token approvals and transfers for buy/sell operations, including third-party interactions.

## Chainlink Integration
### Chainlink Functions
Chainlink Functions enables the platform to fetch off-chain data for on-chain use, such as:
- **Market Status**: Queries an external API (e.g., Alpha Vantage) to determine if the U.S. market is open, restricting buy/sell actions to 9:30 AM–4:00 PM ET, Monday to Friday.
- **Custody Balance**: Checks the custody account’s balance to ensure sufficient liquidity for buy transactions.
- **Proof of Reserve**: Verifies that the custody account holds enough assets to back minted tokens (see [Proof of Reserve](#proof-of-reserve)).

### Chainlink Automation
Chainlink Automation automates recurring off-chain processes, including:
- **Liquidity Top-Ups**: Monitors the custody account’s balance and triggers token sales to top up funds when below a threshold.
- **Cross-Chain Finalization**: Tracks pending cross-chain transactions via Chainlink CCIP and finalizes them on Avalanche Fuji, ensuring reliability despite network delays.

### Chainlink CCIP
Chainlink Cross-Chain Interoperability Protocol (CCIP) enables seamless buying from Sepolia to Avalanche Fuji by:
- Burn/Lock tokens on Sepolia.
- Sending a message to the Avalanche Fuji `BuySellManager` contract to execute the buy.
- Providing users with transaction status updates via CCIP explorer links.

## Proof of Reserve
To ensure trust and transparency, CoFi RWA uses Chainlink Functions to implement a **Proof of Reserve** mechanism:
- **Purpose**: Verifies that every minted token (e.g., tokenized AAPL) is fully backed by assets in a custody account.
- **Process**: Chainlink Functions queries an external API (e.g., a custodian service) to fetch the custody account’s balance. Before minting new tokens, the smart contract checks that the reserve balance is sufficient to cover the total minted tokens, ensuring a 1:1 asset backing.
- **Benefit**: Enhances user confidence by providing on-chain verification of asset backing, accessible via blockchain explorers.

## Application Flow
1. **User Authentication**: Users connect their MetaMask wallet, selecting Sepolia or Avalanche Fuji.
2. **Market Status Check**: Chainlink Functions verifies if the U.S. market is open (9:30 AM–4:00 PM ET, Mon–Fri).
3. **Token Selection**: Users choose the asset (e.g., AAPL), payment token (e.g., USDC), and destination chain.
4. **Liquidity Check**: Chainlink Functions checks the custody account’s balance; Chainlink Automation triggers a top-up if needed.
5. **Proof of Reserve**: Chainlink Functions verifies that the custody account has sufficient assets before minting tokens.
6. **Transaction Initiation**:
   - **Buy**: Approve token spending and buy via `BuySellManager` (Avalanche Fuji) or `CrossChainSender` (Sepolia).
   - **Sell**: Approve and sell tokens via `BuySellManager` (Avalanche Fuji only).
   - **Cross-Chain Buy**: Lock tokens on Sepolia and send a CCIP message to buy on Avalanche Fuji.
   - **Third-Party Access**: Verified third parties call modular buy/sell functions.
7. **Transaction Status**: Real-time updates via a modal and transaction history table, with links to Snowtrace, Etherscan, or CCIP explorers.
8. **Market Data**: TradingView widget displays real-time price charts for the selected asset.


these project is for submit Chailink Hackathon and partner track Avalanche
