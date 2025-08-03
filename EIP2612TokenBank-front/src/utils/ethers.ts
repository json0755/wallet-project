import { ethers } from 'ethers';
import { EIP2612TokenABI, EIP2612TokenBankABI, Permit2ABI, PERMIT2_DOMAIN, PERMIT_SINGLE_TYPES } from '../abi';
import { DEFAULT_CONTRACTS } from '../config/contracts';
import { randomInt } from 'crypto';

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
  signerOrProvider: ethers.Signer | ethers.Provider,
  owner: string,
  token: string,
  spender: string
): Promise<number> => {
  try {
    const permit2Contract = createPermit2Contract(signerOrProvider);
    const allowanceData = await permit2Contract.allowance(owner, token, spender);
    // Return current nonce directly from contract
    return Number(allowanceData.nonce);
  } catch (error) {
    console.error('Error getting Permit2 nonce:', error);
    // Fallback to 0 if contract call fails (initial nonce)
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
  permitData: PermitSingle
): Promise<string> => {
  const domain = {
    ...PERMIT2_DOMAIN,
    chainId: 31337 // Anvil chain ID
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

// EIP7702 related functions
export const createDelegateContract = (signerOrProvider: ethers.Signer | ethers.Provider) => {
  const DelegateABI = require('../abi/Delegate.json');
  return createContractInstance(
    DEFAULT_CONTRACTS.DELEGATE,
    DelegateABI,
    signerOrProvider
  );
};

export const createAuthorizationSignature = async (
  signer: ethers.Signer,
  contractAddress: string,
  nonce: number = 0
): Promise<string> => {
  const chainId = await signer.provider?.getNetwork().then(n => n.chainId) || 31337;
  
  const authorizationData = {
    chainId: Number(chainId),
    address: contractAddress,
    nonce: nonce
  };
  
  const domain = {
    name: 'EIP7702Authorization',
    version: '1',
    chainId: Number(chainId)
  };
  
  const types = {
    Authorization: [
      { name: 'chainId', type: 'uint256' },
      { name: 'address', type: 'address' },
      { name: 'nonce', type: 'uint256' }
    ]
  };
  
  return await signer.signTypedData(domain, types, authorizationData);
};

export interface Call {
  target: string;
  value: bigint;
  data: string;
}

export const encodeBatchCalls = (calls: Call[]): string => {
  const abiCoder = ethers.AbiCoder.defaultAbiCoder();
  return abiCoder.encode(
    ['tuple(address target, uint256 value, bytes data)[]'],
    [calls.map(call => [call.target, call.value, call.data])]
  );
};

export const encodeInitializeData = (): string => {
  const delegateInterface = new ethers.Interface(require('../abi/Delegate.json'));
  return delegateInterface.encodeFunctionData('initialize', []);
};