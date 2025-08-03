import { ethers } from 'ethers';
import { EIP2612TokenABI, EIP2612TokenBankABI, Permit2ABI, PERMIT2_DOMAIN, PERMIT_SINGLE_TYPES } from '../abi';
import { DEFAULT_CONTRACTS } from '../config/contracts';

// Utility functions
export const formatAmount = (amount: string, decimals: number = 18): string => {
  return ethers.formatUnits(amount, decimals);
};

export const parseAmount = (amount: string, decimals: number = 18): bigint => {
  return ethers.parseUnits(amount, decimals);
};

export const truncateAddress = (address: string, startLength: number = 6, endLength: number = 4): string => {
  if (address.length <= startLength + endLength) return address;
  return `${address.slice(0, startLength)}...${address.slice(-endLength)}`;
};

// Nonce management for Permit2
let currentNonce = 2;

export const generateNonce = (): number => {
  return 50;
};

export const resetNonce = (): void => {
  currentNonce = 0;
};

export const getCurrentNonce = (): number => {
  return currentNonce;
};

// Get current nonce from Permit2 contract
export const getPermit2Nonce = async (
  permit2Contract: ethers.Contract,
  owner: string,
  token: string,
  spender: string
): Promise<number> => {
  try {
    const allowanceData = await permit2Contract.allowance(owner, token, spender);
    return Number(allowanceData.nonce);
  } catch (error) {
    console.error('Error getting Permit2 nonce:', error);
    // Return a default nonce if there's an error
    return 0;
  }
};

export const getDeadline = (minutes: number = 30): number => {
  return Math.floor(Date.now() / 1000) + (minutes * 60);
};

export const getExpiration = (hours: number = 24): number => {
  return Math.floor(Date.now() / 1000) + (hours * 60 * 60);
};

export const getSigDeadline = (minutes: number = 30): number => {
  return Math.floor(Date.now() / 1000) + (minutes * 60);
};

// Types for Permit2
export interface PermitDetails {
  token: string;
  amount: string;
  expiration: number;
  nonce: number;
}

export interface PermitSingle {
  details: PermitDetails;
  spender: string;
  sigDeadline: number;
}

// Create Permit2 signature
export const createPermit2Signature = async (
  signer: ethers.Signer,
  permitDetails: PermitDetails,
  spender: string,
  sigDeadline: number
): Promise<string> => {
  const domain = {
    ...PERMIT2_DOMAIN,
    chainId: 31337 // Anvil chain ID
  };

  const permitData: PermitSingle = {
    details: permitDetails,
    spender,
    sigDeadline
  };

  const signature = await signer.signTypedData(
    domain,
    PERMIT_SINGLE_TYPES,
    permitData
  );

  return signature;
};

// Contract instance creators
export const createContractInstance = (
  address: string,
  abi: any,
  signerOrProvider: ethers.Signer | ethers.Provider
) => {
  return new ethers.Contract(address, abi, signerOrProvider);
};

export const createTokenBankContract = (signerOrProvider: ethers.Signer | ethers.Provider) => {
  return createContractInstance(
    DEFAULT_CONTRACTS.TOKEN_BANK,
    EIP2612TokenBankABI,
    signerOrProvider
  );
};

export const createTokenContract = (signerOrProvider: ethers.Signer | ethers.Provider) => {
  return createContractInstance(
    DEFAULT_CONTRACTS.EIP2612_TOKEN,
    EIP2612TokenABI,
    signerOrProvider
  );
};

export const createPermit2Contract = (signerOrProvider: ethers.Signer | ethers.Provider) => {
  return createContractInstance(
    DEFAULT_CONTRACTS.PERMIT2,
    Permit2ABI,
    signerOrProvider
  );
};