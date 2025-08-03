// Global type declarations

// Ethereum provider types
interface Window {
  ethereum?: {
    isMetaMask?: boolean;
    request: (args: { method: string; params?: any[] }) => Promise<any>;
    on: (event: string, handler: (...args: any[]) => void) => void;
    removeListener: (event: string, handler: (...args: any[]) => void) => void;
  };
}

// Event handler types
type ChangeEvent<T = HTMLInputElement> = React.ChangeEvent<T>;
type MouseEvent<T = HTMLElement> = React.MouseEvent<T>;
type FormEvent<T = HTMLFormElement> = React.FormEvent<T>;

// Contract types
type Address = `0x${string}`;

// Permit2 types
interface PermitDetails {
  token: Address;
  amount: string;
  expiration: number;
  nonce: number;
}

interface PermitSingle {
  details: PermitDetails;
  spender: Address;
  sigDeadline: number;
}

// Export types for use in components
export type {
  ChangeEvent,
  MouseEvent,
  FormEvent,
  Address,
  PermitDetails,
  PermitSingle
};