/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  GovernorNOROegaDelegatorStorage,
  GovernorNOROegaDelegatorStorageInterface,
} from "../GovernorNOROegaDelegatorStorage";

const _abi = [
  {
    constant: true,
    inputs: [],
    name: "admin",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "implementation",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "pendingAdmin",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b506101b0806100206000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c806326782247146100465780635c60da1b14610064578063f851a44014610082575b600080fd5b61004e6100a0565b60405161005b9190610120565b60405180910390f35b61006c6100c6565b6040516100799190610120565b60405180910390f35b61008a6100ec565b6040516100979190610120565b60405180910390f35b600160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b61011a8161013b565b82525050565b60006020820190506101356000830184610111565b92915050565b60006101468261014d565b9050919050565b600073ffffffffffffffffffffffffffffffffffffffff8216905091905056fea365627a7a723158203a90c343b6aa5addcc80fcc763919511426500e0b14a4b8dfcc689fcf33ab0016c6578706572696d656e74616cf564736f6c63430005100040";

export class GovernorNOROegaDelegatorStorage__factory extends ContractFactory {
  constructor(
    ...args: [signer: Signer] | ConstructorParameters<typeof ContractFactory>
  ) {
    if (args.length === 1) {
      super(_abi, _bytecode, args[0]);
    } else {
      super(...args);
    }
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<GovernorNOROegaDelegatorStorage> {
    return super.deploy(
      overrides || {}
    ) as Promise<GovernorNOROegaDelegatorStorage>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): GovernorNOROegaDelegatorStorage {
    return super.attach(address) as GovernorNOROegaDelegatorStorage;
  }
  connect(signer: Signer): GovernorNOROegaDelegatorStorage__factory {
    return super.connect(signer) as GovernorNOROegaDelegatorStorage__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): GovernorNOROegaDelegatorStorageInterface {
    return new utils.Interface(
      _abi
    ) as GovernorNOROegaDelegatorStorageInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): GovernorNOROegaDelegatorStorage {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as GovernorNOROegaDelegatorStorage;
  }
}
