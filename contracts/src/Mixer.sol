// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Mixer (Educational Adaptation of Tornado Cash)
 * @notice This smart contract is a simplified and modified version of the Tornado Cash protocol,
 *         developed purely for educational purposes as part of a blockchain development course.
 * @dev The original design and cryptographic structure are inspired by Tornado Cash:
 *      https://github.com/tornadocash/tornado-core
 * @author Aldo SUrya Ongko
 * @notice Do not deploy this contract to mainnet or use it for handling real funds.
 *         This contract is unaudited and intended for demonstration only.
 */

import {IncrementalMerkleTree, Poseidon2} from "./IncrementalMerkleTree.sol";
import {IVerifier} from "./Verifier.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Mixer is IncrementalMerkleTree, ReentrancyGuard {
    IVerifier public immutable i_verifier;
    // the denomination of the mixer, i.e. the amount of ETH that can be deposited
    uint256 public constant DENOMINATION = 0.001 ether;

    // mapping to store whether a commitment has been used
    mapping(bytes32 => bool) public s_commitments;
    mapping(bytes32 => bool) public s_nullifierHashes;

    event Deposit(
        bytes32 indexed commitment,
        uint32 insertedIndex,
        uint256 timestamp
    );
    event Withdrawal(address recipient, bytes32 nullifierHash);

    error Mixer__CommitmentAlreadyAdded(bytes32 commitment);
    error Mixer__DepositAmountNotCorrect(
        uint256 amountSent,
        uint256 expectedAmount
    );
    error Mixer__UnknownRoot(bytes32 root);
    error Mixer__NullifierAlreadyUsed(bytes32 nullifierHash);
    error Mixer__InvalidWithdrawProof();
    error Mixer__PaymentFailed(address recipient, uint256 amount);

    constructor(
        IVerifier _verifier,
        Poseidon2 _hasher,
        uint32 _merkleTreeDepth
    ) IncrementalMerkleTree(_merkleTreeDepth, _hasher) {
        i_verifier = _verifier;
    }

    /// @notice Deposit funds into the mixer
    /// @param _commitment the poseiden commitment of the nullifier and secret (generated off-chain)
    function deposit(bytes32 _commitment) external payable nonReentrant {
        // check whether the commitment has already been used so we can prevent a deposit being added twice
        if (s_commitments[_commitment]) {
            revert Mixer__CommitmentAlreadyAdded(_commitment);
        }
        // check that the amount of ETH send it the correct denomination
        if (msg.value != DENOMINATION) {
            revert Mixer__DepositAmountNotCorrect(msg.value, DENOMINATION);
        }
        // add the commitment to on-chain incremental Metkle tree containing all of the commitments
        uint32 insertedIndex = _insert(_commitment);
        s_commitments[_commitment] = true;

        emit Deposit(_commitment, insertedIndex, block.timestamp);
    }

    /// @notice Withdraw funds from the mixer in a private way
    /// @param _proof proof that the user has the right to withdraw (they know a valid commitment)
    /// @param _root the root of the Merkle tree that was used to generate the proof
    /// @param _nullifierHash the hash of the nullifier that was used to generate the proof
    /// @param _recipient the address that will receive the funds
    /// @dev the proof is generated off-chain using the circuit
    function withdraw(
        bytes calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient
    ) external nonReentrant {
        // check that the root that was used in the proof mathces the root on-chain
        if (!isKnownRoot(_root)) {
            revert Mixer__UnknownRoot(_root);
        }
        // check that the nullifier has not been used before (to prevent double spending)
        if (s_nullifierHashes[_nullifierHash]) {
            revert Mixer__NullifierAlreadyUsed(_nullifierHash);
        }
        // check that the proof is valid by calling the verifier contract
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _root;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = bytes32(uint256(uint160(address(_recipient)))); // convert address to bytes32
        if (!i_verifier.verify(_proof, publicInputs)) {
            revert Mixer__InvalidWithdrawProof();
        }
        s_nullifierHashes[_nullifierHash] = true;
        // transfer the funds to the user
        (bool success, ) = _recipient.call{value: DENOMINATION}("");
        if (!success) {
            revert Mixer__PaymentFailed(_recipient, DENOMINATION);
        }
        emit Withdrawal(_recipient, _nullifierHash);
    }
}
