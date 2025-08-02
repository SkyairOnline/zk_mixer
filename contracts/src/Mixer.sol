// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IncrementalMerkleTree, Poseidon2} from "./IncrementalMerkleTree.sol";
import {IVerifier} from "./IVerifier.sol";

contract Mixer is IncrementalMerkleTree {
    IVerifier public immutable i_verifier;

    // mapping to store whether a commitment has been used
    mapping(bytes32 => bool) public s_commitments;

    // the denomination of the mixer, i.e. the amount of ETH that can be deposited
    uint256 public constant DENOMINATION = 0.001 ether;

    error Mixer__CommitmentAlreadyAdded(bytes32 commitment);
    error Mixer__DepositAmountNotCorrect(uint256 amountSent, uint256 expectedAmount);

    constructor(IVerifier _verifier, Poseidon2 _hasher, uint32 _merkleTreeDepth) IncrementalMerkleTree(_merkleTreeDepth, _hasher) {
        i_verifier = _verifier;
    }

    // @notice Deposit funds into the mixer
    // @param _commitment the poseiden commitment of the nullifier and secret (generated off-chain)
    function deposit(bytes32 _commitment) external payable {
        // check whether the commitment has already been used so we can prevent a deposit being added twice
        if (s_commitments[_commitment]) {
            revert Mixer__CommitmentAlreadyAdded(_commitment);
        }
        // check that the amount of ETH send it the correct denomination
        if(msg.value != DENOMINATION) {
            revert Mixer__DepositAmountNotCorrect(msg.value, DENOMINATION);
        }
        // add the commitment to on-chain incremental Metkle tree containing all of the commitments
        uint32 insertedINdex = _insert(_commitment);
        s_commitments[_commitment] = true;

        emit Deposit(_commitment, insertedIndex, block.timestamp);
    }

    // @notice Withdraw funds from the mixer in a private way
    // @param _proof proof that the user has the right to withdraw (they know a valid commitment)
    function withdraw(bytes32 _proof) external {
        // check that the proof is valid by calling the verifier contract
        // check that the nullifier has not been used before (to prevent double spending)
        // transfer the funds to the user
    }
}