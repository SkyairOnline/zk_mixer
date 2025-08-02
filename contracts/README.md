# ZK Mixer Project

- Deposit: user can deposit ETH into the mizer to break the connection between depositor and withdrawer.
- Withdraw: users will withdraw using a ZK proof (Noir - generated off-chain) of knowledge of their deposit.
- We will only allow users to deposit a fixed amount of ETH (0.001 ETH)

## Proof
- we need to check that the commitment is present in the Merkle tree
    - proposed root
    - Merkle tree
- Check the nullifier matches the (public) nullifier hash