// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Mixer} from "../src/Mixer.sol";
import {HonkVerifier} from "../src/Verifier.sol";
import {IncrementalMerkleTree} from "../src/IncrementalMerkleTree.sol";

contract MixerTest {
    Mixer public mixer;
    HonkVerifier public verifier;
    IncrementalMerkleTree public merkleTree;

    address public recipient = makeAddr("recipient");

    function setup() public {
        // Initialize the Poseidon2 hasher
        Poseidon2 poseidonHasher = new Poseidon2();
        
        // Initialize the verifier
        verifier = new HonkVerifier();
        
        // Initialize the Mixer contract with the verifier and hasher
        mixer = new Mixer(verifier, poseidonHasher, 20);
    }

    function _getCommitment() public {
        // use ffi to run scripts in the CLI to create the commitment
    }

    function testMakeDeposit() public {
        // create a commitment
        // make a deposit
    }
}