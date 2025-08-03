import { Barretenberg, Fr, UltraHonkBackend } from '@aztec/bb.js';
import { ethers } from 'ethers';
import { Noir } from '@noir-lang/noir_js';
import { merkleTree } from './merkleTree.js'; 

import fs from 'fs';
import path from 'path';

const circuit = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../circuits/target/circuits.json'), 'utf8'));

export default async function generateProof() {
    const bb = await Barretenberg.new();
    const inputs = process.argv.slice(2);
    const nullifier = Fr.fromString(inputs[0]);
    const secret = Fr.fromString(inputs[1]);
    const nullifierHash = await bb.poseidon2Hash([nullifier]);
    const commitment = await bb.poseidon2Hash([nullifier, secret]);
    const recipient = inputs[2];
    const leaves = inputs.slice(3);
    const tree = await merkleTree(leaves);
    const merkleProof = tree.proof(tree.getIndex(commitment.toString()));
    
    try {
        const noir = new Noir(circuit);
        const honk = new UltraHonkBackend(circuit.bytecode, { threads: 1 });
        const input = {
            // Public Inputs,
            root: merkleProof.root.toString(), // This should be the root of the merkle tree
            nullifier_hash: nullifierHash.toString(), // This should be the nullifier hash
            recipient: recipient, // This should be the recipient address
            // Private Inputs,
            nullifier: nullifier.toString(), // This should be the nullifier hash
            secret: secret.toString(), // This should be the secret
            merkle_proof: merkleProof.pathElements.map(el => el.toString()), // This should be the merkle proof path elements
            is_even: merkleProof.pathIndices.map(idx => idx % 2 === 0), // This should be the merkle proof indices
        }
        const { witness } = await noir.execute(input);
        const originalLog = console.log;
        const { proof, publicInputs } = await honk.generateProof(witness, { keccak: true });
        console.log = originalLog; // Restore console.log
        const result = ethers.AbiCoder.defaultAbiCoder().encode(
            ["bytes", "bytes32[]"],
            [proof, publicInputs]
        );
        return result;
    } catch (error) {
        console.error('Error generating proof:', error);
        throw error;
    }
}


(async () => {
    generateProof()
        .then((result) => {
            process.stdout.write(result);
            process.exit(0);
        })
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
})();