// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Mixer, Poseidon2} from "../src/Mixer.sol";
import {HonkVerifier} from "../src/Verifier.sol";
import {IncrementalMerkleTree} from "../src/IncrementalMerkleTree.sol";
import {Test, console} from "forge-std/Test.sol";

contract MixerTest is Test {
    Mixer public mixer;
    HonkVerifier public verifier;
    Poseidon2 public hasher;

    address public recipient = makeAddr("recipient");

    function setUp() public {
        // Initialize the Poseidon2 hasher
        hasher = new Poseidon2();

        // Initialize the verifier
        verifier = new HonkVerifier();

        // Initialize the Mixer contract with the verifier and hasher
        mixer = new Mixer(verifier, hasher, 20);
    }

    function _getCommitment() public returns (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) {
        string[] memory inputs = new string[](3);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateCommitment.ts";
        // use ffi to run scripts in the CLI to create the commitment
        bytes memory result = vm.ffi(inputs);
        // ABI decode result
        (_commitment, _nullifier, _secret) = abi.decode(result, (bytes32, bytes32, bytes32));
    }

    function testMakeDeposit() public {
        // create a commitment
        // make a deposit
        (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) = _getCommitment();
        console.log("Commitment: ");
        console.logBytes32(_commitment);
        vm.expectEmit(true, false, false, true);
        emit Mixer.Deposit(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);
    }

    function testMakeWithdrawal() public {
        // create a commitment
        // make a deposit
        (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) = _getCommitment();
        console.log("Commitment: ");
        console.logBytes32(_commitment);
        vm.expectEmit(true, false, false, true);
        emit Mixer.Deposit(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);

        // create a proof
        bytes memory _proof = _getProof(_nullifier, _secret, recipient, leaves);

        // make a withdrawal
    }
}
