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

    function _getProof(bytes32 _nullifier, bytes32 _secret, address _recipient, bytes32[] memory leaves) internal returns (bytes memory proof, bytes32[] memory publicInputs) {
        // create a proof using the nullifier and secret
        string[] memory inputs = new string[](6 + leaves.length);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateProof.ts";
        inputs[3] = vm.toString(_nullifier);
        inputs[4] = vm.toString(_secret);
        inputs[5] = vm.toString(bytes32(uint256(uint160(_recipient))));
        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[6 + i] = vm.toString(leaves[i]);
        }
        // use ffi to run scripts in the CLI to create the proof
        bytes memory result = vm.ffi(inputs);
        // ABI decode result
        (proof, publicInputs) = abi.decode(result, (bytes, bytes32[]));
    }

    function testMakeDeposit() public {
        // create a commitment
        // make a deposit
        (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) = _getCommitment();
        vm.expectEmit(true, false, false, true);
        emit Mixer.Deposit(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);
    }

    function testMakeWithdrawal() public {
        // create a commitment
        // make a deposit
        (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) = _getCommitment();
        vm.expectEmit(true, false, false, true);
        emit Mixer.Deposit(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);

        // create a proof
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _commitment;
        // get the proof
        (bytes memory _proof, bytes32[] memory _publicInputs) = _getProof(_nullifier, _secret, recipient, leaves);
        assertTrue(verifier.verify(_proof, _publicInputs));
        // make a withdrawal
        assertEq(recipient.balance, 0);
        assertEq(address(mixer).balance, mixer.DENOMINATION());
        mixer.withdraw(_proof, _publicInputs[0], _publicInputs[1], payable(address(uint160(uint256(_publicInputs[2])))));
        assertEq(recipient.balance, mixer.DENOMINATION());
        assertEq(address(mixer).balance, 0);
    }

    function testAnotherAddressSendProof() public {
        // make a deposit
        (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) = _getCommitment();
        vm.expectEmit(true, false, false, true);
        emit Mixer.Deposit(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);

        // create a proof using the nullifier and secret
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _commitment;

        // create a proof
        (bytes memory _proof, bytes32[] memory _publicInputs) = _getProof(_nullifier, _secret, recipient, leaves);


        // make a withdrawal from another address
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert();
        mixer.withdraw(_proof, _publicInputs[0], _publicInputs[1], payable(attacker));
    }
}
